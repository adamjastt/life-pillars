-- Life Pillars: Scales (The Bank's currency) + mailbox gifts. Safe to run more than once.
create table if not exists public.wallets(
  user_id uuid primary key references auth.users(id) on delete cascade,
  balance integer not null default 0 check (balance >= 0),
  updated_at timestamptz not null default now()
);
create table if not exists public.gifts(
  id text primary key,
  amount integer not null check (amount > 0),
  note text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.gift_claims(
  gift_id text not null references public.gifts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  claimed_at timestamptz not null default now(),
  primary key (gift_id, user_id)
);
alter table public.wallets enable row level security;
alter table public.gifts enable row level security;
alter table public.gift_claims enable row level security;

-- people can only look at their own balance and claims; nobody can edit a balance directly
drop policy if exists wal_read on public.wallets;
create policy wal_read on public.wallets for select to authenticated using (user_id = auth.uid());
drop policy if exists gift_read on public.gifts;
create policy gift_read on public.gifts for select to authenticated using (active);
drop policy if exists claim_read on public.gift_claims;
create policy claim_read on public.gift_claims for select to authenticated using (user_id = auth.uid());
grant select on public.wallets, public.gifts, public.gift_claims to authenticated;
grant all on public.wallets, public.gifts, public.gift_claims to service_role;

-- the only way Scales arrive: claim a gift, once per person
create or replace function public.claim_gift(g text) returns integer language plpgsql security definer set search_path = public as $$
declare amt integer; bal integer;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select amount into amt from public.gifts where id = g and active;
  if amt is null then raise exception 'no such gift'; end if;
  insert into public.gift_claims(gift_id, user_id) values (g, auth.uid()) on conflict do nothing;
  if not found then
    select balance into bal from public.wallets where user_id = auth.uid();
    return coalesce(bal, 0);
  end if;
  insert into public.wallets(user_id, balance) values (auth.uid(), amt)
    on conflict (user_id) do update set balance = public.wallets.balance + excluded.balance, updated_at = now()
    returning balance into bal;
  return bal;
end $$;
revoke all on function public.claim_gift(text) from public;
grant execute on function public.claim_gift(text) to authenticated;

-- the launch gift in everyone's mailbox
insert into public.gifts(id, amount, note) values ('launch-50', 50, 'Welcome to Scales') on conflict (id) do nothing;
-- Life Pillars: earning Scales (new species, new PBs, biggest fish in a session). Safe to run more than once.
create table if not exists public.scale_log(
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  amount integer not null,
  reason text not null,
  ref text not null,
  label text,
  catch_id text,
  grams numeric,
  revoked boolean not null default false,
  created_at timestamptz not null default now(),
  unique (user_id, reason, ref)
);
alter table public.scale_log enable row level security;
drop policy if exists slog_read on public.scale_log;
create policy slog_read on public.scale_log for select to authenticated using (user_id = auth.uid());
grant select on public.scale_log to authenticated;
grant all on public.scale_log to service_role;

create or replace function public.scales_add(u uuid, amt integer) returns integer language sql security definer set search_path = public as $$
  insert into public.wallets(user_id, balance) values (u, greatest(amt, 0))
  on conflict (user_id) do update set balance = greatest(public.wallets.balance + amt, 0), updated_at = now()
  returning balance $$;
create or replace function public.scales_room(u uuid) returns integer language sql stable security definer set search_path = public as $$
  select greatest(0, 50 - coalesce(sum(amount), 0))::integer from public.scale_log
  where user_id = u and not revoked and reason in ('species', 'pb', 'session') and created_at >= date_trunc('day', now()) $$;
revoke all on function public.scales_add(uuid, integer) from public;
revoke all on function public.scales_room(uuid) from public;

-- gifts now also show up in the earnings history
create or replace function public.claim_gift(g text) returns integer language plpgsql security definer set search_path = public as $$
declare amt integer; bal integer;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select amount into amt from public.gifts where id = g and active;
  if amt is null then raise exception 'no such gift'; end if;
  insert into public.gift_claims(gift_id, user_id) values (g, auth.uid()) on conflict do nothing;
  if not found then select balance into bal from public.wallets where user_id = auth.uid(); return coalesce(bal, 0); end if;
  insert into public.scale_log(user_id, amount, reason, ref, label) values (auth.uid(), amt, 'gift', g, 'Mailbox gift') on conflict do nothing;
  return public.scales_add(auth.uid(), amt);
end $$;

-- called after a catch has been saved; the server checks the catch itself before paying
create or replace function public.earn_catch(cid text) returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := auth.uid(); d jsonb; c jsonb; sp text; g numeric; prev numeric; prevpb numeric; room integer; amt integer;
        got jsonb := '[]'::jsonb; old public.scale_log;
begin
  if u is null then raise exception 'not signed in'; end if;
  select data into d from public.pillars_data where user_id = u;
  select x into c from jsonb_array_elements(coalesce(d->'fish'->'catches', '[]'::jsonb)) x where x->>'id' = cid limit 1;
  if c is null then return jsonb_build_object('wait', true); end if;
  sp := c->>'species'; g := nullif(c->>'g', '')::numeric;
  if sp is null or sp = '' then return jsonb_build_object('awards', got); end if;

  -- new species: once per species, ever
  select * into old from public.scale_log where user_id = u and reason = 'species' and ref = sp;
  -- only the first catch of a species counts (species caught before Scales existed never pay out)
  if (old.id is null or old.revoked) and not public.bp_has(u, sp) and not exists (select 1 from jsonb_array_elements(d->'fish'->'catches') x where x->>'species' = sp and x->>'id' <> cid) then
    room := public.scales_room(u); amt := least(10, room);
    if amt > 0 then
      if old.id is null then insert into public.scale_log(user_id, amount, reason, ref, label, catch_id) values (u, amt, 'species', sp, 'New species: ' || sp, cid);
      else update public.scale_log set revoked = false, amount = amt, catch_id = cid, created_at = now() where id = old.id; end if;
      perform public.scales_add(u, amt); got := got || jsonb_build_object('amount', amt, 'label', 'New species: ' || sp);
    end if;
  end if;

  -- new personal best: must beat every other catch of that species and any PB already paid for
  if g is not null and g > 0 then
    select max(nullif(x->>'g', '')::numeric) into prev from jsonb_array_elements(d->'fish'->'catches') x where x->>'species' = sp and x->>'id' <> cid;
    select max(grams) into prevpb from public.scale_log where user_id = u and reason = 'pb' and not revoked and label = 'New PB: ' || sp;
    if prev is not null and g > prev and g > coalesce(prevpb, 0)
       and (select count(*) from public.scale_log where user_id = u and reason = 'pb' and not revoked and created_at >= date_trunc('day', now())) < 3 then
      room := public.scales_room(u); amt := least(5, room);
      if amt > 0 then
        insert into public.scale_log(user_id, amount, reason, ref, label, catch_id, grams) values (u, amt, 'pb', cid, 'New PB: ' || sp, cid, g)
        on conflict (user_id, reason, ref) do nothing;
        if found then perform public.scales_add(u, amt); got := got || jsonb_build_object('amount', amt, 'label', 'New PB: ' || sp); end if;
      end if;
    end if;
  end if;
  return jsonb_build_object('awards', got, 'balance', (select balance from public.wallets where user_id = u));
end $$;

-- a deleted catch gives back what it earned (a species award moves to another catch of that species if there is one)
create or replace function public.revoke_catch(cid text) returns integer language plpgsql security definer set search_path = public as $$
declare u uuid := auth.uid(); r public.scale_log; other text;
begin
  if u is null then raise exception 'not signed in'; end if;
  for r in select * from public.scale_log where user_id = u and catch_id = cid and not revoked and reason in ('species', 'pb') loop
    if r.reason = 'species' then
      select x->>'id' into other from public.pillars_data p, jsonb_array_elements(p.data->'fish'->'catches') x
        where p.user_id = u and x->>'species' = r.ref and x->>'id' <> cid limit 1;
      if other is not null then update public.scale_log set catch_id = other where id = r.id; continue; end if;
    end if;
    update public.scale_log set revoked = true where id = r.id;
    perform public.scales_add(u, -r.amount);
  end loop;
  return coalesce((select balance from public.wallets where user_id = u), 0);
end $$;

-- biggest fish in a finished session with 2+ anglers; anyone in the session can ask, it only ever pays once
create or replace function public.award_session(sid uuid) returns jsonb language plpgsql security definer set search_path = public as $$
declare s public.sessions; n integer; w record; room integer; amt integer;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into s from public.sessions where id = sid;
  if s.id is null or not (public.in_session(sid) or s.owner = auth.uid()) then return jsonb_build_object('ok', false); end if;
  if s.ended_at is null and s.ends_at > now() then return jsonb_build_object('ok', false, 'live', true); end if;
  select count(*) into n from public.session_members where session_id = sid and status = 'joined';
  if n < 2 then return jsonb_build_object('ok', true, 'winner', null); end if;
  select user_id, (info->>'g')::numeric as g into w from public.session_events
    where session_id = sid and kind = 'catch' and nullif(info->>'g', '') is not null
    order by (info->>'g')::numeric desc, created_at asc limit 1;
  if w.user_id is null then return jsonb_build_object('ok', true, 'winner', null); end if;
  if not exists (select 1 from public.scale_log where user_id = w.user_id and reason = 'session' and ref = sid::text) then
    room := public.scales_room(w.user_id); amt := least(15, room);
    if amt > 0 then
      insert into public.scale_log(user_id, amount, reason, ref, label) values (w.user_id, amt, 'session', sid::text, 'Biggest fish: ' || s.name) on conflict do nothing;
      if found then perform public.scales_add(w.user_id, amt); end if;
    end if;
  end if;
  return jsonb_build_object('ok', true, 'winner', w.user_id);
end $$;

grant execute on function public.earn_catch(text), public.revoke_catch(text), public.award_session(uuid) to authenticated;


-- Life Pillars: one-off back-payment of 10 Scales per species already unlocked.
-- The species count is snapshotted the moment this runs, so nobody can pad it afterwards. Safe to run more than once.
create table if not exists public.backpay(
  user_id uuid primary key references auth.users(id) on delete cascade,
  species text[] not null default '{}',
  amount integer not null default 0,
  taken_at timestamptz not null default now()
);
alter table public.backpay enable row level security;
drop policy if exists bp_read on public.backpay;
create policy bp_read on public.backpay for select to authenticated using (user_id = auth.uid());
grant select on public.backpay to authenticated;
grant all on public.backpay to service_role;

insert into public.backpay(user_id, species, amount)
select p.user_id, s.list, 10 * coalesce(array_length(s.list, 1), 0)
from public.pillars_data p
cross join lateral (
  select array(
    select distinct sp from (
      select x->>'species' as sp from jsonb_array_elements(coalesce(p.data->'fish'->'catches', '[]'::jsonb)) x
      union
      select t.key from jsonb_each(case when jsonb_typeof(p.data->'fish'->'ticks') = 'object' then p.data->'fish'->'ticks' else '{}'::jsonb end) t
      where coalesce(t.value->>'v', '') not in ('', 'false', '0', 'null')
    ) q where sp is not null and sp <> ''
  ) as list
) s
on conflict (user_id) do nothing;

insert into public.gifts(id, amount, note) values ('species-backpay', 10, '10 Scales per species already unlocked') on conflict (id) do nothing;

create or replace function public.claim_backpay() returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := auth.uid(); b public.backpay; bal integer;
begin
  if u is null then raise exception 'not signed in'; end if;
  select * into b from public.backpay where user_id = u;
  if b.user_id is null or b.amount <= 0 then return jsonb_build_object('amount', 0, 'species', 0); end if;
  insert into public.gift_claims(gift_id, user_id) values ('species-backpay', u) on conflict do nothing;
  if not found then return jsonb_build_object('already', true, 'balance', (select balance from public.wallets where user_id = u)); end if;
  insert into public.scale_log(user_id, amount, reason, ref, label) values (u, b.amount, 'gift', 'species-backpay', 'Species thank-you (' || array_length(b.species, 1) || ')') on conflict do nothing;
  bal := public.scales_add(u, b.amount);
  return jsonb_build_object('amount', b.amount, 'species', array_length(b.species, 1), 'balance', bal);
end $$;
grant execute on function public.claim_backpay() to authenticated;

-- species already paid for here never pay the "new species" reward again
create or replace function public.bp_has(u uuid, sp text) returns boolean language sql stable security definer set search_path = public as
$$ select exists(select 1 from public.backpay where user_id = u and sp = any(species)) $$;
revoke all on function public.bp_has(uuid, text) from public;

-- updated reward check (skips species already paid by the back-payment)
create or replace function public.earn_catch(cid text) returns jsonb language plpgsql security definer set search_path = public as $$
declare u uuid := auth.uid(); d jsonb; c jsonb; sp text; g numeric; prev numeric; prevpb numeric; room integer; amt integer;
        got jsonb := '[]'::jsonb; old public.scale_log;
begin
  if u is null then raise exception 'not signed in'; end if;
  select data into d from public.pillars_data where user_id = u;
  select x into c from jsonb_array_elements(coalesce(d->'fish'->'catches', '[]'::jsonb)) x where x->>'id' = cid limit 1;
  if c is null then return jsonb_build_object('wait', true); end if;
  sp := c->>'species'; g := nullif(c->>'g', '')::numeric;
  if sp is null or sp = '' then return jsonb_build_object('awards', got); end if;

  -- new species: once per species, ever
  select * into old from public.scale_log where user_id = u and reason = 'species' and ref = sp;
  -- only the first catch of a species counts (species caught before Scales existed never pay out)
  if (old.id is null or old.revoked) and not public.bp_has(u, sp) and not exists (select 1 from jsonb_array_elements(d->'fish'->'catches') x where x->>'species' = sp and x->>'id' <> cid) then
    room := public.scales_room(u); amt := least(10, room);
    if amt > 0 then
      if old.id is null then insert into public.scale_log(user_id, amount, reason, ref, label, catch_id) values (u, amt, 'species', sp, 'New species: ' || sp, cid);
      else update public.scale_log set revoked = false, amount = amt, catch_id = cid, created_at = now() where id = old.id; end if;
      perform public.scales_add(u, amt); got := got || jsonb_build_object('amount', amt, 'label', 'New species: ' || sp);
    end if;
  end if;

  -- new personal best: must beat every other catch of that species and any PB already paid for
  if g is not null and g > 0 then
    select max(nullif(x->>'g', '')::numeric) into prev from jsonb_array_elements(d->'fish'->'catches') x where x->>'species' = sp and x->>'id' <> cid;
    select max(grams) into prevpb from public.scale_log where user_id = u and reason = 'pb' and not revoked and label = 'New PB: ' || sp;
    if prev is not null and g > prev and g > coalesce(prevpb, 0)
       and (select count(*) from public.scale_log where user_id = u and reason = 'pb' and not revoked and created_at >= date_trunc('day', now())) < 3 then
      room := public.scales_room(u); amt := least(5, room);
      if amt > 0 then
        insert into public.scale_log(user_id, amount, reason, ref, label, catch_id, grams) values (u, amt, 'pb', cid, 'New PB: ' || sp, cid, g)
        on conflict (user_id, reason, ref) do nothing;
        if found then perform public.scales_add(u, amt); got := got || jsonb_build_object('amount', amt, 'label', 'New PB: ' || sp); end if;
      end if;
    end if;
  end if;
  return jsonb_build_object('awards', got, 'balance', (select balance from public.wallets where user_id = u));
end $$;
