-- Life Pillars: live fishing sessions + lock-screen alerts
-- Safe to run more than once.

create table if not exists public.sessions(
  id uuid primary key,
  owner uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  started_at timestamptz not null default now(),
  ends_at timestamptz not null,
  ended_at timestamptz,
  created_at timestamptz not null default now()
);
create table if not exists public.session_members(
  session_id uuid not null references public.sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (session_id, user_id)
);
create table if not exists public.session_events(
  id uuid primary key,
  session_id uuid not null references public.sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null default 'catch' check (kind in ('catch','note')),
  catch_id text,
  info jsonb,
  path text,
  pushed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists session_events_sid on public.session_events(session_id, created_at desc);
create table if not exists public.push_subs(
  endpoint text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);

-- helpers (security definer so policies don't recurse)
create or replace function public.in_session(s uuid) returns boolean language sql stable security definer set search_path = public as
$$ select exists(select 1 from public.session_members where session_id = s and user_id = auth.uid()) $$;
create or replace function public.in_session_t(s text) returns boolean language sql stable security definer set search_path = public as
$$ select exists(select 1 from public.session_members where session_id::text = s and user_id = auth.uid()) $$;
create or replace function public.session_owner(s uuid) returns uuid language sql stable security definer set search_path = public as
$$ select owner from public.sessions where id = s $$;
create or replace function public.session_live(s uuid) returns boolean language sql stable security definer set search_path = public as
$$ select exists(select 1 from public.sessions where id = s and ended_at is null and ends_at > now()) $$;
create or replace function public.mates(a uuid, b uuid) returns boolean language sql stable security definer set search_path = public as
$$ select exists(select 1 from public.friendships where status = 'accepted' and ((from_id = a and to_id = b) or (from_id = b and to_id = a))) $$;

alter table public.sessions enable row level security;
alter table public.session_members enable row level security;
alter table public.session_events enable row level security;
alter table public.push_subs enable row level security;

drop policy if exists ses_read on public.sessions;
create policy ses_read on public.sessions for select to authenticated using (owner = auth.uid() or public.in_session(id));
drop policy if exists ses_new on public.sessions;
create policy ses_new on public.sessions for insert to authenticated with check (owner = auth.uid());
drop policy if exists ses_edit on public.sessions;
create policy ses_edit on public.sessions for update to authenticated using (owner = auth.uid()) with check (owner = auth.uid());
drop policy if exists ses_del on public.sessions;
create policy ses_del on public.sessions for delete to authenticated using (owner = auth.uid());

drop policy if exists sesm_read on public.session_members;
create policy sesm_read on public.session_members for select to authenticated using (public.in_session(session_id) or public.session_owner(session_id) = auth.uid());
drop policy if exists sesm_add on public.session_members;
create policy sesm_add on public.session_members for insert to authenticated with check (public.session_owner(session_id) = auth.uid() and (user_id = auth.uid() or public.mates(auth.uid(), user_id)));
drop policy if exists sesm_del on public.session_members;
create policy sesm_del on public.session_members for delete to authenticated using (user_id = auth.uid() or public.session_owner(session_id) = auth.uid());

drop policy if exists sese_read on public.session_events;
create policy sese_read on public.session_events for select to authenticated using (public.in_session(session_id));
drop policy if exists sese_add on public.session_events;
create policy sese_add on public.session_events for insert to authenticated with check (user_id = auth.uid() and public.in_session(session_id) and public.session_live(session_id));
drop policy if exists sese_del on public.session_events;
create policy sese_del on public.session_events for delete to authenticated using (user_id = auth.uid() or public.session_owner(session_id) = auth.uid());

drop policy if exists push_own on public.push_subs;
create policy push_own on public.push_subs for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- session photos live in the existing catch-photos bucket under sessions/<session id>/<user id>_<photo id>.jpg
drop policy if exists ses_photo_read on storage.objects;
create policy ses_photo_read on storage.objects for select to authenticated using (bucket_id = 'catch-photos' and (storage.foldername(name))[1] = 'sessions' and public.in_session_t((storage.foldername(name))[2]));
drop policy if exists ses_photo_add on storage.objects;
create policy ses_photo_add on storage.objects for insert to authenticated with check (bucket_id = 'catch-photos' and (storage.foldername(name))[1] = 'sessions' and public.in_session_t((storage.foldername(name))[2]) and split_part(storage.filename(name), '_', 1) = auth.uid()::text);
drop policy if exists ses_photo_del on storage.objects;
create policy ses_photo_del on storage.objects for delete to authenticated using (bucket_id = 'catch-photos' and (storage.foldername(name))[1] = 'sessions' and public.in_session_t((storage.foldername(name))[2]) and split_part(storage.filename(name), '_', 1) = auth.uid()::text);

-- live updates
do $$ begin
  begin alter publication supabase_realtime add table public.session_events; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.sessions; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.session_members; exception when duplicate_object then null; end;
end $$;

-- table access (this project doesn't grant it automatically)
grant select, insert, update, delete on public.sessions, public.session_members, public.session_events, public.push_subs to authenticated;
grant all on public.sessions, public.session_members, public.session_events, public.push_subs to service_role;
grant execute on function public.in_session(uuid), public.in_session_t(text), public.session_owner(uuid), public.session_live(uuid), public.mates(uuid, uuid) to authenticated;
