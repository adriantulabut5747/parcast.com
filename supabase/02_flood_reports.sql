-- ============================================================
-- AgosAlert: flood reports + their photos (paper, Table 15)
-- ============================================================
-- Paste this whole file into Supabase > SQL Editor > New query > Run,
-- AFTER 01_users.sql. Safe to run once.
--
-- What it makes:
--   * public.flood_reports: one row per report (columns = Table 15).
--   * public.flood_report_feed: what the app reads. The active reports
--     plus the poster's NAME (the users table itself stays private:
--     nobody can read another person's email or phone number).
--   * Storage bucket "report-photos": the photos. Anyone can look at
--     them; a logged-in user can only upload into their own folder
--     (<their user_id>/...). Max 5 MB, JPEG/PNG/WebP only.
--   * A job that deletes reports 14 days after the photo was taken
--     (FR-S1), every hour.
--
-- Rules (NFR-3, enforced here, not just hidden in the app):
--   * Everyone (guests too) can read reports that aren't removed and
--     haven't expired.
--   * Only logged-in, active users can post, and only as themselves.
--     user_id, status, expires_at and created_at are set by the
--     database, never by the app, so nobody can post a "verified" report
--     or one that never expires.
--   * You can delete your own reports. Admins can verify/remove any
--     report (status), for now in the Table Editor (no admin screen yet).

create table public.flood_reports (
  report_id      bigint generated always as identity primary key,
  user_id        uuid not null references public.users (user_id) on delete cascade,
  incident_type  varchar(30) not null check (incident_type in (
    'flooding', 'blocked road', 'landslide', 'fallen power line',
    'stranded people', 'other')),
  severity       varchar(10) not null check (severity in ('minor', 'moderate', 'high')),
  depth_cm       smallint check (depth_cm between 0 and 300),
  barangay       varchar(50) not null check (barangay in (
    'Atlu-Bola', 'Bical', 'Bundagul', 'Cacutud', 'Calumpang', 'Camachiles',
    'Dapdap', 'Dau', 'Dolores', 'Duquit', 'Lakandula', 'Mabiga',
    'Macapagal Village', 'Mamatitang', 'Mangalit', 'Marcos Village',
    'Mawaque', 'Paralayunan', 'Poblacion', 'San Francisco', 'San Joaquin',
    'Santa Ines', 'Santa Maria', 'Santo Rosario', 'Sapang Balen',
    'Sapang Biabas', 'Tabun')),
  -- Same box as kCityBounds in the app: reports must be in Mabalacat.
  latitude       decimal(9, 6) not null check (latitude between 15.130 and 15.300),
  longitude      decimal(9, 6) not null check (longitude between 120.490 and 120.670),
  note           text check (length(note) <= 500),
  photo_url      text,
  photo_taken_at timestamptz not null,
  expires_at     timestamptz not null,
  status         varchar(10) not null default 'unverified'
                   check (status in ('unverified', 'verified', 'removed')),
  reviewed_by    uuid references public.users (user_id) on delete set null,
  created_at     timestamptz not null default now()
);

create index flood_reports_expires_at on public.flood_reports (expires_at);

-- Fills in what the app must not choose. Runs before every new row.
create function public.flood_reports_before_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.user_id := auth.uid();
  new.status := 'unverified';
  new.reviewed_by := null;
  new.created_at := now();
  -- A photo can't be from the future (5 min of slack for phone clocks)...
  if new.photo_taken_at > now() + interval '5 minutes' then
    new.photo_taken_at := now();
  end if;
  new.expires_at := new.photo_taken_at + interval '14 days';
  -- ...and one older than 14 days would be deleted straight away.
  if new.expires_at <= now() then
    raise exception 'This photo is more than 14 days old.';
  end if;
  return new;
end;
$$;

create trigger flood_reports_before_insert
  before insert on public.flood_reports
  for each row execute function public.flood_reports_before_insert();

-- True when the person asking has an active account (suspended users
-- can't post).
create function public.is_active_user()
returns boolean
language sql
stable
security definer set search_path = ''
as $$
  select exists (
    select 1 from public.users
    where user_id = (select auth.uid()) and account_status = 'active'
  );
$$;

alter table public.flood_reports enable row level security;

create policy "Anyone reads active reports; owners and admins read all"
  on public.flood_reports for select to anon, authenticated
  using (
    (status <> 'removed' and expires_at > now())
    or user_id = (select auth.uid())
    or public.is_admin()
  );

create policy "Active users post as themselves"
  on public.flood_reports for insert to authenticated
  with check (user_id = (select auth.uid()) and public.is_active_user());

create policy "Delete own report; admins delete any"
  on public.flood_reports for delete to authenticated
  using (user_id = (select auth.uid()) or public.is_admin());

create policy "Admins review reports"
  on public.flood_reports for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

revoke all on public.flood_reports from anon, authenticated;
grant select on public.flood_reports to anon, authenticated;
grant insert (incident_type, severity, depth_cm, barangay, latitude, longitude,
              note, photo_url, photo_taken_at)
  on public.flood_reports to authenticated;
grant delete on public.flood_reports to authenticated;
grant update (status, reviewed_by) on public.flood_reports to authenticated;
grant execute on function public.is_active_user() to authenticated;
grant execute on function public.is_admin() to anon;

-- What the app reads: active reports + the poster's name and barangay.
-- A view runs with its owner's rights, which is what lets it show names
-- from the private users table; it only ever exposes these two columns,
-- and repeats the "active only" filter itself.
create view public.flood_report_feed as
  select r.report_id, r.user_id, r.incident_type, r.severity, r.depth_cm,
         r.barangay, r.latitude, r.longitude, r.note, r.photo_url,
         r.photo_taken_at, r.expires_at, r.status, r.created_at,
         u.full_name as poster_name, u.barangay as poster_barangay
  from public.flood_reports r
  join public.users u on u.user_id = r.user_id
  where r.status <> 'removed' and r.expires_at > now();

revoke all on public.flood_report_feed from anon, authenticated;
grant select on public.flood_report_feed to anon, authenticated;

-- Live updates (FR-S3): the app hears about new/deleted reports.
alter publication supabase_realtime add table public.flood_reports;

-- ---------------------------------------------------------------- photos
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('report-photos', 'report-photos', true, 5242880,
        array['image/jpeg', 'image/png', 'image/webp']);

create policy "Active users upload into their own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'report-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and public.is_active_user()
  );

create policy "Users delete their own photos"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'report-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- ------------------------------------------------- the 14-day clean-up
-- pg_cron runs the delete every hour, inside the database.
-- shortcut: the photo FILES of deleted reports stay in Storage (Supabase
-- doesn't allow deleting them from SQL). Fine for a demo (1 GB free);
-- add the scheduled Edge Function from the paper when it fills up.
create extension if not exists pg_cron with schema pg_catalog;

select cron.schedule(
  'delete-expired-flood-reports',
  '0 * * * *',
  $$delete from public.flood_reports where expires_at <= now()$$
);
