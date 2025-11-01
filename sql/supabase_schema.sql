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

-- Add role check constraint if it doesn't already exist (some Postgres versions
-- / Supabase do not support IF NOT EXISTS on ADD CONSTRAINT).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'profiles_role_check'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_role_check CHECK (role IN ('technician','supervisor'));
  END IF;
END
$$;

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
-- Some Postgres/Supabase builds don't support CREATE FUNCTION IF NOT EXISTS.
-- Create the trigger function only if it doesn't already exist.
-- Create or replace trigger function for updated_at
CREATE OR REPLACE FUNCTION public.trigger_set_timestamp()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Create triggers (use DROP IF EXISTS then CREATE to avoid incompatibilities)
DROP TRIGGER IF EXISTS tasks_set_timestamp ON public.tasks;
CREATE TRIGGER tasks_set_timestamp
  BEFORE UPDATE ON public.tasks
  FOR EACH ROW EXECUTE PROCEDURE public.trigger_set_timestamp();

DROP TRIGGER IF EXISTS reports_set_timestamp ON public.reports;
CREATE TRIGGER reports_set_timestamp
  BEFORE UPDATE ON public.reports
  FOR EACH ROW EXECUTE PROCEDURE public.trigger_set_timestamp();

DROP TRIGGER IF EXISTS profiles_set_timestamp ON public.profiles;
CREATE TRIGGER profiles_set_timestamp
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE PROCEDURE public.trigger_set_timestamp();

-- 5) Enable Row Level Security (RLS)
alter table public.profiles enable row level security;
alter table public.tasks enable row level security;
alter table public.reports enable row level security;

-- 6) Policies for profiles: users can manage only their own profile
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'profiles' AND policyname = 'Select own profile'
  ) THEN
    EXECUTE 'CREATE POLICY "Select own profile" ON public.profiles FOR SELECT USING (auth.uid() = id)';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'profiles' AND policyname = 'Insert own profile'
  ) THEN
    EXECUTE 'CREATE POLICY "Insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id)';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'profiles' AND policyname = 'Update own profile'
  ) THEN
    EXECUTE 'CREATE POLICY "Update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id)';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'profiles' AND policyname = 'Delete own profile'
  ) THEN
    EXECUTE 'CREATE POLICY "Delete own profile" ON public.profiles FOR DELETE USING (auth.uid() = id)';
  END IF;
END
$$;

-- 7) Policies for tasks
-- Supervisors can view all tasks using existence check on profiles
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'tasks' AND policyname = 'Select tasks (owner or assigned or supervisor)'
  ) THEN
    EXECUTE 'CREATE POLICY "Select tasks (owner or assigned or supervisor)" ON public.tasks FOR SELECT USING (auth.uid() = created_by OR auth.uid() = assigned_to OR exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''supervisor''))';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'tasks' AND policyname = 'Insert tasks (owner)'
  ) THEN
    EXECUTE 'CREATE POLICY "Insert tasks (owner)" ON public.tasks FOR INSERT WITH CHECK (auth.uid() = created_by)';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'tasks' AND policyname = 'Update tasks (owner or assigned)'
  ) THEN
  EXECUTE 'CREATE POLICY "Update tasks (owner or assigned)" ON public.tasks FOR UPDATE USING (auth.uid() = created_by OR auth.uid() = assigned_to) WITH CHECK (created_by = auth.uid())';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'tasks' AND policyname = 'Delete tasks (creator)'
  ) THEN
    EXECUTE 'CREATE POLICY "Delete tasks (creator)" ON public.tasks FOR DELETE USING (auth.uid() = created_by)';
  END IF;
END
$$;

-- 8) Policies for reports
-- Supervisors can read all reports; authors can access their own
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'reports' AND policyname = 'Select reports (author or supervisor)'
  ) THEN
    EXECUTE 'CREATE POLICY "Select reports (author or supervisor)" ON public.reports FOR SELECT USING (auth.uid() = author OR exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''supervisor''))';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'reports' AND policyname = 'Insert reports (author)'
  ) THEN
    EXECUTE 'CREATE POLICY "Insert reports (author)" ON public.reports FOR INSERT WITH CHECK (auth.uid() = author)';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'reports' AND policyname = 'Update reports (author or supervisor)'
  ) THEN
  -- Keep update restricted to the original author to avoid allowing supervisors to change authorship via client
  EXECUTE 'CREATE POLICY "Update reports (author or supervisor)" ON public.reports FOR UPDATE USING (auth.uid() = author) WITH CHECK (author = auth.uid())';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'reports' AND policyname = 'Delete reports (author or supervisor)'
  ) THEN
    EXECUTE 'CREATE POLICY "Delete reports (author or supervisor)" ON public.reports FOR DELETE USING (auth.uid() = author OR exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''supervisor''))';
  END IF;
END
$$;

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
