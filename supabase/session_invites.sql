-- Life Pillars: session invites ("message in a bottle"). Safe to run more than once.
alter table public.session_members add column if not exists status text not null default 'joined';
alter table public.session_members add column if not exists invited_by uuid references auth.users(id) on delete set null;
alter table public.session_members add column if not exists note text;
do $$ begin
  alter table public.session_members add constraint session_members_status_chk check (status in ('invited','joined'));
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.session_members add constraint session_members_note_chk check (note is null or char_length(note) <= 280);
exception when duplicate_object then null; end $$;

-- only people who've said yes count as "in" the session
create or replace function public.in_session(s uuid) returns boolean language sql stable security definer set search_path = public as
$$ select exists(select 1 from public.session_members where session_id = s and user_id = auth.uid() and status = 'joined') $$;
create or replace function public.in_session_t(s text) returns boolean language sql stable security definer set search_path = public as
$$ select exists(select 1 from public.session_members where session_id::text = s and user_id = auth.uid() and status = 'joined') $$;
create or replace function public.invited_to(s uuid) returns boolean language sql stable security definer set search_path = public as
$$ select exists(select 1 from public.session_members where session_id = s and user_id = auth.uid() and status = 'invited') $$;
grant execute on function public.invited_to(uuid) to authenticated;

drop policy if exists ses_read on public.sessions;
create policy ses_read on public.sessions for select to authenticated using (owner = auth.uid() or public.in_session(id) or public.invited_to(id));

drop policy if exists sesm_read on public.session_members;
create policy sesm_read on public.session_members for select to authenticated using (public.in_session(session_id) or public.invited_to(session_id) or public.session_owner(session_id) = auth.uid());
drop policy if exists sesm_add on public.session_members;
create policy sesm_add on public.session_members for insert to authenticated with check (
  public.session_owner(session_id) = auth.uid() and (
    (user_id = auth.uid() and status = 'joined') or
    (user_id <> auth.uid() and status = 'invited' and invited_by = auth.uid() and public.mates(auth.uid(), user_id))));
drop policy if exists sesm_accept on public.session_members;
create policy sesm_accept on public.session_members for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid() and status = 'joined');
