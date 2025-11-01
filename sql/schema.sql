-- Supabase schema untuk App_Reporting_Teknisi
-- Paste ke Supabase -> SQL editor dan Run

-- 0) Pastikan ekstensi crypto tersedia untuk gen_random_uuid()
create extension if not exists "pgcrypto";

-- 1) Tabel profiles (terhubung ke auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'technician', -- 'technician' atau 'supervisor'
  full_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Tambahkan constraint untuk role
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

-- 2) Tabel tasks (tugas/pekerjaan)
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

-- 3) Tabel reports (laporan pekerjaan)
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  task_id uuid references public.tasks(id) on delete set null,
  title text not null,
  summary text,
  content text,
  images text[], -- Array dari URL gambar
  author uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 4) Trigger untuk update updated_at
CREATE OR REPLACE FUNCTION public.trigger_set_timestamp()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Buat triggers (gunakan DROP IF EXISTS lalu CREATE)
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

-- 5) Aktifkan Row Level Security (RLS)
alter table public.profiles enable row level security;
alter table public.tasks enable row level security;
alter table public.reports enable row level security;

-- 6) Policies untuk profiles
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
END
$$;

-- 7) Policies untuk tasks
DO $$
BEGIN
  -- Supervisor bisa lihat semua tugas; teknisi hanya lihat tugas mereka
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'tasks' AND policyname = 'Select tasks policy'
  ) THEN
    EXECUTE 'CREATE POLICY "Select tasks policy" ON public.tasks FOR SELECT USING (
      exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''supervisor'')
      OR auth.uid() = created_by 
      OR auth.uid() = assigned_to
    )';
  END IF;

  -- Hanya supervisor yang bisa buat tugas baru
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'tasks' AND policyname = 'Insert tasks policy'
  ) THEN
    EXECUTE 'CREATE POLICY "Insert tasks policy" ON public.tasks FOR INSERT WITH CHECK (
      exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''supervisor'')
      AND auth.uid() = created_by
    )';
  END IF;

  -- Update: supervisor bisa update semua, teknisi hanya bisa update status tugas mereka
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'tasks' AND policyname = 'Update tasks policy'
  ) THEN
    EXECUTE 'CREATE POLICY "Update tasks policy" ON public.tasks FOR UPDATE USING (
      exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''supervisor'')
      OR auth.uid() = assigned_to
    )';
  END IF;

  -- Hanya supervisor yang bisa hapus tugas
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'tasks' AND policyname = 'Delete tasks policy'
  ) THEN
    EXECUTE 'CREATE POLICY "Delete tasks policy" ON public.tasks FOR DELETE USING (
      exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''supervisor'')
    )';
  END IF;
END
$$;

-- 8) Policies untuk reports
DO $$
BEGIN
  -- Supervisor bisa lihat semua laporan, teknisi hanya lihat laporan mereka
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'reports' AND policyname = 'Select reports policy'
  ) THEN
    EXECUTE 'CREATE POLICY "Select reports policy" ON public.reports FOR SELECT USING (
      exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''supervisor'')
      OR auth.uid() = author
    )';
  END IF;

  -- Teknisi bisa buat laporan untuk tugas mereka
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'reports' AND policyname = 'Insert reports policy'
  ) THEN
    EXECUTE 'CREATE POLICY "Insert reports policy" ON public.reports FOR INSERT WITH CHECK (
      auth.uid() = author 
      AND EXISTS (
        SELECT 1 FROM public.tasks t 
        WHERE t.id = task_id 
        AND (t.assigned_to = auth.uid() OR exists (
          select 1 from public.profiles p 
          where p.id = auth.uid() and p.role = ''supervisor''
        ))
      )
    )';
  END IF;

  -- Update: teknisi bisa edit laporan mereka, supervisor bisa edit semua
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'reports' AND policyname = 'Update reports policy'
  ) THEN
    EXECUTE 'CREATE POLICY "Update reports policy" ON public.reports FOR UPDATE USING (
      exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''supervisor'')
      OR auth.uid() = author
    )';
  END IF;

  -- Delete: hanya supervisor yang bisa hapus laporan
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'reports' AND policyname = 'Delete reports policy'
  ) THEN
    EXECUTE 'CREATE POLICY "Delete reports policy" ON public.reports FOR DELETE USING (
      exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = ''supervisor'')
    )';
  END IF;
END
$$;

-- 9) Index untuk performa
create index if not exists idx_tasks_assigned_to on public.tasks (assigned_to);
create index if not exists idx_tasks_created_by on public.tasks (created_by);
create index if not exists idx_tasks_status on public.tasks (status);
create index if not exists idx_reports_author on public.reports (author);
create index if not exists idx_reports_task_id on public.reports (task_id);
create index if not exists idx_profiles_role on public.profiles (role);

-- 10) Catatan penggunaan:
-- - Jalankan script ini di Supabase SQL Editor
-- - Gunakan service_role key untuk operasi admin seperti mengassign tugas
-- - Teknisi bisa:
--   * Lihat profil mereka sendiri
--   * Lihat tugas yang di-assign ke mereka
--   * Update status tugas mereka
--   * Buat dan edit laporan untuk tugas mereka
-- - Supervisor bisa:
--   * Lihat semua profil
--   * CRUD semua tugas
--   * CRUD semua laporan
--   * Assign tugas ke teknisi

-- 11) Queries berguna:
/*
-- Lihat tugas aktif teknisi
SELECT t.*, p.full_name as assigned_to_name
FROM tasks t
JOIN profiles p ON p.id = t.assigned_to
WHERE t.status != 'done'
ORDER BY t.created_at DESC;

-- Lihat laporan per tugas
SELECT r.*, p.full_name as author_name
FROM reports r
JOIN profiles p ON p.id = r.author
WHERE r.task_id = '<task-id>'
ORDER BY r.created_at DESC;

-- Statistik tugas per teknisi
SELECT 
  p.full_name,
  COUNT(t.id) as total_tasks,
  COUNT(t.id) FILTER (WHERE t.status = 'done') as completed_tasks
FROM profiles p
LEFT JOIN tasks t ON t.assigned_to = p.id
WHERE p.role = 'technician'
GROUP BY p.id, p.full_name;
*/