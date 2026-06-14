type MealType = "breakfast" | "lunch" | "dinner" | "snack";
type Source = "photo" | "text" | "restaurant" | "barcode";

type FoodItem = {
  name: string;
  normalized_query: string;
  portion_label: string;
  amount: number;
  unit: string;
  serving_grams: number;
  provider: string;
  provider_food_id: string;
  confidence: number;
  confidence_level: "high" | "medium" | "low";
  alternatives: string[];
  clarifying_question: string | null;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  fiber: number;
  sugar: number;
  vitamin_a: number;
  vitamin_b_complex: number;
  vitamin_c: number;
  vitamin_d: number;
  vitamin_e: number;
  vitamin_k: number;
  iron: number;
  calcium: number;
  magnesium: number;
  sodium: number;
  potassium: number;
  zinc: number;
  raw_provider_payload?: Record<string, unknown>;
};

type ParseFoodResponse = {
  meal_name: string;
  meal_type: MealType;
  confidence: number;
  needs_review: boolean;
  needs_clarification: boolean;
  clarifying_question: string | null;
  estimated_totals: Record<string, number>;
  items: FoodItem[];
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.1-flash-lite";
const apiKey = Deno.env.get("GEMINI_API_KEY");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const body = await req.json();
    const source = normalizeSource(body.source);
    const description = String(body.description ?? body.caption ?? "").trim();
    const barcode = String(body.barcode ?? body.code ?? "").trim();
    const imageBase64 = typeof body.image_base64 === "string"
      ? body.image_base64
      : typeof body.imageBase64 === "string"
      ? body.imageBase64
      : null;
    const imageMimeType = String(
      body.image_mime_type ?? body.imageMimeType ?? "image/jpeg",
    );

    if (source === "barcode") {
      const lookupValue = barcode || description;
      if (!lookupValue) return json({ error: "barcode is required" }, 400);
      return json(await lookupBarcodeFood(lookupValue));
    }

    if (!apiKey) {
      return json({ error: "GEMINI_API_KEY is not configured" }, 500);
    }

    if (!description && !imageBase64) {
      return json({ error: "description or image_base64 is required" }, 400);
    }

    const prompt = buildPrompt(source, description);
    const gemini = await callGemini({ prompt, imageBase64, imageMimeType });
    const parsed = normalizeResponse(extractJson(gemini), source, description);

    return json(parsed);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message }, 500);
  }
});

async function lookupBarcodeFood(rawCode: string): Promise<ParseFoodResponse> {
  const candidates = barcodeCandidates(rawCode);
  if (candidates.length === 0) {
    throw new Error("No valid barcode number was found in the scan.");
  }

  for (const code of candidates) {
    const product = await fetchOpenFoodFactsProduct(code);
    if (product) return responseFromOpenFoodFactsProduct(product, code);
  }

  throw new Error(
    `No exact packaged food match was found for barcode ${candidates[0]}. Try scanning again or add the item manually.`,
  );
}

async function fetchOpenFoodFactsProduct(
  barcode: string,
): Promise<Record<string, unknown> | null> {
  const fields = [
    "code",
    "product_name",
    "product_name_en",
    "generic_name",
    "brands",
    "quantity",
    "serving_size",
    "serving_quantity",
    "nutriments",
    "image_front_url",
  ].join(",");
  const response = await fetch(
    `https://world.openfoodfacts.org/api/v2/product/${barcode}.json?fields=${fields}`,
    {
      headers: {
        "Accept": "application/json",
        "User-Agent": "NutritionApp/1.0 (packaged food lookup)",
      },
    },
  );
  if (!response.ok) return null;
  const payload = await response.json();
  if (payload?.status !== 1 || !payload?.product) return null;
  return payload.product as Record<string, unknown>;
}

function responseFromOpenFoodFactsProduct(
  product: Record<string, unknown>,
  barcode: string,
): ParseFoodResponse {
  const nutriments = typeof product.nutriments === "object" &&
      product.nutriments !== null
    ? product.nutriments as Record<string, unknown>
    : {};
  const name = stringValue(product.product_name) ||
    stringValue(product.product_name_en) ||
    stringValue(product.generic_name) ||
    `Packaged food ${barcode}`;
  const brand = stringValue(product.brands);
  const servingQuantity = clampNumber(product.serving_quantity, 0);
  const servingSize = stringValue(product.serving_size);
  const amount = servingSize ? amountFromPortion(servingSize) : 1;
  const unit = servingSize ? unitFromPortion(servingSize) : "serving";
  const servingGrams = servingQuantity > 0
    ? servingQuantity
    : unit.toLowerCase().includes("g")
    ? amount
    : 100;
  const item: FoodItem = {
    name: brand ? `${brand} ${name}` : name,
    normalized_query: name.toLowerCase(),
    portion_label: servingSize || "1 serving",
    amount: servingSize ? amount : 1,
    unit: servingSize ? unit : "serving",
    serving_grams: servingGrams,
    provider: "open_food_facts",
    provider_food_id: barcode,
    confidence: 0.98,
    confidence_level: "high",
    alternatives: [],
    clarifying_question: null,
    calories: nutrientValue(nutriments, "energy-kcal"),
    protein: nutrientValue(nutriments, "proteins"),
    carbs: nutrientValue(nutriments, "carbohydrates"),
    fat: nutrientValue(nutriments, "fat"),
    fiber: nutrientValue(nutriments, "fiber"),
    sugar: nutrientValue(nutriments, "sugars"),
    vitamin_a: nutrientValue(nutriments, "vitamin-a"),
    vitamin_b_complex: 0,
    vitamin_c: nutrientValue(nutriments, "vitamin-c"),
    vitamin_d: nutrientValue(nutriments, "vitamin-d"),
    vitamin_e: nutrientValue(nutriments, "vitamin-e"),
    vitamin_k: nutrientValue(nutriments, "vitamin-k"),
    iron: nutrientValue(nutriments, "iron", { gramsToMilligrams: true }),
    calcium: nutrientValue(nutriments, "calcium", { gramsToMilligrams: true }),
    magnesium: nutrientValue(nutriments, "magnesium", {
      gramsToMilligrams: true,
    }),
    sodium: nutrientValue(nutriments, "sodium", { gramsToMilligrams: true }),
    potassium: nutrientValue(nutriments, "potassium", {
      gramsToMilligrams: true,
    }),
    zinc: nutrientValue(nutriments, "zinc", { gramsToMilligrams: true }),
    raw_provider_payload: {
      barcode,
      product_name: name,
      brand,
      quantity: product.quantity,
      serving_size: servingSize,
      image_front_url: product.image_front_url,
      source: "open_food_facts",
      was_ai_estimated: false,
    },
  };

  return {
    meal_name: item.name,
    meal_type: "snack",
    confidence: 0.98,
    needs_review: true,
    needs_clarification: false,
    clarifying_question: null,
    estimated_totals: totalsForItems([item]),
    items: [item],
  };
}

function nutrientValue(
  nutriments: Record<string, unknown>,
  key: string,
  options: { gramsToMilligrams?: boolean } = {},
) {
  const servingValue = numericValue(nutriments[`${key}_serving`]);
  const per100gValue = numericValue(nutriments[`${key}_100g`]);
  const value = servingValue ?? per100gValue ?? 0;
  const multiplier = options.gramsToMilligrams ? 1000 : 1;
  return Math.round(value * multiplier * 10) / 10;
}

function numericValue(value: unknown): number | null {
  const number = typeof value === "number" ? value : Number(value);
  return Number.isFinite(number) ? number : null;
}

function barcodeCandidates(rawValue: string) {
  const digitGroups = rawValue.match(/\d{8,14}/g) ?? [];
  const cleaned = rawValue.replace(/\D/g, "");
  if (cleaned.length >= 8 && cleaned.length <= 14) digitGroups.unshift(cleaned);
  const candidates = new Set<string>();
  for (const group of digitGroups) {
    candidates.add(group);
    if (group.length === 12) candidates.add(`0${group}`);
    if (group.length === 13 && group.startsWith("0")) {
      candidates.add(group.slice(1));
    }
  }
  return [...candidates];
}

async function callGemini({
  prompt,
  imageBase64,
  imageMimeType,
}: {
  prompt: string;
  imageBase64: string | null;
  imageMimeType: string;
}) {
  const parts: unknown[] = [{ text: prompt }];
  if (imageBase64) {
    parts.push({
      inline_data: {
        mime_type: imageMimeType,
        data: stripDataUrlPrefix(imageBase64),
      },
    });
  }

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ role: "user", parts }],
        generationConfig: {
          temperature: 0.15,
          responseMimeType: "application/json",
        },
      }),
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

function buildPrompt(source: Source, description: string) {
  const modeInstruction = source === "photo"
    ? "Analyze the provided food image. Use the optional description only as context."
    : source === "restaurant"
    ? "Parse this restaurant or fast-food meal. Prefer branded/menu-style nutrition estimates."
    : "Parse this free-text food log.";

  return `
You are the AI food parser for a nutrition tracking app.
${modeInstruction}

Return JSON only. Do not use markdown.
If multiple foods are present, return multiple items.
Parse natural quantities like "2 eggs", "1 cup rice", "6 oz chicken", "1 tbsp mayo", and mixed foods into ingredient-level items.
For vague mixed foods such as sandwich, salad, bowl, burrito, wrap, smoothie, omelet, soup, pasta, or pizza, infer likely ingredients when enough detail exists, otherwise mark low confidence and include clarifying questions/alternatives.
Estimate portions in grams when not provided.
Use realistic nutrition estimates for each item.
Vitamins and minerals may be percent daily value except sodium and potassium, which must be milligrams.
Use confidence_level as high, medium, or low. Include alternatives for uncertain ingredients.

Input description: ${description || "(none)"}

JSON schema:
{
  "meal_name": "string",
  "meal_type": "breakfast|lunch|dinner|snack",
  "confidence": 0.0,
  "needs_review": true,
  "needs_clarification": false,
  "clarifying_question": null,
  "estimated_totals": {
    "calories": 0,
    "protein": 0,
    "carbs": 0,
    "fat": 0,
    "fiber": 0,
    "sugar": 0,
    "sodium": 0
  },
  "items": [
    {
      "name": "string",
      "normalized_query": "string",
      "portion_label": "string",
      "amount": 0,
      "unit": "grams|ounces|cups|tbsp|tsp|pieces|slices|large|medium|small|serving|container|package",
      "serving_grams": 0,
      "provider": "gemini",
      "provider_food_id": "string",
      "confidence": 0.0,
      "confidence_level": "high|medium|low",
      "alternatives": ["string"],
      "clarifying_question": null,
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
  ]
}`;
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
    if (start >= 0 && end > start) {
      return JSON.parse(cleaned.slice(start, end + 1));
    }
    throw new Error("Gemini returned invalid JSON");
  }
}

function normalizeResponse(
  payload: Record<string, unknown>,
  source: Source,
  description: string,
): ParseFoodResponse {
  const rawItems = Array.isArray(payload.items) ? payload.items : [];
  const items = rawItems
    .map((item) => normalizeItem(item))
    .filter((item): item is FoodItem => item !== null);

  if (items.length === 0) {
    items.push(fallbackItem(description || source));
  }

  const confidence = clampNumber(payload.confidence, 0.7);
  const totals = totalsForItems(items);
  return {
    meal_name: stringValue(payload.meal_name) || stringValue(payload.mealName) ||
      titleFromItems(items),
    meal_type: normalizeMealType(payload.meal_type, source, description),
    confidence,
    needs_review: true,
    needs_clarification: Boolean(payload.needs_clarification) ||
      confidence < 0.65,
    clarifying_question: typeof payload.clarifying_question === "string"
      ? payload.clarifying_question
      : confidence < 0.65
      ? "Can you add a portion size or more detail?"
      : null,
    estimated_totals: totals,
    items,
  };
}

function normalizeItem(value: unknown): FoodItem | null {
  if (!value || typeof value !== "object") return null;
  const item = value as Record<string, unknown>;
  const name = stringValue(item.name) || stringValue(item.normalized_query);
  if (!name) return null;
  const normalizedQuery = stringValue(item.normalized_query) || name;
  const amount = clampNumber(item.amount, amountFromPortion(item.portion_label));
  const unit = stringValue(item.unit) || unitFromPortion(item.portion_label);
  const confidence = clampNumber(item.confidence, 0.75);
  return {
    name,
    normalized_query: normalizedQuery,
    portion_label: stringValue(item.portion_label) || `${amount} ${unit}`,
    amount,
    unit,
    serving_grams: clampNumber(item.serving_grams, 100),
    provider: stringValue(item.provider) || "gemini",
    provider_food_id: stringValue(item.provider_food_id) ||
      slugify(normalizedQuery),
    confidence,
    confidence_level: confidenceLevel(item.confidence_level, confidence),
    alternatives: Array.isArray(item.alternatives)
      ? item.alternatives.map((value) => String(value).trim()).filter(Boolean)
      : [],
    clarifying_question: typeof item.clarifying_question === "string"
      ? item.clarifying_question
      : typeof item.clarifyingQuestion === "string"
      ? item.clarifyingQuestion
      : null,
    calories: clampNumber(item.calories, 0),
    protein: clampNumber(item.protein, 0),
    carbs: clampNumber(item.carbs, 0),
    fat: clampNumber(item.fat, 0),
    fiber: clampNumber(item.fiber, 0),
    sugar: clampNumber(item.sugar, 0),
    vitamin_a: clampNumber(item.vitamin_a, 0),
    vitamin_b_complex: clampNumber(item.vitamin_b_complex, 0),
    vitamin_c: clampNumber(item.vitamin_c, 0),
    vitamin_d: clampNumber(item.vitamin_d, 0),
    vitamin_e: clampNumber(item.vitamin_e, 0),
    vitamin_k: clampNumber(item.vitamin_k, 0),
    iron: clampNumber(item.iron, 0),
    calcium: clampNumber(item.calcium, 0),
    magnesium: clampNumber(item.magnesium, 0),
    sodium: clampNumber(item.sodium, 0),
    potassium: clampNumber(item.potassium, 0),
    zinc: clampNumber(item.zinc, 0),
    raw_provider_payload: { model },
  };
}

function fallbackItem(description: string): FoodItem {
  const name = description.trim() || "Unknown Food";
  return {
    name,
    normalized_query: name.toLowerCase(),
    portion_label: "1 serving",
    amount: 1,
    unit: "serving",
    serving_grams: 100,
    provider: "fallback",
    provider_food_id: slugify(name),
    confidence: 0.45,
    confidence_level: "low",
    alternatives: [],
    clarifying_question: "Can you add a portion size or more detail?",
    calories: 0,
    protein: 0,
    carbs: 0,
    fat: 0,
    fiber: 0,
    sugar: 0,
    vitamin_a: 0,
    vitamin_b_complex: 0,
    vitamin_c: 0,
    vitamin_d: 0,
    vitamin_e: 0,
    vitamin_k: 0,
    iron: 0,
    calcium: 0,
    magnesium: 0,
    sodium: 0,
    potassium: 0,
    zinc: 0,
    raw_provider_payload: { model, fallback: true },
  };
}

function normalizeSource(value: unknown): Source {
  if (
    value === "photo" || value === "restaurant" || value === "text" ||
    value === "barcode"
  ) {
    return value;
  }
  return "text";
}

function normalizeMealType(
  value: unknown,
  source: Source,
  description: string,
): MealType {
  if (
    value === "breakfast" || value === "lunch" || value === "dinner" ||
    value === "snack"
  ) {
    return value;
  }
  const text = description.toLowerCase();
  if (text.includes("breakfast") || text.includes("yogurt")) return "breakfast";
  if (text.includes("dinner") || text.includes("steak")) return "dinner";
  if (text.includes("snack") || text.includes("banana")) return "snack";
  return source === "restaurant" ? "lunch" : "lunch";
}

function stripDataUrlPrefix(value: string) {
  return value.replace(/^data:[^;]+;base64,/, "");
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function clampNumber(value: unknown, fallback: number) {
  const number = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.max(0, Math.round(number * 10) / 10);
}

function confidenceLevel(
  value: unknown,
  confidence: number,
): "high" | "medium" | "low" {
  if (value === "high" || value === "medium" || value === "low") return value;
  if (confidence >= 0.8) return "high";
  if (confidence >= 0.6) return "medium";
  return "low";
}

function amountFromPortion(value: unknown) {
  const text = stringValue(value);
  const match = text.match(/^\d+(\.\d+)?/);
  return match ? Number(match[0]) : 1;
}

function unitFromPortion(value: unknown) {
  const text = stringValue(value);
  const unit = text.replace(/^\d+(\.\d+)?\s*/, "").trim();
  return unit || "serving";
}

function totalsForItems(items: FoodItem[]) {
  const keys = [
    "calories",
    "protein",
    "carbs",
    "fat",
    "fiber",
    "sugar",
    "sodium",
    "potassium",
  ] as const;
  const totals: Record<string, number> = {};
  for (const key of keys) {
    totals[key] = Math.round(
      items.reduce((sum, item) => sum + Number(item[key] ?? 0), 0) * 10,
    ) / 10;
  }
  return totals;
}

function titleFromItems(items: FoodItem[]) {
  if (items.length === 0) return "Reviewed Meal";
  if (items.length === 1) return items[0].name;
  return items.slice(0, 3).map((item) => item.name).join(", ");
}

function slugify(value: string) {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}
