"use strict";

const nullableString = {
  type: ["string", "null"]
};

const wineDataSchema = {
  type: "object",
  additionalProperties: false,
  required: [
    "producer",
    "country",
    "region",
    "subregion",
    "appellation",
    "classification",
    "grapes",
    "vintage",
    "tastingNotes",
    "pairings",
    "vibeTag",
    "vineyard",
    "soilType",
    "climate",
    "drinkingWindow",
    "abv",
    "winemakingStyle",
    "category"
  ],
  properties: {
    producer: nullableString,
    country: nullableString,
    region: nullableString,
    subregion: nullableString,
    appellation: nullableString,
    classification: nullableString,
    grapes: {
      type: "array",
      items: { type: "string" }
    },
    vintage: nullableString,
    tastingNotes: { type: "string" },
    pairings: {
      type: "array",
      items: { type: "string" }
    },
    vibeTag: nullableString,
    vineyard: nullableString,
    soilType: nullableString,
    climate: nullableString,
    drinkingWindow: nullableString,
    abv: nullableString,
    winemakingStyle: nullableString,
    category: {
      type: "string",
      enum: [
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
      ]
    }
  }
};

module.exports = {
  wineDataSchema
};
