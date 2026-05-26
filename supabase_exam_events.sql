create table if not exists public.exam_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject_name text not null check (length(trim(subject_name)) > 0),
  exam_type text not null default 'Examen' check (length(trim(exam_type)) > 0),
  starts_at timestamptz not null,
  room text not null default '',
  notes text not null default '',
  reminder_minutes_before integer not null default 1440 check (reminder_minutes_before >= 0),
  notifications_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.exam_events enable row level security;

create policy "Users can read their exam events"
  on public.exam_events
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can insert their exam events"
  on public.exam_events
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update their exam events"
  on public.exam_events
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete their exam events"
  on public.exam_events
  for delete
  to authenticated
  using (auth.uid() = user_id);

create index if not exists exam_events_user_starts_at_idx
  on public.exam_events (user_id, starts_at);

create or replace function public.set_exam_events_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_exam_events_updated_at on public.exam_events;

create trigger set_exam_events_updated_at
  before update on public.exam_events
  for each row
  execute function public.set_exam_events_updated_at();
