update public.goals
set setup_completed = true
where setup_completed = false
  and created_at < '2026-05-10 19:30:00+00'::timestamptz;
