# Database

The production schema is managed through Supabase migrations.

## Required Tables

- `users`: one profile row per Supabase auth user
- `daily_logs`: one log per user per date
- `meals`: breakfast/lunch/dinner/snack entries
- `meal_items`: individual foods with full nutrition breakdown
- `nutrition_totals`: daily totals recalculated by trigger
- `goals`: daily user targets

## Nutrition Fields

Every `meal_items` row stores:

- `calories`
- `protein`
- `carbs`
- `fat`
- `fiber`
- `sugar`
- `vitamin_a`
- `vitamin_b_complex`
- `vitamin_c`
- `vitamin_d`
- `vitamin_e`
- `vitamin_k`
- `iron`
- `calcium`
- `magnesium`
- `sodium`
- `potassium`
- `zinc`

## Security

All user data tables have row-level security enabled. Policies require `auth.uid() = user_id`, except `users`, where `auth.uid() = id`.

The `meal-photos` storage bucket is private. Users can only access object paths whose first folder is their auth user id.

