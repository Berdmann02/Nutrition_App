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
  coalesce(
    jsonb_agg(to_jsonb(mi) order by mi.created_at) filter (where mi.id is not null),
    '[]'::jsonb
  ) as items,
  coalesce(sum(mi.fiber), 0) as fiber,
  coalesce(sum(mi.sugar), 0) as sugar,
  coalesce(sum(mi.vitamin_a), 0) as vitamin_a,
  coalesce(sum(mi.vitamin_b_complex), 0) as vitamin_b_complex,
  coalesce(sum(mi.vitamin_c), 0) as vitamin_c,
  coalesce(sum(mi.vitamin_d), 0) as vitamin_d,
  coalesce(sum(mi.vitamin_e), 0) as vitamin_e,
  coalesce(sum(mi.vitamin_k), 0) as vitamin_k,
  coalesce(sum(mi.iron), 0) as iron,
  coalesce(sum(mi.calcium), 0) as calcium,
  coalesce(sum(mi.magnesium), 0) as magnesium,
  coalesce(sum(mi.sodium), 0) as sodium,
  coalesce(sum(mi.potassium), 0) as potassium,
  coalesce(sum(mi.zinc), 0) as zinc
from public.meals m
join public.daily_logs dl on dl.id = m.daily_log_id
left join public.meal_items mi on mi.meal_id = m.id
group by m.id, dl.log_date;
