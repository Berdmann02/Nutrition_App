alter table public.goals
add column if not exists plan_name text,
add column if not exists setup_completed boolean not null default false;
