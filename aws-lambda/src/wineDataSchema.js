"use strict";

const nullableString = {
  type: ["string", "null"]
};

function describedNullableString(description) {
  return {
    ...nullableString,
    description
  };
}

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
    producer: describedNullableString("Producer or estate name only if visible on the label or reliably identified; otherwise null."),
    country: describedNullableString("Wine country when visible or reliably inferable from region/appellation."),
    region: describedNullableString("Major wine region when visible or reliably inferable."),
    subregion: describedNullableString("Subregion or zone when visible or reliably inferable; otherwise null."),
    appellation: describedNullableString("Official appellation/village/AVA only if visible or reliably determined from the label; otherwise null."),
    classification: describedNullableString("Official classification such as AOC, DOCG, DOC, AVA, Premier Cru, or Grand Cru only if visible or reliably known; otherwise null."),
    grapes: {
      type: "array",
      description: "Specific grapes if visible or strictly defined by appellation; otherwise an empty array or one broad style classification.",
      items: { type: "string" }
    },
    vintage: describedNullableString("Four-digit vintage only if visible or reliably identified; otherwise null."),
    tastingNotes: {
      type: "string",
      description: "Single 20-35 word educational tasting note based on confirmed grape, region, style, or category. Never an array."
    },
    pairings: {
      type: "array",
      description: "Three specific food pairing strings based on style, grape, acidity, tannin, sweetness, body, and regional typicity.",
      items: { type: "string" }
    },
    vibeTag: describedNullableString("Six to ten word consumer-friendly tasting summary."),
    vineyard: describedNullableString("Named vineyard or site only if visible or reliably known for this exact wine; otherwise null."),
    soilType: describedNullableString("Broad regional or appellation soil type when known, such as limestone, clay-limestone, gravel, schist, granite, volcanic, or alluvial. Use null only if no reliable broad geology is available."),
    climate: describedNullableString("Broad wine-growing climate such as continental, maritime, Mediterranean, alpine, cool continental, warm dry, or temperate."),
    drinkingWindow: describedNullableString("Broad drinking window estimate when style, vintage, region, grape, or category support it. Use a general phrase for non-vintage/fresh styles or null if not responsibly estimable."),
    abv: describedNullableString("Alcohol by volume only if visible or reliably known; otherwise null."),
    winemakingStyle: describedNullableString("Broad educational style inferred from grape, region, and category, such as traditional dry white, oak-influenced red, sparkling method, fortified, oxidative, or aromatic off-dry. Avoid unsupported producer-specific claims."),
    category: {
      type: "string",
      description: "App-compatible normalized wine category.",
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
