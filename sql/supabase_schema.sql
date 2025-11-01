-- Supabase schema for App_Reporting_Teknisi
-- Paste this into Supabase -> SQL editor and Run
-- It creates tables: profiles, tasks, reports; enables RLS and reasonable policies
-- NOTE: Adjust table/column names or policies to your needs before running in production.

-- 0) Ensure crypto extension for gen_random_uuid()
create extension if not exists "pgcrypto";

-- 1) profiles table (link to auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'technician', -- 'technician' or 'supervisor'
  full_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles
  add constraint if not exists profiles_role_check check (role in ('technician','supervisor'));

-- 2) tasks table
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  status text not null default 'open', -- open, in_progress, done, etc
  assigned_to uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3) reports table
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  summary text,
  content text,
  author uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 4) Triggers to update updated_at
create function if not exists public.trigger_set_timestamp()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger if not exists tasks_set_timestamp
  before update on public.tasks
  for each row execute procedure public.trigger_set_timestamp();

create trigger if not exists reports_set_timestamp
  before update on public.reports
  for each row execute procedure public.trigger_set_timestamp();

create trigger if not exists profiles_set_timestamp
  before update on public.profiles
  for each row execute procedure public.trigger_set_timestamp();

-- 5) Enable Row Level Security (RLS)
alter table public.profiles enable row level security;
alter table public.tasks enable row level security;
alter table public.reports enable row level security;

-- 6) Policies for profiles: users can manage only their own profile
create policy if not exists "Select own profile" on public.profiles
  for select
  using (auth.uid() = id);

create policy if not exists "Insert own profile" on public.profiles
  for insert
  with check (auth.uid() = id);

create policy if not exists "Update own profile" on public.profiles
  for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy if not exists "Delete own profile" on public.profiles
  for delete
  using (auth.uid() = id);

-- 7) Policies for tasks
-- Supervisors can view all tasks using existence check on profiles
create policy if not exists "Select tasks (owner or assigned or supervisor)" on public.tasks
  for select
  using (
    auth.uid() = created_by
    OR auth.uid() = assigned_to
    OR exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'supervisor')
  );

-- Insert: only allow creating tasks where created_by == auth.uid()
create policy if not exists "Insert tasks (owner)" on public.tasks
  for insert
  with check (auth.uid() = created_by);

-- Update: allow assigned_to or creator to update the task
create policy if not exists "Update tasks (owner or assigned)" on public.tasks
  for update
  using (
    auth.uid() = created_by
    OR auth.uid() = assigned_to
  )
  with check (
    -- created_by cannot be forged/changed to someone else on update
    created_by = old.created_by
  );

-- Delete: only creator can delete
create policy if not exists "Delete tasks (creator)" on public.tasks
  for delete
  using (auth.uid() = created_by);

-- 8) Policies for reports
-- Supervisors can read all reports; authors can access their own
create policy if not exists "Select reports (author or supervisor)" on public.reports
  for select
  using (
    auth.uid() = author
    OR exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'supervisor')
  );

-- Insert: must be author
create policy if not exists "Insert reports (author)" on public.reports
  for insert
  with check (auth.uid() = author);

-- Update: only author or supervisor can update (supervisor typically via admin UI)
create policy if not exists "Update reports (author or supervisor)" on public.reports
  for update
  using (
    auth.uid() = author
    OR exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'supervisor')
  )
  with check (author = old.author);

-- Delete: only supervisor (admin-like) or original author
create policy if not exists "Delete reports (author or supervisor)" on public.reports
  for delete
  using (
    auth.uid() = author
    OR exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'supervisor')
  );

-- 9) Useful indexes
create index if not exists idx_tasks_assigned_to on public.tasks (assigned_to);
create index if not exists idx_tasks_created_by on public.tasks (created_by);
create index if not exists idx_reports_author on public.reports (author);
create index if not exists idx_profiles_role on public.profiles (role);

-- 10) Example inserts (admin / service_role only)
-- Replace the UUIDs below with actual auth.users ids or run these from a server using the service_role key
-- INSERT INTO public.profiles (id, email, role, full_name) VALUES
--   ('11111111-1111-1111-1111-111111111111','teknisi1@example.com','technician','Teknisi Satu'),
--   ('22222222-2222-2222-2222-222222222222','boss@example.com','supervisor','Boss');

-- 11) Notes
-- - If you use email confirmation and restrict inserts until confirmation, consider creating server-side functions
--   or running profile creation from an Edge function triggered after confirmation.
-- - To allow supervisors to reassign tasks, you'll need a server-side function (using service_role) or an admin UI that uses
--   the service_role key because RLS typically prevents clients from changing assigned_to to someone else.
-- - Review and tighten policies according to your exact security requirements before production deployment.

-- End of schema
