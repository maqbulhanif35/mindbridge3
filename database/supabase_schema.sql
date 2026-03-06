-- ─────────────────────────────────────────────────────────
-- MindBridge — Supabase Schema
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor)
-- ─────────────────────────────────────────────────────────

-- ─── 1. Profiles (extends auth.users) ─────────────────────
create table if not exists public.profiles (
  id                   uuid primary key references auth.users(id) on delete cascade,
  email                text not null,
  name                 text not null,
  university           text,
  year_of_study        integer,
  profile_image_url    text,
  onboarding_completed boolean default false,
  goals                text[]  default '{}',
  preferred_name       text,
  created_at           timestamptz default now()
);

alter table public.profiles enable row level security;

create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- ─── 2. Chat sessions ──────────────────────────────────────
create table if not exists public.chat_sessions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  title      text default 'New conversation',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.chat_sessions enable row level security;

create policy "Users own their chat sessions"
  on public.chat_sessions for all
  using (auth.uid() = user_id);

-- ─── 3. Chat messages ──────────────────────────────────────
create table if not exists public.chat_messages (
  id         uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.chat_sessions(id) on delete cascade,
  role       text not null check (role in ('user', 'assistant')),
  content    text not null,
  created_at timestamptz default now()
);

alter table public.chat_messages enable row level security;

create policy "Users can access messages in their sessions"
  on public.chat_messages for all
  using (
    auth.uid() = (
      select user_id from public.chat_sessions
      where id = session_id
    )
  );

-- ─── 4. Mood logs ──────────────────────────────────────────
create table if not exists public.mood_logs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  mood_score  integer not null check (mood_score between 1 and 10),
  emotions    text[]  default '{}',
  activities  text[]  default '{}',
  note        text,
  sleep_hours numeric(4,1),
  created_at  timestamptz default now()
);

alter table public.mood_logs enable row level security;

create policy "Users own their mood logs"
  on public.mood_logs for all
  using (auth.uid() = user_id);

-- ─── 5. Journal entries ─────────────────────────────────────
create table if not exists public.journal_entries (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  title      text,
  content    text not null,
  mood_score integer check (mood_score between 1 and 10),
  tags       text[] default '{}',
  is_private boolean default true,
  ai_insight text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.journal_entries enable row level security;

create policy "Users own their journal entries"
  on public.journal_entries for all
  using (auth.uid() = user_id);

-- ─── Helper: auto-update updated_at ────────────────────────
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_chat_sessions_updated
  before update on public.chat_sessions
  for each row execute function public.set_updated_at();

create trigger trg_journal_updated
  before update on public.journal_entries
  for each row execute function public.set_updated_at();
