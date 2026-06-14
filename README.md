# Nutrition App MVP

AI-assisted nutrition tracking app built with Flutter and Supabase.

## Current Stack

- Mobile app: Flutter
- Backend: Supabase Auth, Postgres, Storage, RLS, RPC functions
- Food parsing: Supabase Edge Function using Gemini `gemini-3.1-flash-lite`
- Hosted Supabase project: `gopvtuhcwrwbgssbyksf`

## Run The App

```bash
/Users/benjaminerdmann/Documents/Codex/2026-05-09/create-an-empty-flutter-project-and/.tooling/flutter/bin/flutter run -d 3FE477B6-0DDA-418B-8988-F69759F6878C
```

## Supabase

The repo is linked to the hosted Supabase project.

```bash
supabase projects list
supabase db push
```

The main schema is in:

```text
supabase/migrations/20260510023040_initial_nutrition_schema.sql
```

## Implemented Flows

- Sign up / login with Supabase Auth
- Dashboard reads totals from Supabase RPC
- Text food logging calls Gemini, then inserts meals and meal items
- Restaurant food logging calls Gemini, then inserts meals and meal items
- Photo logging uploads to private Supabase Storage, calls Gemini Vision, then inserts nutrition data
- Daily totals recalculate in Postgres triggers
- History screen reads 7-day averages/trends
- Goals screen updates daily targets

## Notes

The current AI path uses Gemini for food parsing and nutrition estimates. The next production step is adding a dedicated nutrition provider adapter such as USDA FoodData Central, Edamam, or Spoonacular after Gemini normalizes the food query.
