create or replace function public.get_history(day_count int default 30)
returns jsonb
language sql
stable
security invoker
as $$
  with dates as (
    select generate_series(current_date - (greatest(1, least(day_count, 365)) - 1), current_date, interval '1 day')::date as log_date
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
    'days', greatest(1, least(day_count, 365)),
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
