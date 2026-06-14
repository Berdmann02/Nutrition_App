alter table public.user_nutrition_profiles
  add column if not exists height_cm numeric,
  add column if not exists weight_kg numeric,
  add column if not exists age int,
  add column if not exists gender text,
  add column if not exists activity_level text;
