# SommLens Lambda Scan Backend

Phase 2 backend for SommLens wine label scanning. The iOS app already sends JSON to API Gateway and expects direct `WineData` JSON back, so no iOS changes are required for this phase.

## Contract

Request:

```json
{
  "imageBase64": "...",
  "detail": "low"
}
```

Response:

```json
{
  "producer": "Example Producer",
  "country": "France",
  "region": "Burgundy",
  "subregion": null,
  "appellation": "Chablis",
  "classification": null,
  "grapes": ["Chardonnay"],
  "vintage": "2022",
  "tastingNotes": "A dry, bright white wine with crisp acidity, light body, citrus fruit, subtle orchard notes, and a mineral-leaning finish.",
  "pairings": ["Oysters", "Goat cheese tart", "Grilled fish with lemon"],
  "vibeTag": "crisp, clean, mineral, and bright",
  "vineyard": null,
  "soilType": "limestone",
  "climate": "cool continental",
  "drinkingWindow": "2024-2029",
  "abv": "12.5%",
  "winemakingStyle": "dry white",
  "category": "white"
}
```

`tastingNotes` must be a string. `grapes` and `pairings` must be string arrays. Optional unknown string fields are returned as `null`.

## Environment Variables

Required:

- `OPENAI_API_KEY`: OpenAI API key configured in Lambda environment variables.

Optional:

- `SCAN_TABLE_NAME`: DynamoDB table name for best-effort scan result storage. Scans still return to iOS if this is missing or a write fails, but no review record will be created.
- `OPENAI_MODEL`: defaults to `gpt-4.1`.
- `SCAN_MAX_TOKENS`: defaults to `700`.
- `MAX_IMAGE_BYTES`: defaults to `2000000`.

Do not paste API keys into source files or commit secrets.

## Manual Lambda Deploy For Now

For a manual first deployment:

1. Create a Node.js 20 Lambda function.
2. Set the handler to `src/handler.handler`.
3. Configure `OPENAI_API_KEY` in Lambda environment variables.
4. Put API Gateway in front of the Lambda with a `POST` route.
5. Keep the existing iOS request and response contract unchanged.

Package dependencies before zip upload so the DynamoDB client is available at runtime:

```bash
cd aws-lambda
npm install
zip -r function.zip src package.json package-lock.json node_modules
```

### AWS Console Code Editor

If editing directly in the Lambda console, create the same file paths shown in this folder:

```text
src/handler.js
src/prompt.js
src/wineDataSchema.js
src/validateRequest.js
src/normalizeWineData.js
src/scanRecordStore.js
```

Then paste each file's contents into the matching console file and deploy.

### Zip Upload

If uploading a zip, zip the contents of this `aws-lambda` folder so `src/handler.js` is at the zip root path:

```bash
cd aws-lambda
npm install
zip -r function.zip src package.json package-lock.json node_modules
```

Upload `function.zip` in the Lambda console and keep the handler set to `src/handler.handler`.

## DynamoDB Scan Record Storage

Phase 1 storage writes one unverified record after OpenAI returns valid normalized `WineData`.
The iOS contract does not change: Lambda still returns direct `WineData` JSON.

Create a DynamoDB table such as `SommLensScanRecords`:

- Partition key: `scanId` (`String`)
- Sort key: none

Set Lambda environment variable:

- `SCAN_TABLE_NAME=SommLensScanRecords`

Each successful stored item includes:

- `scanId`: UUID
- `createdAt`: ISO timestamp
- `verificationStatus`: `"unverified"`
- `producer`
- `wineName`
- `vintage`
- `country`
- `region`
- `appellation`
- `category`
- `fingerprint`: normalized lookup string built from available searchable fields
- `wineData`: the full normalized `WineData` object returned to iOS

The Lambda does not store `imageBase64`. If DynamoDB write fails, the Lambda logs a safe warning and still returns `WineData` to iOS.

Minimum Lambda IAM permission:

```json
{
  "Effect": "Allow",
  "Action": ["dynamodb:PutItem"],
  "Resource": "arn:aws:dynamodb:REGION:ACCOUNT_ID:table/SommLensScanRecords"
}
```

Later, when verified lookup exists, add a GSI such as `FingerprintVerificationIndex` with `fingerprint` as the partition key and a verification/status timestamp field as the sort key, then add `dynamodb:Query` for that index.

## Local Syntax Check

From this folder:

```bash
npm run check
```

## Test With curl

Prepare a small JPEG as base64:

```bash
IMAGE_BASE64="$(base64 -i /path/to/label.jpg | tr -d '\n')"
```

Call the deployed API Gateway endpoint:

```bash
curl -sS -X POST "https://YOUR_API_GATEWAY_URL" \
  -H "Content-Type: application/json" \
  --data "{\"imageBase64\":\"$IMAGE_BASE64\",\"detail\":\"low\"}"
```

Expected result is direct `WineData` JSON, not an OpenAI `choices` envelope.

## Notes

- The Lambda does not log image data, request bodies, API keys, or secrets.
- The Lambda does not store image data.
- DynamoDB scan record writes are best-effort and do not fail successful scans.
- Invalid client requests return `400`.
- Missing server configuration returns `500`.
- OpenAI failures or invalid model JSON return `502`.
- iOS should not change for Phase 2; it already sends JSON and decodes direct `WineData`.
