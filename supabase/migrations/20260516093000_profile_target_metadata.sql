alter table public.user_nutrition_profiles
  add column if not exists sodium_target numeric,
  add column if not exists potassium_target numeric,
  add column if not exists bmr numeric,
  add column if not exists tdee numeric,
  add column if not exists calorie_adjustment_percent numeric,
  add column if not exists calculation_method text not null default 'mifflin_st_jeor';

create table if not exists public.user_weight_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  weight_kg numeric not null,
  logged_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.user_weight_entries enable row level security;

drop policy if exists user_weight_entries_own_all on public.user_weight_entries;
create policy user_weight_entries_own_all on public.user_weight_entries
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index if not exists user_weight_entries_user_logged_at_idx
  on public.user_weight_entries(user_id, logged_at desc);
