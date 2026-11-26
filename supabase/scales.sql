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
