# Architecture

```text
Flutter iOS App
  |
  | Supabase Flutter SDK
  v
Supabase Auth  ---- auth.users
  |
  v
Postgres public schema
  |-- users
  |-- goals
  |-- daily_logs
  |-- meals
  |-- meal_items
  |-- nutrition_totals
  |-- get_dashboard(date)
  |-- get_history(day_count)
  |
  v
RLS policies enforce user-owned data access

Supabase Storage
  |
  |-- meal-photos/{user_id}/{timestamp}.jpg

Future AI pipeline
  |
  |-- Supabase Edge Function: parse-food
        |-- Gemini gemini-3.1-flash-lite vision/text parser
        |-- Future USDA/Edamam/Spoonacular provider adapter
        |-- normalized meal_items insert
```

## Backend Responsibilities

Supabase owns authentication, storage, relational data, row-level security, dashboard/history aggregation, and AI parsing through Edge Functions. The Flutter app calls `parse-food`, then stores the normalized meal and nutrition rows returned by the function.

## Data Flow

1. User signs in with Supabase Auth.
2. User logs food by text, restaurant entry, or photo.
3. App calls Supabase Edge Function `parse-food`.
4. Edge Function calls Gemini `gemini-3.1-flash-lite`.
5. App creates or reuses `daily_logs` for today.
6. App inserts `meals`.
7. App inserts one or more `meal_items` with complete nutrition fields.
8. Postgres trigger recalculates `nutrition_totals`.
9. Dashboard calls `get_dashboard(current_date)`.
10. History calls `get_history(7)` or `get_history(30)`.

## AI Prompts

### Food Image Parsing

```text
You are a nutrition logging assistant using Gemini. Analyze this food image and return JSON only.
Detect every visible food item, estimate portion size in grams, and provide confidence.

Schema:
{
  "meal_type": "breakfast|lunch|dinner|snack",
  "items": [
    {
      "name": "string",
      "normalized_query": "string for nutrition API lookup",
      "portion_label": "string",
      "serving_grams": number,
      "confidence": number
    }
  ],
  "needs_clarification": boolean,
  "clarifying_question": "string|null"
}
```

### Text Food Parsing

```text
You are a nutrition logging assistant using Gemini. Parse the user's food description and return JSON only.
Normalize each food into a lookup query and estimate a reasonable portion if the user did not give one.
Ask for clarification only when confidence is below 0.65.

User text:
{{description}}
```

## Provider Adapter Contract

Each nutrition provider should return the same normalized shape:

```json
{
  "provider": "usda|edamam|spoonacular",
  "provider_food_id": "string",
  "name": "string",
  "serving_grams": 100,
  "nutrition": {
    "calories": 0,
    "protein": 0,
    "carbs": 0,
    "fat": 0,
    "fiber": 0,
    "sugar": 0,
    "vitamin_a": 0,
    "vitamin_b_complex": 0,
    "vitamin_c": 0,
    "vitamin_d": 0,
    "vitamin_e": 0,
    "vitamin_k": 0,
    "iron": 0,
    "calcium": 0,
    "magnesium": 0,
    "sodium": 0,
    "potassium": 0,
    "zinc": 0
  }
}
```
