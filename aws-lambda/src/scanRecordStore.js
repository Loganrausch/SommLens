"use strict";

const { randomUUID } = require("crypto");
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand } = require("@aws-sdk/lib-dynamodb");

const dynamoClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));

function cleanPart(value) {
  if (value == null) return null;

  const cleaned = String(value)
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");

  return cleaned === "" ? null : cleaned;
}

function buildFingerprint(wineData) {
  const parts = [
    wineData.producer,
    wineData.wineName,
    wineData.vintage,
    wineData.country,
    wineData.region,
    wineData.appellation,
    wineData.category
  ]
    .map(cleanPart)
    .filter(Boolean);

  return parts.length > 0 ? parts.join("|") : null;
}

function buildScanRecord(wineData, now = new Date()) {
  const wineName = wineData.wineName || null;

  return {
    scanId: randomUUID(),
    createdAt: now.toISOString(),
    verificationStatus: "unverified",
    producer: wineData.producer || null,
    wineName,
    vintage: wineData.vintage || null,
    country: wineData.country || null,
    region: wineData.region || null,
    appellation: wineData.appellation || null,
    category: wineData.category || null,
    fingerprint: buildFingerprint({ ...wineData, wineName }),
    wineData
  };
}

async function storeScanRecord(wineData) {
  const tableName = process.env.SCAN_TABLE_NAME;
  if (!tableName) {
    console.warn("DynamoDB scan record skipped: SCAN_TABLE_NAME is not configured.");
    return null;
  }

  const record = buildScanRecord(wineData);

  await dynamoClient.send(new PutCommand({
    TableName: tableName,
    Item: record
  }));

  return record;
}

module.exports = {
  buildFingerprint,
  buildScanRecord,
  storeScanRecord
};
