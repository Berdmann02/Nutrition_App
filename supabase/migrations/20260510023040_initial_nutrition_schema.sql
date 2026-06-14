create extension if not exists pgcrypto;

do $$ begin
  create type public.meal_type as enum ('breakfast', 'lunch', 'dinner', 'snack');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create type public.meal_source as enum ('photo', 'text', 'restaurant', 'manual');
exception
  when duplicate_object then null;
end $$;

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.daily_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  log_date date not null default current_date,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, log_date)
);

create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  calories numeric not null default 2200,
  protein numeric not null default 150,
  carbs numeric not null default 250,
  fat numeric not null default 70,
  fiber numeric not null default 30,
  sugar numeric not null default 50,
  vitamin_a numeric not null default 100,
  vitamin_b_complex numeric not null default 100,
  vitamin_c numeric not null default 100,
  vitamin_d numeric not null default 100,
  vitamin_e numeric not null default 100,
  vitamin_k numeric not null default 100,
  iron numeric not null default 100,
  calcium numeric not null default 100,
  magnesium numeric not null default 100,
  sodium numeric not null default 2300,
  potassium numeric not null default 3400,
  zinc numeric not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id)
);

create table if not exists public.meals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  daily_log_id uuid not null references public.daily_logs(id) on delete cascade,
  meal_type public.meal_type not null,
  source public.meal_source not null,
  title text not null,
  raw_input text,
  image_path text,
  confidence numeric not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.meal_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  meal_id uuid not null references public.meals(id) on delete cascade,
  name text not null,
  normalized_query text not null,
  brand text,
  restaurant_name text,
  portion_label text,
  serving_grams numeric,
  provider text not null default 'mock',
  provider_food_id text,
  confidence numeric not null default 0,
  calories numeric not null default 0,
  protein numeric not null default 0,
  carbs numeric not null default 0,
  fat numeric not null default 0,
  fiber numeric not null default 0,
  sugar numeric not null default 0,
  vitamin_a numeric not null default 0,
  vitamin_b_complex numeric not null default 0,
  vitamin_c numeric not null default 0,
  vitamin_d numeric not null default 0,
  vitamin_e numeric not null default 0,
  vitamin_k numeric not null default 0,
  iron numeric not null default 0,
  calcium numeric not null default 0,
  magnesium numeric not null default 0,
  sodium numeric not null default 0,
  potassium numeric not null default 0,
  zinc numeric not null default 0,
  raw_provider_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.nutrition_totals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  daily_log_id uuid not null references public.daily_logs(id) on delete cascade,
  log_date date not null,
  calories numeric not null default 0,
  protein numeric not null default 0,
  carbs numeric not null default 0,
  fat numeric not null default 0,
  fiber numeric not null default 0,
  sugar numeric not null default 0,
  vitamin_a numeric not null default 0,
  vitamin_b_complex numeric not null default 0,
  vitamin_c numeric not null default 0,
  vitamin_d numeric not null default 0,
  vitamin_e numeric not null default 0,
  vitamin_k numeric not null default 0,
  iron numeric not null default 0,
  calcium numeric not null default 0,
  magnesium numeric not null default 0,
  sodium numeric not null default 0,
  potassium numeric not null default 0,
  zinc numeric not null default 0,
  updated_at timestamptz not null default now(),
  unique (daily_log_id),
  unique (user_id, log_date)
);

create index if not exists daily_logs_user_date_idx on public.daily_logs(user_id, log_date desc);
create index if not exists meals_user_date_idx on public.meals(user_id, created_at desc);
create index if not exists meals_daily_log_idx on public.meals(daily_log_id);
create index if not exists meal_items_meal_idx on public.meal_items(meal_id);
create index if not exists nutrition_totals_user_date_idx on public.nutrition_totals(user_id, log_date desc);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists users_touch_updated_at on public.users;
create trigger users_touch_updated_at
before update on public.users
for each row execute function public.touch_updated_at();

drop trigger if exists daily_logs_touch_updated_at on public.daily_logs;
create trigger daily_logs_touch_updated_at
before update on public.daily_logs
for each row execute function public.touch_updated_at();

drop trigger if exists goals_touch_updated_at on public.goals;
create trigger goals_touch_updated_at
before update on public.goals
for each row execute function public.touch_updated_at();

drop trigger if exists meals_touch_updated_at on public.meals;
create trigger meals_touch_updated_at
before update on public.meals
for each row execute function public.touch_updated_at();

drop trigger if exists meal_items_touch_updated_at on public.meal_items;
create trigger meal_items_touch_updated_at
before update on public.meal_items
for each row execute function public.touch_updated_at();

create or replace function public.create_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email, display_name)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data->>'display_name', split_part(coalesce(new.email, ''), '@', 1))
  )
  on conflict (id) do nothing;

  insert into public.goals (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.create_user_profile();

create or replace function public.recalculate_daily_totals(target_daily_log_id uuid)
returns public.nutrition_totals
language plpgsql
security definer
set search_path = public
as $$
declare
  log_record public.daily_logs;
  total_record public.nutrition_totals;
begin
  select * into log_record
  from public.daily_logs
  where id = target_daily_log_id;

  if log_record.id is null then
    raise exception 'daily log not found';
  end if;

  insert into public.nutrition_totals (
    user_id,
    daily_log_id,
    log_date,
    calories,
    protein,
    carbs,
    fat,
    fiber,
    sugar,
    vitamin_a,
    vitamin_b_complex,
    vitamin_c,
    vitamin_d,
    vitamin_e,
    vitamin_k,
    iron,
    calcium,
    magnesium,
    sodium,
    potassium,
    zinc
  )
  select
    log_record.user_id,
    log_record.id,
    log_record.log_date,
    coalesce(sum(mi.calories), 0),
    coalesce(sum(mi.protein), 0),
    coalesce(sum(mi.carbs), 0),
    coalesce(sum(mi.fat), 0),
    coalesce(sum(mi.fiber), 0),
    coalesce(sum(mi.sugar), 0),
    coalesce(sum(mi.vitamin_a), 0),
    coalesce(sum(mi.vitamin_b_complex), 0),
    coalesce(sum(mi.vitamin_c), 0),
    coalesce(sum(mi.vitamin_d), 0),
    coalesce(sum(mi.vitamin_e), 0),
    coalesce(sum(mi.vitamin_k), 0),
    coalesce(sum(mi.iron), 0),
    coalesce(sum(mi.calcium), 0),
    coalesce(sum(mi.magnesium), 0),
    coalesce(sum(mi.sodium), 0),
    coalesce(sum(mi.potassium), 0),
    coalesce(sum(mi.zinc), 0)
  from public.meals m
  left join public.meal_items mi on mi.meal_id = m.id
  where m.daily_log_id = log_record.id
  on conflict (daily_log_id) do update set
    calories = excluded.calories,
    protein = excluded.protein,
    carbs = excluded.carbs,
    fat = excluded.fat,
    fiber = excluded.fiber,
    sugar = excluded.sugar,
    vitamin_a = excluded.vitamin_a,
    vitamin_b_complex = excluded.vitamin_b_complex,
    vitamin_c = excluded.vitamin_c,
    vitamin_d = excluded.vitamin_d,
    vitamin_e = excluded.vitamin_e,
    vitamin_k = excluded.vitamin_k,
    iron = excluded.iron,
    calcium = excluded.calcium,
    magnesium = excluded.magnesium,
    sodium = excluded.sodium,
    potassium = excluded.potassium,
    zinc = excluded.zinc,
    updated_at = now()
  returning * into total_record;

  return total_record;
end;
$$;

create or replace function public.recalculate_totals_after_item_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_log_id uuid;
begin
  if tg_op = 'DELETE' then
    select daily_log_id into target_log_id from public.meals where id = old.meal_id;
  else
    select daily_log_id into target_log_id from public.meals where id = new.meal_id;
  end if;

  if target_log_id is not null then
    perform public.recalculate_daily_totals(target_log_id);
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists meal_items_recalculate_totals on public.meal_items;
create trigger meal_items_recalculate_totals
after insert or update or delete on public.meal_items
for each row execute function public.recalculate_totals_after_item_change();

create or replace view public.meal_summaries
with (security_invoker = true)
as
select
  m.id,
  m.user_id,
  m.daily_log_id,
  dl.log_date,
  m.meal_type,
  m.source,
  m.title,
  m.raw_input,
  m.image_path,
  m.confidence,
  m.created_at,
  coalesce(sum(mi.calories), 0) as calories,
  coalesce(sum(mi.protein), 0) as protein,
  coalesce(sum(mi.carbs), 0) as carbs,
  coalesce(sum(mi.fat), 0) as fat,
  coalesce(jsonb_agg(to_jsonb(mi) order by mi.created_at) filter (where mi.id is not null), '[]'::jsonb) as items
from public.meals m
join public.daily_logs dl on dl.id = m.daily_log_id
left join public.meal_items mi on mi.meal_id = m.id
group by m.id, dl.log_date;

create or replace function public.get_dashboard(target_date date default current_date)
returns jsonb
language sql
stable
security invoker
as $$
  with log_row as (
    select *
    from public.daily_logs
    where user_id = auth.uid()
      and log_date = target_date
    limit 1
  ),
  totals_row as (
    select nt.*
    from public.nutrition_totals nt
    join log_row dl on dl.id = nt.daily_log_id
  ),
  goals_row as (
    select *
    from public.goals
    where user_id = auth.uid()
    limit 1
  ),
  meals_row as (
    select coalesce(jsonb_agg(to_jsonb(ms) order by ms.created_at), '[]'::jsonb) as meals
    from public.meal_summaries ms
    where ms.user_id = auth.uid()
      and ms.log_date = target_date
  )
  select jsonb_build_object(
    'date', target_date,
    'totals', coalesce(to_jsonb((select t from totals_row t)), jsonb_build_object(
      'calories', 0, 'protein', 0, 'carbs', 0, 'fat', 0, 'fiber', 0, 'sugar', 0,
      'vitamin_a', 0, 'vitamin_b_complex', 0, 'vitamin_c', 0, 'vitamin_d', 0,
      'vitamin_e', 0, 'vitamin_k', 0, 'iron', 0, 'calcium', 0, 'magnesium', 0,
      'sodium', 0, 'potassium', 0, 'zinc', 0
    )),
    'goals', coalesce(to_jsonb((select g from goals_row g)), '{}'::jsonb),
    'meals', (select meals from meals_row)
  );
$$;

create or replace function public.get_history(day_count int default 7)
returns jsonb
language sql
stable
security invoker
as $$
  with dates as (
    select generate_series(current_date - (greatest(1, least(day_count, 30)) - 1), current_date, interval '1 day')::date as log_date
  ),
  series as (
    select
      d.log_date,
      coalesce(nt.calories, 0) as calories,
      coalesce(nt.protein, 0) as protein,
      coalesce(nt.carbs, 0) as carbs,
      coalesce(nt.fat, 0) as fat,
      coalesce(nt.fiber, 0) as fiber,
      coalesce(nt.sugar, 0) as sugar
    from dates d
    left join public.daily_logs dl on dl.user_id = auth.uid() and dl.log_date = d.log_date
    left join public.nutrition_totals nt on nt.daily_log_id = dl.id
  )
  select jsonb_build_object(
    'days', greatest(1, least(day_count, 30)),
    'averages', jsonb_build_object(
      'calories', round(avg(calories), 1),
      'protein', round(avg(protein), 1),
      'carbs', round(avg(carbs), 1),
      'fat', round(avg(fat), 1),
      'fiber', round(avg(fiber), 1),
      'sugar', round(avg(sugar), 1)
    ),
    'series', coalesce(jsonb_agg(to_jsonb(series) order by log_date), '[]'::jsonb)
  )
  from series;
$$;

alter table public.users enable row level security;
alter table public.daily_logs enable row level security;
alter table public.goals enable row level security;
alter table public.meals enable row level security;
alter table public.meal_items enable row level security;
alter table public.nutrition_totals enable row level security;

drop policy if exists users_own_select on public.users;
create policy users_own_select on public.users
for select using (auth.uid() = id);

drop policy if exists users_own_update on public.users;
create policy users_own_update on public.users
for update using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists daily_logs_own_all on public.daily_logs;
create policy daily_logs_own_all on public.daily_logs
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists goals_own_all on public.goals;
create policy goals_own_all on public.goals
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists meals_own_all on public.meals;
create policy meals_own_all on public.meals
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists meal_items_own_all on public.meal_items;
create policy meal_items_own_all on public.meal_items
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists nutrition_totals_own_select on public.nutrition_totals;
create policy nutrition_totals_own_select on public.nutrition_totals
for select using (auth.uid() = user_id);

drop policy if exists nutrition_totals_own_insert on public.nutrition_totals;
create policy nutrition_totals_own_insert on public.nutrition_totals
for insert with check (auth.uid() = user_id);

drop policy if exists nutrition_totals_own_update on public.nutrition_totals;
create policy nutrition_totals_own_update on public.nutrition_totals
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('meal-photos', 'meal-photos', false, 10485760, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists meal_photos_own_select on storage.objects;
create policy meal_photos_own_select on storage.objects
for select using (
  bucket_id = 'meal-photos'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists meal_photos_own_insert on storage.objects;
create policy meal_photos_own_insert on storage.objects
for insert with check (
  bucket_id = 'meal-photos'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists meal_photos_own_delete on storage.objects;
create policy meal_photos_own_delete on storage.objects
for delete using (
  bucket_id = 'meal-photos'
  and auth.uid()::text = (storage.foldername(name))[1]
);
