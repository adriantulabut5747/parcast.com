-- ============================================================
-- AgosAlert: the users table (paper, Table 14)
-- ============================================================
-- Paste this whole file into Supabase > SQL Editor > New query > Run.
-- Safe to run once on a fresh project. Later tables get their own
-- numbered file (02_..., 03_...), added when their feature is built.
--
-- How accounts work:
--   * Supabase Auth (auth.users) keeps the email + hashed password.
--     We never store passwords (NFR-2).
--   * public.users is OUR row per account: name, barangay, role...
--     A trigger makes it automatically when someone signs up, from the
--     name + barangay the app sends as sign-up "metadata".
--   * Row Level Security (NFR-3): you can read and edit only your own
--     row; admins can read every row. Nobody can make themselves an
--     admin or un-suspend themselves from the app: role and
--     account_status can only be changed in the Supabase dashboard
--     (Table Editor) for now.
--
-- The Laravel build must sign people in through Supabase Auth too (its
-- REST API), NOT with Laravel's own users/password table, or the two
-- builds end up with two separate login systems.

create table public.users (
  user_id        uuid primary key references auth.users (id) on delete cascade,
  full_name      varchar(100) not null check (length(trim(full_name)) > 0),
  email          varchar(255) not null unique,
  phone_number   varchar(15),
  barangay       varchar(50)  not null check (barangay in (
    'Atlu-Bola', 'Bical', 'Bundagul', 'Cacutud', 'Calumpang', 'Camachiles',
    'Dapdap', 'Dau', 'Dolores', 'Duquit', 'Lakandula', 'Mabiga',
    'Macapagal Village', 'Mamatitang', 'Mangalit', 'Marcos Village',
    'Mawaque', 'Paralayunan', 'Poblacion', 'San Francisco', 'San Joaquin',
    'Santa Ines', 'Santa Maria', 'Santo Rosario', 'Sapang Balen',
    'Sapang Biabas', 'Tabun')),
  role           varchar(20)  not null default 'registered'
                   check (role in ('registered', 'admin')),
  account_status varchar(20)  not null default 'active'
                   check (account_status in ('active', 'suspended')),
  created_at     timestamptz  not null default now()
);

-- Sign-up -> profile row. Runs as the table owner (security definer),
-- because the new user isn't allowed to insert rows themselves.
-- role / account_status are NOT read from the metadata: they take their
-- defaults, so nobody can sign up as an admin.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.users (user_id, full_name, email, barangay)
  values (
    new.id,
    trim(new.raw_user_meta_data ->> 'full_name'),
    new.email,
    new.raw_user_meta_data ->> 'barangay'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- True when the person asking is an active admin. security definer so
-- it can look at the users table without tripping its own RLS rules.
create function public.is_admin()
returns boolean
language sql
stable
security definer set search_path = ''
as $$
  select exists (
    select 1 from public.users
    where user_id = (select auth.uid())
      and role = 'admin'
      and account_status = 'active'
  );
$$;

alter table public.users enable row level security;

create policy "Read own row; admins read all"
  on public.users for select to authenticated
  using (user_id = (select auth.uid()) or public.is_admin());

create policy "Edit own row while active"
  on public.users for update to authenticated
  using (user_id = (select auth.uid()) and account_status = 'active')
  with check (user_id = (select auth.uid()));

-- Column rights: logged-in users may change only these three columns
-- (FR-R2). Rows are only added by the trigger and removed with the
-- auth account. Guests (anon) get nothing.
revoke all on public.users from anon, authenticated;
grant select on public.users to authenticated;
grant update (full_name, phone_number, barangay) on public.users to authenticated;
-- The RLS rule above calls is_admin(), so logged-in users must be allowed
-- to run it (needed when "Automatically expose new tables" is off).
grant execute on function public.is_admin() to authenticated;
