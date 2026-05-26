-- Academic schema v2 for the Student Command Center refactor.
-- This adds normalized tables beside the existing schema. Do not drop legacy
-- tables until the Flutter repository has been migrated and verified.

create extension if not exists pgcrypto;

create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  semester_label text not null default 'Semestrul 1',
  credits integer not null default 5 check (credits > 0 and credits <= 60),
  professor text not null default '',
  color_hex text not null default '#35B86F',
  archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, name, semester_label)
);

create table if not exists public.class_sessions (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null references public.subjects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  session_type text not null check (
    session_type in ('Curs', 'Seminar', 'Laborator')
  ),
  weekday integer not null check (weekday between 1 and 7),
  starts_at_time time not null,
  ends_at_time time not null,
  room text not null default '',
  professor text not null default '',
  recurrence text not null default 'weekly' check (recurrence in ('weekly')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at_time > starts_at_time)
);

create table if not exists public.academic_events (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid references public.subjects(id) on delete set null,
  user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null check (
    event_type in (
      'exam',
      'colloquium',
      'retake',
      'project',
      'homework',
      'lab',
      'deadline',
      'study'
    )
  ),
  title text not null check (length(trim(title)) > 0),
  starts_at timestamptz,
  due_at timestamptz,
  room text not null default '',
  notes text not null default '',
  priority text not null default 'medium' check (
    priority in ('low', 'medium', 'high')
  ),
  status text not null default 'planned' check (
    status in ('planned', 'in_progress', 'done', 'cancelled')
  ),
  reminder_minutes_before integer not null default 1440 check (
    reminder_minutes_before >= 0
  ),
  notifications_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (starts_at is not null or due_at is not null)
);

create table if not exists public.grade_components (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null references public.subjects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  component_type text not null default 'other' check (
    component_type in (
      'exam',
      'seminar',
      'laboratory',
      'project',
      'coursework',
      'other'
    )
  ),
  weight_percent numeric(5, 2) not null default 0 check (
    weight_percent >= 0 and weight_percent <= 100
  ),
  minimum_grade numeric(4, 2) not null default 5 check (
    minimum_grade >= 1 and minimum_grade <= 10
  ),
  grade numeric(4, 2) check (grade >= 1 and grade <= 10),
  is_required boolean not null default true,
  is_eliminatory boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (subject_id, name)
);

create table if not exists public.study_tasks (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid references public.subjects(id) on delete set null,
  academic_event_id uuid references public.academic_events(id) on delete set null,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  due_at timestamptz,
  estimated_minutes integer check (
    estimated_minutes is null or estimated_minutes > 0
  ),
  priority text not null default 'medium' check (
    priority in ('low', 'medium', 'high')
  ),
  status text not null default 'todo' check (
    status in ('todo', 'in_progress', 'done', 'cancelled')
  ),
  reminder_minutes_before integer check (
    reminder_minutes_before is null or reminder_minutes_before >= 0
  ),
  notifications_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.subjects enable row level security;
alter table public.class_sessions enable row level security;
alter table public.academic_events enable row level security;
alter table public.grade_components enable row level security;
alter table public.study_tasks enable row level security;

drop policy if exists "Users can read their subjects" on public.subjects;
create policy "Users can read their subjects"
  on public.subjects
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their subjects" on public.subjects;
create policy "Users can insert their subjects"
  on public.subjects
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their subjects" on public.subjects;
create policy "Users can update their subjects"
  on public.subjects
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their subjects" on public.subjects;
create policy "Users can delete their subjects"
  on public.subjects
  for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can read their class sessions" on public.class_sessions;
create policy "Users can read their class sessions"
  on public.class_sessions
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their class sessions" on public.class_sessions;
create policy "Users can insert their class sessions"
  on public.class_sessions
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1
      from public.subjects
      where subjects.id = class_sessions.subject_id
        and subjects.user_id = auth.uid()
    )
  );

drop policy if exists "Users can update their class sessions" on public.class_sessions;
create policy "Users can update their class sessions"
  on public.class_sessions
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and exists (
      select 1
      from public.subjects
      where subjects.id = class_sessions.subject_id
        and subjects.user_id = auth.uid()
    )
  );

drop policy if exists "Users can delete their class sessions" on public.class_sessions;
create policy "Users can delete their class sessions"
  on public.class_sessions
  for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can read their academic events" on public.academic_events;
create policy "Users can read their academic events"
  on public.academic_events
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their academic events" on public.academic_events;
create policy "Users can insert their academic events"
  on public.academic_events
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and (
      subject_id is null
      or exists (
        select 1
        from public.subjects
        where subjects.id = academic_events.subject_id
          and subjects.user_id = auth.uid()
      )
    )
  );

drop policy if exists "Users can update their academic events" on public.academic_events;
create policy "Users can update their academic events"
  on public.academic_events
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and (
      subject_id is null
      or exists (
        select 1
        from public.subjects
        where subjects.id = academic_events.subject_id
          and subjects.user_id = auth.uid()
      )
    )
  );

drop policy if exists "Users can delete their academic events" on public.academic_events;
create policy "Users can delete their academic events"
  on public.academic_events
  for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can read their grade components" on public.grade_components;
create policy "Users can read their grade components"
  on public.grade_components
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their grade components" on public.grade_components;
create policy "Users can insert their grade components"
  on public.grade_components
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1
      from public.subjects
      where subjects.id = grade_components.subject_id
        and subjects.user_id = auth.uid()
    )
  );

drop policy if exists "Users can update their grade components" on public.grade_components;
create policy "Users can update their grade components"
  on public.grade_components
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and exists (
      select 1
      from public.subjects
      where subjects.id = grade_components.subject_id
        and subjects.user_id = auth.uid()
    )
  );

drop policy if exists "Users can delete their grade components" on public.grade_components;
create policy "Users can delete their grade components"
  on public.grade_components
  for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can read their study tasks" on public.study_tasks;
create policy "Users can read their study tasks"
  on public.study_tasks
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their study tasks" on public.study_tasks;
create policy "Users can insert their study tasks"
  on public.study_tasks
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and (
      subject_id is null
      or exists (
        select 1
        from public.subjects
        where subjects.id = study_tasks.subject_id
          and subjects.user_id = auth.uid()
      )
    )
    and (
      academic_event_id is null
      or exists (
        select 1
        from public.academic_events
        where academic_events.id = study_tasks.academic_event_id
          and academic_events.user_id = auth.uid()
      )
    )
  );

drop policy if exists "Users can update their study tasks" on public.study_tasks;
create policy "Users can update their study tasks"
  on public.study_tasks
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and (
      subject_id is null
      or exists (
        select 1
        from public.subjects
        where subjects.id = study_tasks.subject_id
          and subjects.user_id = auth.uid()
      )
    )
    and (
      academic_event_id is null
      or exists (
        select 1
        from public.academic_events
        where academic_events.id = study_tasks.academic_event_id
          and academic_events.user_id = auth.uid()
      )
    )
  );

drop policy if exists "Users can delete their study tasks" on public.study_tasks;
create policy "Users can delete their study tasks"
  on public.study_tasks
  for delete
  to authenticated
  using (auth.uid() = user_id);

create index if not exists subjects_user_semester_idx
  on public.subjects (user_id, semester_label, archived);

create index if not exists class_sessions_user_weekday_time_idx
  on public.class_sessions (user_id, weekday, starts_at_time);

create index if not exists class_sessions_subject_idx
  on public.class_sessions (subject_id);

create index if not exists academic_events_user_due_idx
  on public.academic_events (user_id, (coalesce(due_at, starts_at)));

create index if not exists academic_events_subject_idx
  on public.academic_events (subject_id);

create index if not exists grade_components_subject_idx
  on public.grade_components (subject_id);

create index if not exists study_tasks_user_due_status_idx
  on public.study_tasks (user_id, status, due_at);

create index if not exists study_tasks_subject_idx
  on public.study_tasks (subject_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_subjects_updated_at on public.subjects;
create trigger set_subjects_updated_at
  before update on public.subjects
  for each row
  execute function public.set_updated_at();

drop trigger if exists set_class_sessions_updated_at on public.class_sessions;
create trigger set_class_sessions_updated_at
  before update on public.class_sessions
  for each row
  execute function public.set_updated_at();

drop trigger if exists set_academic_events_updated_at on public.academic_events;
create trigger set_academic_events_updated_at
  before update on public.academic_events
  for each row
  execute function public.set_updated_at();

drop trigger if exists set_grade_components_updated_at on public.grade_components;
create trigger set_grade_components_updated_at
  before update on public.grade_components
  for each row
  execute function public.set_updated_at();

drop trigger if exists set_study_tasks_updated_at on public.study_tasks;
create trigger set_study_tasks_updated_at
  before update on public.study_tasks
  for each row
  execute function public.set_updated_at();
