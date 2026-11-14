-- ============================================================
-- AgosAlert: alerts + who has read them (paper, Tables 19 and 20)
-- ============================================================
-- Paste this whole file into Supabase > SQL Editor > New query > Run,
-- AFTER 01-03. Safe to run once.
--
-- What it makes:
--   * public.alerts: the alerts and advisories the bell shows (title,
--     one-line summary, full details, category, severity, area, "what to
--     do" steps). Use case "Post Alerts and Advisories" (Table 13).
--   * public.alert_reads: one row per (user, alert) they've opened. The
--     bell's number = alerts without a row here. Guests have no account,
--     so the app keeps their "read" marks in memory only.
--
-- Rules (NFR-3):
--   * Everyone, guests too, can read alerts (FR "View alerts").
--   * Only active admins can post, edit or delete them. posted_by must be
--     an admin (checked by the trigger below).
--   * Users read and write only their own alert_reads rows.
--
-- There is no admin screen yet. To post an alert, run this in the SQL
-- Editor with your own values (posted_by = an admin's user_id; the
-- subquery finds it by email):
--
--   insert into public.alerts
--     (title, summary, details, category, severity, area, actions, posted_by)
--   values (
--     'Flooding in Brgy. Dau',
--     'Knee-deep water on low-lying streets near the creek.',
--     'Water is knee-deep near the creek. Residents of the affected streets should prepare to evacuate.',
--     'flood',            -- flood | weather | road | shelter
--     'high',             -- normal | moderate | high
--     'Brgy. Dau',        -- a barangay as "Brgy. Name", or 'Mabalacat City'
--     array['Move valuables to higher places', 'Prepare your go-bag'],
--     (select user_id from public.users where email = 'admin@example.com')
--   );
--
-- (The Table Editor works too: Insert row, pick posted_by from the list,
-- and type actions as {"Step one","Step two"}.)

create table public.alerts (
  alert_id   bigint generated always as identity primary key,
  title      varchar(120) not null check (length(trim(title)) > 0),
  summary    varchar(255) not null check (length(trim(summary)) > 0),
  details    text         not null check (length(trim(details)) > 0),
  category   varchar(20)  not null check (category in ('flood', 'weather', 'road', 'shelter')),
  severity   varchar(10)  not null check (severity in ('normal', 'moderate', 'high')),
  area       varchar(100) not null,
  actions    text[],
  posted_by  uuid         not null references public.users (user_id),
  created_at timestamptz  not null default now()
);

create index alerts_created_at on public.alerts (created_at desc);

-- From the app, posted_by is always the admin who's posting. From the
-- SQL Editor / Table Editor (no logged-in user) it must name an admin.
create function public.alerts_check_poster()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  if (select auth.uid()) is not null then
    new.posted_by := (select auth.uid());
  end if;
  if not exists (
    select 1 from public.users
    where user_id = new.posted_by and role = 'admin'
  ) then
    raise exception 'posted_by must be an admin';
  end if;
  return new;
end;
$$;

create trigger alerts_check_poster
  before insert or update on public.alerts
  for each row execute function public.alerts_check_poster();

create table public.alert_reads (
  user_id  uuid   not null references public.users (user_id) on delete cascade,
  alert_id bigint not null references public.alerts (alert_id) on delete cascade,
  read_at  timestamptz not null default now(),
  primary key (user_id, alert_id)
);

alter table public.alerts enable row level security;
alter table public.alert_reads enable row level security;

create policy "Anyone reads alerts"
  on public.alerts for select to anon, authenticated
  using (true);

create policy "Admins post alerts"
  on public.alerts for insert to authenticated
  with check (public.is_admin());

create policy "Admins edit alerts"
  on public.alerts for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins delete alerts"
  on public.alerts for delete to authenticated
  using (public.is_admin());

create policy "Read own read-marks"
  on public.alert_reads for select to authenticated
  using (user_id = (select auth.uid()));

create policy "Mark alerts read as yourself"
  on public.alert_reads for insert to authenticated
  with check (user_id = (select auth.uid()));

grant select on public.alerts to anon, authenticated;
grant insert, update, delete on public.alerts to authenticated;
grant select, insert on public.alert_reads to authenticated;

-- New / edited / deleted alerts reach open apps at once (FR "Real-time
-- updates"). Read-marks don't need it: only the reader changes them.
alter publication supabase_realtime add table public.alerts;
