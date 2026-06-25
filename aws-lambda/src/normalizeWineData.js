"use strict";

const STRING_FIELDS = [
  "producer",
  "country",
  "region",
  "subregion",
  "appellation",
  "classification",
  "vintage",
  "vibeTag",
  "vineyard",
  "soilType",
  "climate",
  "drinkingWindow",
  "abv",
  "winemakingStyle"
];

const CATEGORY_VALUES = new Set([
  "red",
  "white",
  "rose",
  "orange",
  "red sparkling",
  "white sparkling",
  "red dessert",
  "white dessert",
  "red fortified",
  "white fortified",
  "unknown"
]);

function cleanString(value) {
  if (value == null) return null;
  if (typeof value === "number" || typeof value === "boolean") return String(value);
  if (typeof value !== "string") return null;

  const trimmed = value.trim();
  return trimmed === "" ? null : trimmed;
}

function cleanStringArray(value) {
  if (!Array.isArray(value)) {
    if (typeof value === "string" && value.trim() !== "") {
      const separator = value.includes(";") ? ";" : ",";
      return value
        .split(separator)
        .map((item) => cleanString(item))
        .filter((item) => item != null);
    }
    return [];
  }

  return value
    .map((item) => cleanString(item))
    .filter((item) => item != null);
}

function normalizeTastingNotes(value) {
  if (Array.isArray(value)) {
    return value
      .map((item) => cleanString(item))
      .filter((item) => item != null)
      .join(", ");
  }

  return cleanString(value) || "";
}

function normalizeCategory(value) {
  const cleaned = cleanString(value);
  if (!cleaned) return "unknown";

  const normalized = cleaned
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .replace(/\s+wine$/, "")
    .trim();

  const aliases = {
    "red wine": "red",
    "white wine": "white",
    "orange wine": "orange",
    "sparkling red": "red sparkling",
    "sparkling white": "white sparkling",
    "sparkling wine": "white sparkling",
    "sparkling": "white sparkling",
    "dessert red": "red dessert",
    "dessert white": "white dessert",
    "dessert wine": "white dessert",
    "fortified red": "red fortified",
    "fortified white": "white fortified",
    "fortified wine": "red fortified",
    "rose wine": "rose",
    "rose": "rose",
    "rosé": "rose"
  };

  const category = aliases[normalized] || normalized;
  return CATEGORY_VALUES.has(category) ? category : "unknown";
}

function normalizeWineData(input) {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new Error("Model output must be a JSON object.");
  }

  const output = {};

  for (const field of STRING_FIELDS) {
    output[field] = cleanString(input[field]);
  }

  output.grapes = cleanStringArray(input.grapes);
  output.tastingNotes = normalizeTastingNotes(input.tastingNotes);
  output.pairings = cleanStringArray(input.pairings);
  output.category = normalizeCategory(input.category);

  return {
    producer: output.producer,
    country: output.country,
    region: output.region,
    subregion: output.subregion,
    appellation: output.appellation,
    classification: output.classification,
    grapes: output.grapes,
    vintage: output.vintage,
    tastingNotes: output.tastingNotes,
    pairings: output.pairings,
    vibeTag: output.vibeTag,
    vineyard: output.vineyard,
    soilType: output.soilType,
    climate: output.climate,
    drinkingWindow: output.drinkingWindow,
    abv: output.abv,
    winemakingStyle: output.winemakingStyle,
    category: output.category
  };
}

module.exports = {
  normalizeWineData
};
