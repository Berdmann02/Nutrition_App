alter table public.user_nutrition_profiles
  add column if not exists target_weight_kg numeric;
