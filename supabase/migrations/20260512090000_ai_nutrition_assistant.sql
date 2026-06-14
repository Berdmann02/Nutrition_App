create table if not exists public.user_nutrition_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  goal_type text,
  calorie_target numeric,
  protein_target numeric,
  carb_target numeric,
  fat_target numeric,
  fiber_target numeric,
  sugar_limit numeric,
  dietary_restrictions text[] not null default '{}',
  allergies text[] not null default '{}',
  household_size int not null default 1,
  budget_preference text not null default 'moderate',
  cooking_skill text not null default 'beginner',
  meal_prep_preference text not null default 'balanced',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_food_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  liked_foods text[] not null default '{}',
  disliked_foods text[] not null default '{}',
  neutral_foods text[] not null default '{}',
  favorite_meals text[] not null default '{}',
  avoided_ingredients text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('user', 'assistant', 'system')),
  content text not null,
  context_type text not null default 'general_chat',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.meal_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  goal_type text,
  days int not null default 1,
  meals_per_day int not null default 3,
  household_size int not null default 1,
  total_calories numeric not null default 0,
  total_protein numeric not null default 0,
  total_carbs numeric not null default 0,
  total_fat numeric not null default 0,
  plan jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.meal_plan_days (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  meal_plan_id uuid not null references public.meal_plans(id) on delete cascade,
  day_index int not null,
  title text,
  meals jsonb not null default '[]'::jsonb,
  totals jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.grocery_lists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  meal_plan_id uuid references public.meal_plans(id) on delete set null,
  title text not null,
  items jsonb not null default '[]'::jsonb,
  export_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.grocery_list_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  grocery_list_id uuid not null references public.grocery_lists(id) on delete cascade,
  name text not null,
  quantity numeric,
  unit text,
  category text not null default 'Other',
  linked_meals text[] not null default '{}',
  created_at timestamptz not null default now()
);

drop trigger if exists user_nutrition_profiles_touch_updated_at on public.user_nutrition_profiles;
create trigger user_nutrition_profiles_touch_updated_at
before update on public.user_nutrition_profiles
for each row execute function public.touch_updated_at();

drop trigger if exists user_food_preferences_touch_updated_at on public.user_food_preferences;
create trigger user_food_preferences_touch_updated_at
before update on public.user_food_preferences
for each row execute function public.touch_updated_at();

alter table public.user_nutrition_profiles enable row level security;
alter table public.user_food_preferences enable row level security;
alter table public.ai_chat_messages enable row level security;
alter table public.meal_plans enable row level security;
alter table public.meal_plan_days enable row level security;
alter table public.grocery_lists enable row level security;
alter table public.grocery_list_items enable row level security;

drop policy if exists user_nutrition_profiles_own_all on public.user_nutrition_profiles;
create policy user_nutrition_profiles_own_all on public.user_nutrition_profiles
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists user_food_preferences_own_all on public.user_food_preferences;
create policy user_food_preferences_own_all on public.user_food_preferences
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists ai_chat_messages_own_all on public.ai_chat_messages;
create policy ai_chat_messages_own_all on public.ai_chat_messages
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists meal_plans_own_all on public.meal_plans;
create policy meal_plans_own_all on public.meal_plans
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists meal_plan_days_own_all on public.meal_plan_days;
create policy meal_plan_days_own_all on public.meal_plan_days
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists grocery_lists_own_all on public.grocery_lists;
create policy grocery_lists_own_all on public.grocery_lists
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists grocery_list_items_own_all on public.grocery_list_items;
create policy grocery_list_items_own_all on public.grocery_list_items
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
