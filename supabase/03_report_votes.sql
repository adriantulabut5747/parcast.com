-- ============================================================
-- AgosAlert: thumbs up/down on flood reports (paper, Table 16)
-- ============================================================
-- Paste this whole file into Supabase > SQL Editor > New query > Run,
-- AFTER 02_flood_reports.sql. Safe to run once.
--
-- What it makes:
--   * public.report_votes: one row per (report, user). vote = 1 (helpful)
--     or -1 (not helpful). The primary key keeps it to one vote per user
--     per report; changing it updates the row, taking it back deletes it.
--   * flood_report_feed gets three more columns: up_votes, down_votes
--     (counted by the database) and my_vote (the vote of whoever asks,
--     null for guests).
--
-- Rules (NFR-3):
--   * Only logged-in, active users vote, only as themselves, and not on
--     their own report.
--   * Votes are public, like likes on a post: anyone can read them. That
--     is also what lets Realtime tell every app when a vote changes (it
--     only sends rows the listener may read).

create table public.report_votes (
  report_id  bigint not null references public.flood_reports (report_id) on delete cascade,
  user_id    uuid not null references public.users (user_id) on delete cascade,
  vote       smallint not null check (vote in (1, -1)),
  created_at timestamptz not null default now(),
  primary key (report_id, user_id)
);

-- created_at = when the vote was cast or last changed (Table 16).
create function public.report_votes_stamp()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.created_at := now();
  return new;
end;
$$;

create trigger report_votes_stamp
  before insert or update on public.report_votes
  for each row execute function public.report_votes_stamp();

alter table public.report_votes enable row level security;

create policy "Anyone reads votes"
  on public.report_votes for select to anon, authenticated
  using (true);

create policy "Active users vote as themselves, not on their own report"
  on public.report_votes for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and public.is_active_user()
    and not exists (
      select 1 from public.flood_reports r
      where r.report_id = report_votes.report_id
        and r.user_id = (select auth.uid())
    )
  );

create policy "Users change their own vote"
  on public.report_votes for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and public.is_active_user());

create policy "Users take back their own vote"
  on public.report_votes for delete to authenticated
  using (user_id = (select auth.uid()));

revoke all on public.report_votes from anon, authenticated;
grant select on public.report_votes to anon, authenticated;
grant insert (report_id, user_id, vote) on public.report_votes to authenticated;
grant update (vote) on public.report_votes to authenticated;
grant delete on public.report_votes to authenticated;

-- The feed again, same columns as in 02 plus the vote counts and the
-- asker's own vote. auth.uid() inside a view is still the person asking.
create or replace view public.flood_report_feed as
  select r.report_id, r.user_id, r.incident_type, r.severity, r.depth_cm,
         r.barangay, r.latitude, r.longitude, r.note, r.photo_url,
         r.photo_taken_at, r.expires_at, r.status, r.created_at,
         u.full_name as poster_name, u.barangay as poster_barangay,
         (select count(*) from public.report_votes v
           where v.report_id = r.report_id and v.vote = 1) as up_votes,
         (select count(*) from public.report_votes v
           where v.report_id = r.report_id and v.vote = -1) as down_votes,
         (select v.vote from public.report_votes v
           where v.report_id = r.report_id and v.user_id = auth.uid()) as my_vote
  from public.flood_reports r
  join public.users u on u.user_id = r.user_id
  where r.status <> 'removed' and r.expires_at > now();

-- Live updates: the app reloads the feed when a vote changes.
alter publication supabase_realtime add table public.report_votes;
