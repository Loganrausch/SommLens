"use strict";

const { systemPrompt, userText } = require("./prompt");
const { wineDataSchema } = require("./wineDataSchema");
const { validateRequest } = require("./validateRequest");
const { normalizeWineData } = require("./normalizeWineData");
const { storeScanRecord } = require("./scanRecordStore");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Content-Type",
  "Access-Control-Allow-Methods": "OPTIONS,POST"
};

function jsonResponse(statusCode, body) {
  return {
    statusCode,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(body)
  };
}

function parsePositiveInteger(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function extractOpenAIContent(data) {
  const content = data && data.choices && data.choices[0] && data.choices[0].message
    ? data.choices[0].message.content
    : null;

  if (typeof content !== "string" || content.trim() === "") {
    throw new Error("OpenAI response did not include message content.");
  }

  return content
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();
}

async function callOpenAI({ imageBase64, detail }) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    const error = new Error("Missing OPENAI_API_KEY.");
    error.statusCode = 500;
    throw error;
  }

  const model = process.env.OPENAI_MODEL || "gpt-4.1";
  const maxTokens = parsePositiveInteger(process.env.SCAN_MAX_TOKENS, 700);

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`
    },
    body: JSON.stringify({
      model,
      temperature: 0,
      max_tokens: maxTokens,
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "wine_data",
          strict: true,
          schema: wineDataSchema
        }
      },
      messages: [
        {
          role: "system",
          content: systemPrompt
        },
        {
          role: "user",
          content: [
            {
              type: "text",
              text: userText
            },
            {
              type: "image_url",
              image_url: {
                url: `data:image/jpeg;base64,${imageBase64}`,
                detail
              }
            }
          ]
        }
      ]
    })
  });

  if (!response.ok) {
    let errorDetail = "";
    try {
      const errorBody = await response.json();
      errorDetail = errorBody && errorBody.error && errorBody.error.message
        ? `: ${errorBody.error.message}`
        : "";
    } catch {
      errorDetail = "";
    }

    const error = new Error(`OpenAI request failed with ${response.status}${errorDetail}`);
    error.statusCode = 502;
    throw error;
  }

  return response.json();
}

exports.handler = async (event) => {
  const method = (event && event.requestContext && event.requestContext.http && event.requestContext.http.method)
    || (event && event.httpMethod);

  if (method === "OPTIONS") {
    return jsonResponse(204, {});
  }

  const validation = validateRequest(event);
  if (!validation.ok) {
    return jsonResponse(validation.statusCode, { error: validation.message });
  }

  try {
    const openAIData = await callOpenAI(validation.value);
    const content = extractOpenAIContent(openAIData);
    const parsedWine = JSON.parse(content);
    const wineData = normalizeWineData(parsedWine);

    try {
      await storeScanRecord(wineData);
    } catch (storeError) {
      console.warn("DynamoDB scan record write failed:", storeError.message);
    }

    return jsonResponse(200, wineData);
  } catch (error) {
    const statusCode = error.statusCode || 502;

    if (statusCode >= 500) {
      console.error("Scan failed:", error.message);
    }

    if (statusCode === 500) {
      return jsonResponse(500, { error: "Server configuration error." });
    }

    return jsonResponse(502, { error: "Failed to process wine label scan." });
  }
};
