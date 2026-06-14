type AssistantAction =
  | "general_chat"
  | "daily_analysis"
  | "food_swap"
  | "meal_plan"
  | "regenerate_meal"
  | "grocery_list"
  | "restaurant_recommendations";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.1-flash-lite";
const apiKey = Deno.env.get("GEMINI_API_KEY");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  if (!apiKey) return json({ error: "GEMINI_API_KEY is not configured" }, 500);

  try {
    const body = await req.json();
    const action = normalizeAction(body.action);
    const prompt = buildPrompt(action, body);
    const responseMimeType = action === "general_chat" ? "text/plain" : "application/json";
    let text: string;
    let usedSearch = false;
    let searchFallbackReason = "";
    if (action === "restaurant_recommendations") {
      try {
        text = await callGemini(prompt, responseMimeType, { useSearch: true });
        usedSearch = true;
      } catch (error) {
        searchFallbackReason = error instanceof Error ? error.message : String(error);
        text = await callGemini(
          buildPrompt(action, body, {
            searchUnavailableReason: searchFallbackReason,
          }),
          responseMimeType,
        );
      }
    } else {
      text = await callGemini(prompt, responseMimeType);
    }
    const payload = action === "general_chat"
      ? { message: text.trim() }
      : extractJson(text);
    return json({ action, used_search: usedSearch, search_fallback_reason: searchFallbackReason, ...payload });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message }, 500);
  }
});

async function callGemini(
  prompt: string,
  responseMimeType: "text/plain" | "application/json",
  options: { useSearch?: boolean } = {},
) {
  const body: Record<string, unknown> = {
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: {
      temperature: responseMimeType === "text/plain" ? 0.45 : 0.25,
      responseMimeType,
    },
  };
  if (options.useSearch) {
    body.tools = [{ googleSearch: {} }];
  }
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    },
  );

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`Gemini request failed: ${response.status} ${detail}`);
  }

  const payload = await response.json();
  const text = payload?.candidates?.[0]?.content?.parts
    ?.map((part: { text?: string }) => part.text ?? "")
    .join("");
  if (!text) throw new Error("Gemini returned no text");
  return text;
}

function buildPrompt(
  action: AssistantAction,
  body: Record<string, unknown>,
  options: { searchUnavailableReason?: string } = {},
) {
  const context = JSON.stringify(body.context ?? {}, null, 2);
  const message = String(body.message ?? "").trim();
  const safety = `
Safety rules:
- Do not diagnose or treat medical conditions.
- Do not give extreme dieting, starvation, purging, or eating-disorder advice.
- For pregnancy, diabetes, kidney disease, allergies, eating disorders, clinical nutrition, or medication-related diet questions, recommend a qualified clinician or registered dietitian.
- Keep advice practical, balanced, and food-based.
`;

  const base = `
You are Coach Chat, an AI nutrition and workout assistant inside a food logging and coaching app.
Use the provided user context, goals, logged meals, activity/workout context when available, preferences, allergies, restrictions, budget, cooking skill, and household size.
${safety}
User context JSON:
${context}
`;

  if (action === "general_chat") {
    return `${base}
User question: ${message}

Only answer questions related to nutrition, food logging, meals, macros, calories, hydration, groceries, meal planning, body goals, workouts, exercise, recovery, sleep, or activity. Short follow-up replies are allowed when they clearly answer your previous nutrition/workout question, such as energy level, soreness, hunger, fullness, cravings, recovery, workout preference, or meal preference.
If the user asks about coding, entertainment, general trivia, politics, unrelated work, or anything outside nutrition/workouts/activity, politely say you can only help with nutrition, workout, and activity-related questions in this app, then suggest a related question they can ask.
Answer conversationally and briefly. Include a light clinical disclaimer only when the user asks about medical conditions, pregnancy, eating disorders, allergies, diabetes, kidney disease, or other clinical situations.`;
  }

  if (action === "daily_analysis") {
    return `${base}
Analysis request: ${message || "Analyze the logged intake."}

Analyze the provided logged intake against goals for calories, protein, carbs, fat, fiber, sugar, sodium, and available micronutrients.
If the analysis request refers to a past day, write in past tense and explain what could have been done better for that day. Do not call a past day "today".
Return JSON only:
{
  "summary": "string",
  "score": 0,
  "highlights": ["string"],
  "gaps": ["string"],
  "suggestions": [
    {"title": "string", "reason": "string", "example": "string"}
  ],
  "disclaimer": "string"
}`;
  }

  if (action === "food_swap") {
    return `${base}
Selected logged food JSON:
${JSON.stringify(body.food ?? {}, null, 2)}

Return JSON only with practical alternatives:
{
  "food": "string",
  "swaps": [
    {
      "type": "Healthier swap|Higher-protein swap|Lower-calorie swap|Higher-fiber swap|Similar-taste option",
      "suggestion": "string",
      "why": "string",
      "estimated_difference": {
        "calories": "string",
        "protein": "string",
        "carbs": "string",
        "fat": "string",
        "fiber": "string"
      }
    }
  ]
}`;
  }

  if (action === "restaurant_recommendations") {
    return `${base}
Restaurant recommendation request JSON:
${JSON.stringify(body.request ?? {}, null, 2)}

${options.searchUnavailableReason
  ? `Live menu search is currently unavailable for this request. Reason: ${options.searchUnavailableReason}
Use broadly known restaurant menu knowledge only when you are reasonably confident, clearly mark nutrition as estimated, and tell the user to confirm the current restaurant menu/nutrition page before ordering. If the restaurant is niche or unknown, ask the user to paste menu items instead of inventing exact menu options.`
  : "Use Google Search grounding to find the current public menu and available nutrition information for the requested restaurant when possible. Prefer official restaurant nutrition/menu pages. If current nutrition values are unavailable, clearly mark estimates and explain the uncertainty."}

Recommend exactly 3 restaurant or fast-food orders the user should consider. Balance what best fits their nutrition goals with any favorite/craving they mention. Include practical customizations such as sauce on side, grilled instead of fried, half portion, swap sides, add protein, remove high-sugar drink, or add fiber. Do not claim exact current availability unless supported by the searched menu.

If request.message is present, treat it as a follow-up discussion about the previous recommendations and answer it while still returning the full structured JSON.

Return JSON only:
{
  "restaurant": "string",
  "menu_source_note": "string",
  "summary": "string",
  "recommendations": [
    {
      "rank": 1,
      "name": "string",
      "order_details": "string",
      "why_it_fits": "string",
      "what_you_want_vs_need": "string",
      "customizations": ["string"],
      "estimated_nutrition": {
        "calories": 0,
        "protein": 0,
        "carbs": 0,
        "fat": 0,
        "fiber": 0,
        "sugar": 0,
        "sodium": 0
      },
      "confidence": "high|medium|low"
    }
  ],
  "discussion_reply": "string",
  "follow_up_questions": ["string"],
  "disclaimer": "string"
}`;
  }

  if (action === "meal_plan") {
    return `${base}
Meal plan request JSON:
${JSON.stringify(body.request ?? {}, null, 2)}

Generate ingredient quantities scaled for household_size and number of days.
The response must include exactly request.days day objects in days_plan, numbered sequentially from 1 through request.days.
If request.days is 7, days_plan must contain Day 1, Day 2, Day 3, Day 4, Day 5, Day 6, and Day 7. Never return only Day 1 for a multi-day request.
Each day object should include meals matching request.meals_per_day as closely as possible, using snacks only when request.include_snacks allows them.
Every day in days_plan must contain a non-empty meals array. Never leave Day 2, Day 3, or later days empty.
Every meal must include instructions as 3 to 6 clear recipe-style preparation steps. Include cooking temperatures, timing, assembly, or no-cook assembly steps when useful. Never leave instructions blank.
Use the request's budget_preference, variety_mode, repeat_preference, meal_prep_preference, and variety_instruction to decide how much repetition and variety to include.
These are user preferences, not hard universal rules.
If the user chooses grocery efficiency or repeat-heavy planning, it is acceptable to repeat meals and ingredients more often to save money and simplify shopping.
If the user chooses more variety or mostly unique meals, create more distinct recipes and flavors even if the grocery list is longer.
When repeat_preference is "Mostly unique", do not repeat the same meal name across the plan unless the user's notes explicitly request leftovers or repeats. Use different meal names, ingredient combinations, sauces, or preparations for each day.
When variety_mode is "More variety", prioritize different meals across the selected days over grocery simplicity.
If unique_retry is true, the previous plan failed because it repeated too many meal names or left days blank. Treat avoid_repeated_meal_names as names to avoid, and return a complete new plan with all requested days populated with genuinely different meal names and recipes.
When repeat_preference is "Repeat often", repeating meals is allowed and should be intentional for cost and prep savings.
For 7-day plans, avoid accidental copy-paste repetition; repeat meals intentionally only when it matches the user's selected spending, prep, and repeat preferences.
Good example for grocery efficient: similar ingredients reused across bowls, wraps, salads, and reheated meal prep portions.
Good example for more variety: distinct meals with some overlapping ingredients to avoid waste.
Return JSON only:
{
  "title": "string",
  "goal_type": "string",
  "days": 0,
  "meals_per_day": 0,
  "household_size": 0,
  "daily_totals": [{"day": 1, "calories": 0, "protein": 0, "carbs": 0, "fat": 0}],
  "days_plan": [
    {
      "day": 1,
      "meals": [
        {
          "name": "string",
          "meal_type": "breakfast|lunch|dinner|snack",
          "description": "string",
          "serving_size": "string",
          "ingredients": [{"name": "string", "quantity": 0, "unit": "string", "category": "string"}],
          "instructions": ["string"],
          "calories": 0,
          "protein": 0,
          "carbs": 0,
          "fat": 0,
          "fiber": 0,
          "sugar": 0,
          "sodium": 0,
          "potassium": 0,
          "why_this_fits": "string",
          "prep": "string"
        }
      ]
    }
  ],
  "prep_notes": ["string"]
}`;
  }

  if (action === "regenerate_meal") {
    return `${base}
Current meal plan JSON:
${JSON.stringify(body.meal_plan ?? {}, null, 2)}

Original meal JSON:
${JSON.stringify(body.food ?? {}, null, 2)}

Requested change JSON:
${JSON.stringify(body.request ?? {}, null, 2)}

Replace only the selected meal. Keep the replacement aligned with the user's nutrition targets and the other meals that day. Avoid allergens and disliked foods. Return JSON only:
{
  "name": "string",
  "meal_type": "breakfast|lunch|dinner|snack",
  "description": "string",
  "serving_size": "string",
  "ingredients": [{"name": "string", "quantity": 0, "unit": "string", "category": "string"}],
  "instructions": ["string"],
  "calories": 0,
  "protein": 0,
  "carbs": 0,
  "fat": 0,
  "fiber": 0,
  "sugar": 0,
  "sodium": 0,
  "potassium": 0,
  "prep": "string",
  "why_this_fits": "string"
}`;
  }

  return `${base}
Meal plan JSON:
${JSON.stringify(body.meal_plan ?? {}, null, 2)}

Create a combined grocery list. Merge duplicate ingredients and group by category.
Return JSON only:
{
  "title": "string",
  "items": [
    {"name": "string", "quantity": 0, "unit": "string", "category": "Produce|Meat/seafood|Dairy|Grains|Pantry|Frozen|Snacks|Other", "linked_meals": ["string"]}
  ],
  "export_text": "string",
  "export_json": {}
}`;
}

function normalizeAction(value: unknown): AssistantAction {
  const action = String(value ?? "general_chat");
  if (
    action === "daily_analysis" ||
    action === "food_swap" ||
    action === "meal_plan" ||
    action === "regenerate_meal" ||
    action === "grocery_list" ||
    action === "restaurant_recommendations"
  ) return action;
  return "general_chat";
}

function extractJson(text: string): Record<string, unknown> {
  const cleaned = text
    .trim()
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/\s*```$/i, "");
  try {
    return JSON.parse(cleaned);
  } catch {
    const start = cleaned.indexOf("{");
    const end = cleaned.lastIndexOf("}");
    if (start >= 0 && end > start) return JSON.parse(cleaned.slice(start, end + 1));
    throw new Error("Gemini returned invalid JSON");
  }
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
