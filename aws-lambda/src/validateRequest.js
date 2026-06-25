"use strict";

const ALLOWED_DETAIL_VALUES = new Set(["low", "high", "auto"]);

function parsePositiveInteger(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function stripDataUrlPrefix(value) {
  return value.replace(/^data:image\/[a-zA-Z0-9.+-]+;base64,/, "");
}

function parseEventBody(event) {
  if (!event || event.body == null) {
    return { error: "Missing JSON request body." };
  }

  if (typeof event.body === "object") {
    return { body: event.body };
  }

  try {
    const rawBody = event.isBase64Encoded
      ? Buffer.from(event.body, "base64").toString("utf8")
      : event.body;

    return { body: JSON.parse(rawBody) };
  } catch {
    return { error: "Request body must be valid JSON." };
  }
}

function validateRequest(event, options = {}) {
  const maxImageBytes = parsePositiveInteger(
    options.maxImageBytes || process.env.MAX_IMAGE_BYTES,
    2000000
  );

  const parsed = parseEventBody(event);
  if (parsed.error) {
    return { ok: false, statusCode: 400, message: parsed.error };
  }

  const body = parsed.body;
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return { ok: false, statusCode: 400, message: "Request body must be a JSON object." };
  }

  if (typeof body.imageBase64 !== "string" || body.imageBase64.trim() === "") {
    return { ok: false, statusCode: 400, message: "imageBase64 is required." };
  }

  const imageBase64 = stripDataUrlPrefix(body.imageBase64.trim()).replace(/\s/g, "");

  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(imageBase64) || imageBase64.length % 4 !== 0) {
    return { ok: false, statusCode: 400, message: "imageBase64 must be valid base64." };
  }

  const imageBuffer = Buffer.from(imageBase64, "base64");
  if (imageBuffer.length === 0) {
    return { ok: false, statusCode: 400, message: "imageBase64 decoded to an empty image." };
  }

  if (imageBuffer.length > maxImageBytes) {
    return {
      ok: false,
      statusCode: 400,
      message: `Decoded image exceeds ${maxImageBytes} bytes.`
    };
  }

  const detail = typeof body.detail === "string" ? body.detail.toLowerCase() : "low";
  if (!ALLOWED_DETAIL_VALUES.has(detail)) {
    return {
      ok: false,
      statusCode: 400,
      message: "detail must be one of: low, high, auto."
    };
  }

  return {
    ok: true,
    value: {
      imageBase64,
      detail,
      imageBytes: imageBuffer.length
    }
  };
}

module.exports = {
  validateRequest
};
