-- Life Pillars: clans, Grandma's cottage, the aquarium and the garden pond. Safe to run more than once.
create table if not exists public.clans(
  id uuid primary key,
  name text not null check (char_length(name) between 1 and 40),
  owner uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.clan_members(
  clan_id uuid not null references public.clans(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'joined' check (status in ('invited','joined')),
  invited_by uuid references auth.users(id) on delete set null,
  note text check (note is null or char_length(note) <= 280),
  joined_at timestamptz not null default now(),
  primary key (clan_id, user_id)
);
alter table public.clan_members drop constraint if exists clan_members_status_check;
alter table public.clan_members add constraint clan_members_status_check check (status in ('invited','joined','requested'));
create unique index if not exists clan_one_per_person on public.clan_members(user_id) where status = 'joined';
create table if not exists public.clan_fish(
  id uuid primary key,
  clan_id uuid not null references public.clans(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  catch_id text not null,
  species text not null,
  grams numeric,
  cm numeric,
  caught_on text,
  place text not null default 'tank' check (place in ('tank','pond')),
  feeds integer not null default 0,
  last_fed date,
  last_fed_by uuid,
  promoted_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index if not exists clan_one_tank_fish on public.clan_fish(clan_id, user_id) where place = 'tank';
create unique index if not exists clan_fish_once on public.clan_fish(user_id, catch_id);
create table if not exists public.small_sizes(species text primary key, max_g numeric not null, max_cm numeric not null);
insert into public.small_sizes(species, max_g, max_cm) values
  ('Barbel', 900, 40),
  ('Bleak', 20, 11),
  ('Bream (common)', 900, 35),
  ('Bream (silver)', 115, 20),
  ('Bullhead', 15, 8),
  ('Carp (common)', 1800, 40),
  ('Carp (mirror)', 1800, 40),
  ('Carp (leather)', 1800, 40),
  ('Carp (ghost)', 1800, 40),
  ('Carp (grass)', 2300, 50),
  ('Carp (crucian)', 225, 18),
  ('Catfish (wels)', 4500, 80),
  ('Chub', 450, 30),
  ('Dace', 85, 17),
  ('Eel', 340, 45),
  ('Gudgeon', 30, 11),
  ('Ide', 450, 30),
  ('Golden orfe', 450, 30),
  ('Minnow', 5, 6),
  ('Perch', 170, 22),
  ('Pike', 1360, 55),
  ('Roach', 115, 18),
  ('Rudd', 115, 18),
  ('Ruffe', 25, 11),
  ('Stone loach', 8, 8),
  ('Stickleback', 2, 5),
  ('Tench', 680, 32),
  ('Zander', 900, 45),
  ('Brown trout', 340, 30),
  ('Rainbow trout', 450, 32),
  ('Sea trout', 680, 38),
  ('Tiger trout', 450, 32),
  ('Atlantic salmon', 2300, 55),
  ('Grayling', 280, 30),
  ('Arctic char', 280, 28),
  ('Bass', 900, 40),
  ('Cod', 1360, 45),
  ('Pollack', 900, 40),
  ('Coalfish', 680, 38),
  ('Whiting', 340, 30),
  ('Pouting', 225, 22),
  ('Haddock', 680, 38),
  ('Ling', 2300, 70),
  ('Mackerel', 280, 30),
  ('Scad', 170, 25),
  ('Garfish', 340, 55),
  ('Herring', 170, 24),
  ('Ballan wrasse', 450, 25),
  ('Corkwing wrasse', 85, 14),
  ('Cuckoo wrasse', 170, 22),
  ('Conger eel', 4500, 100),
  ('Thornback ray', 1800, 50),
  ('Small-eyed ray', 1800, 50),
  ('Spotted ray', 900, 40),
  ('Undulate ray', 1800, 50),
  ('Lesser spotted dogfish', 450, 45),
  ('Bull huss', 2300, 65),
  ('Smoothhound', 2300, 65),
  ('Tope', 6800, 100),
  ('Plaice', 450, 30),
  ('Flounder', 340, 28),
  ('Dab', 170, 22),
  ('Sole', 340, 28),
  ('Turbot', 1360, 40),
  ('Brill', 900, 35),
  ('Black bream', 450, 28),
  ('Gilthead bream', 450, 28),
  ('Red mullet', 225, 22),
  ('Thick-lipped grey mullet', 900, 40),
  ('Thin-lipped grey mullet', 900, 40),
  ('Golden grey mullet', 450, 32),
  ('Red gurnard', 340, 28),
  ('Grey gurnard', 225, 25),
  ('Tub gurnard', 680, 35),
  ('Lesser weever', 30, 12),
  ('Shore rockling', 85, 20),
  ('Shanny', 15, 9),
  ('Long-spined sea scorpion', 30, 12),
  ('Dragonet', 30, 15),
  ('Asp', 900, 45),
  ('Nase', 340, 30),
  ('Vimba', 340, 30),
  ('Huchen', 4500, 75),
  ('Sterlet', 900, 50),
  ('Siberian sturgeon', 4500, 80),
  ('Iberian barbel', 680, 38),
  ('Comizo barbel', 2300, 55),
  ('Pumpkinseed', 85, 13),
  ('Largemouth bass', 680, 32),
  ('Black bullhead', 225, 22),
  ('Leerfish', 2300, 60),
  ('Greater amberjack', 4500, 70),
  ('Common dentex', 1360, 40),
  ('White seabream', 340, 25),
  ('Saddled seabream', 225, 22),
  ('European barracuda', 900, 50),
  ('Atlantic bonito', 1800, 50),
  ('Little tunny', 1800, 50),
  ('Bluefin tuna', 23000, 120),
  ('Bluefish', 1360, 45),
  ('Dusky grouper', 2300, 50),
  ('Meagre', 4500, 75),
  ('Corb', 900, 38),
  ('Mahseer', 2300, 55),
  ('Arapaima', 9000, 120),
  ('Peacock bass', 900, 38),
  ('Nile perch', 4500, 70),
  ('Tigerfish', 1360, 45),
  ('Snook', 1800, 55),
  ('Tarpon', 4500, 90),
  ('Bonefish', 1360, 50),
  ('Giant trevally', 4500, 65),
  ('Barramundi', 2300, 55),
  ('Mahi-mahi', 2300, 70),
  ('Sailfish', 13600, 150),
  ('Blue marlin', 45000, 200),
  ('Yellowfin tuna', 9000, 90),
  ('Red snapper', 1360, 40),
  ('Red drum', 2300, 55),
  ('Walleye', 680, 38),
  ('Muskellunge', 2300, 70),
  ('Smallmouth bass', 450, 30),
  ('Channel catfish', 900, 45)
on conflict (species) do update set max_g = excluded.max_g, max_cm = excluded.max_cm;

alter table public.clans enable row level security;
alter table public.clan_members enable row level security;
alter table public.clan_fish enable row level security;
alter table public.small_sizes enable row level security;

create or replace function public.my_clan() returns uuid language sql stable security definer set search_path = public as
$$ select clan_id from public.clan_members where user_id = auth.uid() and status = 'joined' limit 1 $$;
create or replace function public.clan_invited(c uuid) returns boolean language sql stable security definer set search_path = public as
$$ select exists(select 1 from public.clan_members where clan_id = c and user_id = auth.uid() and status = 'invited') $$;

drop policy if exists clan_read on public.clans;
create policy clan_read on public.clans for select to authenticated using (id = public.my_clan() or public.clan_invited(id));
drop policy if exists clanm_read on public.clan_members;
create policy clanm_read on public.clan_members for select to authenticated using (clan_id = public.my_clan() or (user_id = auth.uid()) or public.clan_invited(clan_id));
drop policy if exists clanf_read on public.clan_fish;
create policy clanf_read on public.clan_fish for select to authenticated using (clan_id = public.my_clan());
drop policy if exists small_read on public.small_sizes;
create policy small_read on public.small_sizes for select to authenticated using (true);
grant select on public.clans, public.clan_members, public.clan_fish, public.small_sizes to authenticated;
grant all on public.clans, public.clan_members, public.clan_fish, public.small_sizes to service_role;
grant execute on function public.my_clan(), public.clan_invited(uuid) to authenticated;

-- everything below changes things, and only through these checked functions
create or replace function public.clan_create(cid uuid, nm text) returns uuid language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if public.my_clan() is not null then raise exception 'already in a clan'; end if;
  insert into public.clans(id, name, owner) values (cid, trim(nm), auth.uid());
  insert into public.clan_members(clan_id, user_id, status) values (cid, auth.uid(), 'joined');
  delete from public.clan_members where user_id = auth.uid() and status in ('invited','requested');
  return cid;
end $$;

create or replace function public.clan_invite(u uuid, nt text) returns boolean language plpgsql security definer set search_path = public as $$
declare c uuid := public.my_clan();
begin
  if c is null then raise exception 'not in a clan'; end if;
  if not public.mates(auth.uid(), u) then raise exception 'not friends'; end if;
  if (select count(*) from public.clan_members where clan_id = c and status in ('joined','invited')) >= 12 then raise exception 'clan is full'; end if;
  if exists (select 1 from public.clan_members where clan_id = c and user_id = u and status = 'requested') then
    return public.clan_decide(u, true);
  end if;
  insert into public.clan_members(clan_id, user_id, status, invited_by, note) values (c, u, 'invited', auth.uid(), nullif(trim(coalesce(nt, '')), ''))
  on conflict (clan_id, user_id) do nothing;
  return found;
end $$;

create or replace function public.clan_answer(c uuid, yes boolean) returns boolean language plpgsql security definer set search_path = public as $$
begin
  if not public.clan_invited(c) then return false; end if;
  if not yes then delete from public.clan_members where clan_id = c and user_id = auth.uid(); return true; end if;
  if public.my_clan() is not null then raise exception 'already in a clan'; end if;
  if (select count(*) from public.clan_members where clan_id = c and status = 'joined') >= 12 then raise exception 'clan is full'; end if;
  update public.clan_members set status = 'joined', joined_at = now() where clan_id = c and user_id = auth.uid();
  delete from public.clan_members where user_id = auth.uid() and status in ('invited','requested');
  return true;
end $$;

create or replace function public.clan_leave() returns boolean language plpgsql security definer set search_path = public as $$
declare c uuid := public.my_clan(); nxt uuid;
begin
  if c is null then return false; end if;
  delete from public.clan_fish where clan_id = c and user_id = auth.uid() and place = 'tank';
  delete from public.clan_members where clan_id = c and user_id = auth.uid();
  if not exists (select 1 from public.clan_members where clan_id = c and status = 'joined') then delete from public.clans where id = c; return true; end if;
  if (select owner from public.clans where id = c) = auth.uid() then
    select user_id into nxt from public.clan_members where clan_id = c and status = 'joined' order by joined_at limit 1;
    update public.clans set owner = nxt where id = c;
  end if;
  return true;
end $$;

create or replace function public.clan_rename(nm text) returns boolean language plpgsql security definer set search_path = public as $$
begin
  update public.clans set name = trim(nm) where id = public.my_clan() and owner = auth.uid() and char_length(trim(nm)) between 1 and 40;
  return found;
end $$;

create or replace function public.clan_remove(u uuid) returns boolean language plpgsql security definer set search_path = public as $$
declare c uuid := public.my_clan();
begin
  if c is null or (select owner from public.clans where id = c) <> auth.uid() or u = auth.uid() then return false; end if;
  delete from public.clan_fish where clan_id = c and user_id = u and place = 'tank';
  delete from public.clan_members where clan_id = c and user_id = u;
  return found;
end $$;

-- ======================= the club page: badge, description, XP and stats =======================
alter table public.clans add column if not exists about text;
alter table public.clans add column if not exists emblem jsonb;
alter table public.clans drop constraint if exists clans_about_len;
alter table public.clans add constraint clans_about_len check (about is null or char_length(about) <= 160);

-- the head edits the club's name, description and badge
create or replace function public.clan_update(nm text, ab text, em jsonb) returns boolean language plpgsql security definer set search_path = public as $$
begin
  if char_length(trim(coalesce(nm, ''))) not between 1 and 40 then raise exception 'name length'; end if;
  if char_length(trim(coalesce(ab, ''))) > 160 then raise exception 'description too long'; end if;
  if em is not null and not (
       em->>'s' in ('shield','round','pennant','badge')
   and em->>'i' in ('fish','hook','float','reel','leaf','crown','pike','moon')
   and coalesce(em->>'a', '') ~ '^#[0-9a-fA-F]{6}$' and coalesce(em->>'b', '') ~ '^#[0-9a-fA-F]{6}$') then raise exception 'bad badge'; end if;
  update public.clans set name = trim(nm), about = nullif(trim(coalesce(ab, '')), ''),
    emblem = case when em is null then null else jsonb_build_object('s', em->>'s', 'i', em->>'i', 'a', em->>'a', 'b', em->>'b') end
  where id = public.my_clan() and owner = auth.uid();
  return found;
end $$;

-- XP per member, worked out from what they've logged since joining:
--   10 per catch (up to 5 a day count), 25 per species logged, 100 per fish raised to the pond
create or replace function public.clan_xp_rows(c uuid) returns table(user_id uuid, catches integer, counted integer, species integer, pond integer, xp integer)
language sql stable security definer set search_path = public as $$
  with mem as (select m.user_id, m.joined_at::date j from public.clan_members m where m.clan_id = c and m.status = 'joined'),
  cat as (
    select m.user_id, (x->>'date')::date d, x->>'species' sp
    from mem m join public.pillars_data p on p.user_id = m.user_id
    cross join lateral jsonb_array_elements(case when jsonb_typeof(p.data->'fish'->'catches') = 'array' then p.data->'fish'->'catches' else '[]'::jsonb end) x
    where coalesce(x->>'date', '') ~ '^\d{4}-\d{2}-\d{2}$' and coalesce(x->>'species', '') <> ''
      and (x->>'date')::date >= m.j and (x->>'date')::date <= current_date + 1),
  per as (select m.user_id,
      (select count(*)::int from cat where cat.user_id = m.user_id) catches,
      (select coalesce(sum(n), 0)::int from (select least(count(*), 5) n from cat where cat.user_id = m.user_id group by d) q) counted,
      (select count(distinct sp)::int from cat where cat.user_id = m.user_id) species,
      (select count(*)::int from public.clan_fish f where f.clan_id = c and f.user_id = m.user_id and f.place = 'pond') pond
    from mem m)
  select per.user_id, per.catches, per.counted, per.species, per.pond, per.counted * 10 + per.species * 25 + per.pond * 100 from per
  union all
  -- fish raised by people who've since left still count for the club
  select null::uuid, 0, 0, 0, count(*)::int, count(*)::int * 100 from public.clan_fish f
  where f.clan_id = c and f.place = 'pond' and not exists (select 1 from mem where mem.user_id = f.user_id)
$$;
revoke execute on function public.clan_xp_rows(uuid) from public;

create or replace function public.clan_xp(c uuid) returns integer language sql stable security definer set search_path = public as $$
  select coalesce(sum(xp), 0)::int from public.clan_xp_rows(c)
$$;
revoke execute on function public.clan_xp(uuid) from public;

-- full stats for your own club
create or replace function public.clan_stats() returns json language plpgsql stable security definer set search_path = public as $$
declare c uuid := public.my_clan(); r json;
begin
  if c is null then return null; end if;
  select json_build_object(
    'xp', (select coalesce(sum(xp), 0) from public.clan_xp_rows(c)),
    'members', (select coalesce(json_agg(json_build_object('user_id', x.user_id, 'xp', x.xp, 'catches', x.catches, 'species', x.species, 'pond', x.pond) order by x.xp desc), '[]'::json) from public.clan_xp_rows(c) x where x.user_id is not null),
    'past_pond', (select coalesce(sum(pond), 0) from public.clan_xp_rows(c) x where x.user_id is null),
    'species', (select count(distinct x->>'species') from public.clan_members m join public.pillars_data p on p.user_id = m.user_id
        cross join lateral jsonb_array_elements(case when jsonb_typeof(p.data->'fish'->'catches') = 'array' then p.data->'fish'->'catches' else '[]'::jsonb end) x
        where m.clan_id = c and m.status = 'joined' and coalesce(x->>'date', '') ~ '^\d{4}-\d{2}-\d{2}$' and (x->>'date')::date >= m.joined_at::date and coalesce(x->>'species', '') <> ''),
    'pond', (select count(*) from public.clan_fish where clan_id = c and place = 'pond'),
    'feeds', (select coalesce(sum(feeds), 0) from public.clan_fish where clan_id = c),
    'recent', (select coalesce(json_agg(z.e order by z.ts desc), '[]'::json) from (select * from (
        select (x->>'date') || 'T' || coalesce(nullif(x->>'time', ''), '12:00') as ts,
          json_build_object('k', 'catch', 'user_id', m.user_id, 'species', x->>'species', 'g', nullif(x->>'g', '')::numeric, 'date', x->>'date') e
        from public.clan_members m join public.pillars_data p on p.user_id = m.user_id
        cross join lateral jsonb_array_elements(case when jsonb_typeof(p.data->'fish'->'catches') = 'array' then p.data->'fish'->'catches' else '[]'::jsonb end) x
        where m.clan_id = c and m.status = 'joined' and coalesce(x->>'date', '') ~ '^\d{4}-\d{2}-\d{2}$' and (x->>'date')::date >= m.joined_at::date and coalesce(x->>'species', '') <> ''
        union all
        select to_char(f.promoted_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI'),
          json_build_object('k', 'pond', 'user_id', f.user_id, 'species', f.species, 'g', round(public.fish_grams(f)), 'date', to_char(f.promoted_at at time zone 'UTC', 'YYYY-MM-DD'))
        from public.clan_fish f where f.clan_id = c and f.place = 'pond' and f.promoted_at is not null
      ) u order by ts desc limit 10) z)
  ) into r;
  return r;
end $$;

-- the club directory: every club, how full it is, and whether you've already asked to join
drop function if exists public.clan_browse();
create or replace function public.clan_browse() returns table(id uuid, name text, owner uuid, owner_name text, members integer, pond integer, asked boolean, invited boolean, emblem jsonb, xp integer)
language sql stable security definer set search_path = public as $$
  select c.id, c.name, c.owner, p.name,
    (select count(*)::int from public.clan_members m where m.clan_id = c.id and m.status = 'joined'),
    (select count(*)::int from public.clan_fish f where f.clan_id = c.id and f.place = 'pond'),
    exists(select 1 from public.clan_members m where m.clan_id = c.id and m.user_id = auth.uid() and m.status = 'requested'),
    exists(select 1 from public.clan_members m where m.clan_id = c.id and m.user_id = auth.uid() and m.status = 'invited'),
    c.emblem, public.clan_xp(c.id)
  from public.clans c left join public.profiles p on p.user_id = c.owner
  where auth.uid() is not null
  order by 5 desc, c.created_at
$$;

-- one club's details for anyone browsing: members, what's in the tank and the pond
create or replace function public.clan_info(c uuid) returns json language sql stable security definer set search_path = public as $$
  select case when auth.uid() is null then null else (
    select json_build_object(
      'id', k.id, 'name', k.name, 'owner', k.owner, 'created_at', k.created_at, 'about', k.about, 'emblem', k.emblem, 'xp', public.clan_xp(k.id),
      'members', (select coalesce(json_agg(json_build_object('user_id', m.user_id, 'name', p.name, 'avatar', p.avatar, 'joined_at', m.joined_at) order by m.joined_at), '[]'::json)
                  from public.clan_members m left join public.profiles p on p.user_id = m.user_id where m.clan_id = k.id and m.status = 'joined'),
      'tank', (select coalesce(json_agg(json_build_object('species', f.species, 'grams', round(public.fish_grams(f)), 'by', p.name) order by f.created_at), '[]'::json)
               from public.clan_fish f left join public.profiles p on p.user_id = f.user_id where f.clan_id = k.id and f.place = 'tank'),
      'pond', (select coalesce(json_agg(json_build_object('species', f.species, 'grams', round(public.fish_grams(f)), 'by', p.name, 'promoted_at', f.promoted_at) order by f.promoted_at desc), '[]'::json)
               from public.clan_fish f left join public.profiles p on p.user_id = f.user_id where f.clan_id = k.id and f.place = 'pond'),
      'asked', exists(select 1 from public.clan_members m where m.clan_id = k.id and m.user_id = auth.uid() and m.status = 'requested'),
      'invited', exists(select 1 from public.clan_members m where m.clan_id = k.id and m.user_id = auth.uid() and m.status = 'invited'))
    from public.clans k where k.id = c) end
$$;

-- ask to join a club (up to 3 open requests at a time). If that club already invited you, you're straight in.
create or replace function public.clan_request(c uuid) returns text language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if public.my_clan() is not null then raise exception 'already in a clan'; end if;
  if not exists (select 1 from public.clans where id = c) then raise exception 'club not found'; end if;
  if public.clan_invited(c) then perform public.clan_answer(c, true); return 'joined'; end if;
  if (select count(*) from public.clan_members where clan_id = c and status in ('joined','invited')) >= 12 then raise exception 'clan is full'; end if;
  if (select count(*) from public.clan_members where user_id = auth.uid() and status = 'requested') >= 3 then raise exception 'too many requests'; end if;
  insert into public.clan_members(clan_id, user_id, status) values (c, auth.uid(), 'requested') on conflict (clan_id, user_id) do nothing;
  return 'requested';
end $$;

create or replace function public.clan_unrequest(c uuid) returns boolean language plpgsql security definer set search_path = public as $$
begin
  delete from public.clan_members where clan_id = c and user_id = auth.uid() and status = 'requested';
  return found;
end $$;

-- the head of the club lets someone in, or turns them down
create or replace function public.clan_decide(u uuid, yes boolean) returns boolean language plpgsql security definer set search_path = public as $$
declare c uuid := public.my_clan();
begin
  if c is null or (select owner from public.clans where id = c) <> auth.uid() then raise exception 'only the head of the club can do that'; end if;
  if not exists (select 1 from public.clan_members where clan_id = c and user_id = u and status = 'requested') then return false; end if;
  if not yes then delete from public.clan_members where clan_id = c and user_id = u; return true; end if;
  if exists (select 1 from public.clan_members where user_id = u and status = 'joined') then
    delete from public.clan_members where clan_id = c and user_id = u; return false;
  end if;
  if (select count(*) from public.clan_members where clan_id = c and status in ('joined','invited')) >= 12 then raise exception 'clan is full'; end if;
  update public.clan_members set status = 'joined', joined_at = now() where clan_id = c and user_id = u;
  delete from public.clan_members where user_id = u and status in ('invited','requested');
  return true;
end $$;


-- put one of your small catches in the tank (one each); the server checks the catch and its size
create or replace function public.fish_donate(cid text) returns uuid language plpgsql security definer set search_path = public as $$
declare c uuid := public.my_clan(); d jsonb; x jsonb; sp text; g numeric; cmv numeric; lim public.small_sizes; fid uuid := gen_random_uuid();
begin
  if c is null then raise exception 'not in a clan'; end if;
  if exists (select 1 from public.clan_fish where clan_id = c and user_id = auth.uid() and place = 'tank') then raise exception 'you already have a fish in the tank'; end if;
  select data into d from public.pillars_data where user_id = auth.uid();
  select y into x from jsonb_array_elements(coalesce(d->'fish'->'catches', '[]'::jsonb)) y where y->>'id' = cid limit 1;
  if x is null then raise exception 'catch not found, try again in a moment'; end if;
  sp := x->>'species'; g := nullif(x->>'g', '')::numeric; cmv := nullif(x->>'cm', '')::numeric;
  select * into lim from public.small_sizes where species = sp;
  if lim.species is null then lim.max_g := 225; lim.max_cm := 20; end if;
  if g is null and cmv is null then raise exception 'log a weight or length first'; end if;
  if (g is not null and g > lim.max_g) or (g is null and cmv > lim.max_cm) then raise exception 'too big for the tank'; end if;
  insert into public.clan_fish(id, clan_id, user_id, catch_id, species, grams, cm, caught_on) values (fid, c, auth.uid(), cid, sp, g, cmv, x->>'date');
  return fid;
end $$;

-- growth: a fish gains an ounce for every 3 days it's fed. It outgrows the tank at 4 lb, or more for bigger species
-- (twice the small size for its species), but never needs more than 6 lb of growth.
create or replace function public.fish_start(f public.clan_fish) returns numeric language sql stable set search_path = public as $$
  select coalesce(f.grams, round(coalesce(s.max_g, 225) * power(least(coalesce(f.cm, coalesce(s.max_cm, 20) / 2) / coalesce(s.max_cm, 20), 1), 3)))
  from (select 1) one left join public.small_sizes s on s.species = f.species
$$;
create or replace function public.fish_grams(f public.clan_fish) returns numeric language sql stable set search_path = public as $$
  select public.fish_start(f) + floor(f.feeds / 3) * 28.35
$$;
create or replace function public.fish_target(f public.clan_fish) returns numeric language sql stable set search_path = public as $$
  select least(greatest(1814, 2 * coalesce(s.max_g, 225)), public.fish_start(f) + 2722)
  from (select 1) one left join public.small_sizes s on s.species = f.species
$$;

-- any club member can feed any tank fish, once per fish per day; when it outgrows the tank it moves to the pond by itself
create or replace function public.fish_feed(f uuid) returns integer language plpgsql security definer set search_path = public as $$
declare r public.clan_fish;
begin
  update public.clan_fish set feeds = feeds + 1, last_fed = current_date, last_fed_by = auth.uid()
  where id = f and clan_id = public.my_clan() and place = 'tank' and (last_fed is null or last_fed < current_date)
  returning * into r;
  if r.id is null then return null; end if;
  if public.fish_grams(r) >= public.fish_target(r) then
    update public.clan_fish set place = 'pond', promoted_at = now() where id = f;
  end if;
  return r.feeds;
end $$;

-- kept for older app versions: moves a fish that has already outgrown the tank
create or replace function public.fish_promote(f uuid) returns boolean language plpgsql security definer set search_path = public as $$
begin
  update public.clan_fish c set place = 'pond', promoted_at = now() where c.id = f and c.user_id = auth.uid() and c.clan_id = public.my_clan() and c.place = 'tank'
    and public.fish_grams(c) >= public.fish_target(c);
  return found;
end $$;

-- the owner can take their fish back out of the tank if they want to swap it
create or replace function public.fish_release(f uuid) returns boolean language plpgsql security definer set search_path = public as $$
begin
  delete from public.clan_fish where id = f and user_id = auth.uid() and place = 'tank';
  return found;
end $$;

grant execute on function public.clan_create(uuid, text), public.clan_invite(uuid, text), public.clan_answer(uuid, boolean), public.clan_leave(),
  public.clan_rename(text), public.clan_remove(uuid), public.fish_donate(text), public.fish_feed(uuid), public.fish_promote(uuid), public.fish_release(uuid),
  public.clan_browse(), public.clan_info(uuid), public.clan_stats(), public.clan_update(text, text, jsonb), public.clan_request(uuid), public.clan_unrequest(uuid), public.clan_decide(uuid, boolean) to authenticated;
