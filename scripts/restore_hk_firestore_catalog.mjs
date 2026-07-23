import {createHash} from "node:crypto";
import {mkdir, writeFile} from "node:fs/promises";
import path from "node:path";

const PROJECT_ID = "vetmap-app";
const DATABASE_ID = "(default)";
const FIRESTORE_ROOT =
  `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}`
  + `/databases/${DATABASE_ID}/documents`;
const MIGRATION_ID = "hk-v1-normalize-2026-07-24";

const HK_CLINIC_IDS = new Set([
  "hk-69dad9893b2c2f0a8731",
  "hk-69dad98a3b2c2f0a8731",
  "hk-69dc64ed544efd16046c",
  "hk-69dceac485c5cd6a0637",
  "hk-69dcead9f1da3469d949",
  "hk-animal-medical-centre",
  "hk-hung-hom-veterinary-clinic",
  "hk-macpherson-animal-clinic",
  "hk-npv-non-profit-vet-services-npv29",
  "hk-peace-avenue-veterinary-clinic---cityu-a",
]);

const APPLY = process.argv.includes("--apply");
const BACKUP_ARGUMENT_INDEX = process.argv.indexOf("--backup");
const BACKUP_PATH =
  BACKUP_ARGUMENT_INDEX >= 0
    ? process.argv[BACKUP_ARGUMENT_INDEX + 1]
    : `build/backups/firestore-before-${MIGRATION_ID}.json`;
const ACCESS_TOKEN = process.env.FIREBASE_ACCESS_TOKEN;

if (!ACCESS_TOKEN) {
  throw new Error(
    "Set FIREBASE_ACCESS_TOKEN to a current Firebase/Google OAuth access token.",
  );
}

if (BACKUP_ARGUMENT_INDEX >= 0 && !BACKUP_PATH) {
  throw new Error("--backup requires a path.");
}

function authHeaders(extra = {}) {
  return {
    authorization: `Bearer ${ACCESS_TOKEN}`,
    ...extra,
  };
}

async function listCollection(collection) {
  const documents = [];
  let pageToken = "";

  do {
    const url = new URL(`${FIRESTORE_ROOT}/${collection}`);
    url.searchParams.set("pageSize", "1000");
    if (pageToken) {
      url.searchParams.set("pageToken", pageToken);
    }

    const response = await fetch(url, {headers: authHeaders()});
    if (!response.ok) {
      throw new Error(
        `${collection}: HTTP ${response.status} ${await response.text()}`,
      );
    }

    const body = await response.json();
    documents.push(...(body.documents ?? []));
    pageToken = body.nextPageToken ?? "";
  } while (pageToken);

  return documents;
}

function decodeValue(value) {
  if ("nullValue" in value) return null;
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return value.doubleValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("timestampValue" in value) return value.timestampValue;
  if ("geoPointValue" in value) {
    return {
      latitude: value.geoPointValue.latitude,
      longitude: value.geoPointValue.longitude,
    };
  }
  if ("arrayValue" in value) {
    return (value.arrayValue.values ?? []).map(decodeValue);
  }
  if ("mapValue" in value) {
    return Object.fromEntries(
      Object.entries(value.mapValue.fields ?? {}).map(([key, child]) => [
        key,
        decodeValue(child),
      ]),
    );
  }
  throw new Error("Unsupported Firestore value.");
}

function decodeDocument(document) {
  return {
    id: document.name.split("/").at(-1),
    createTime: document.createTime,
    updateTime: document.updateTime,
    fields: Object.fromEntries(
      Object.entries(document.fields ?? {}).map(([key, value]) => [
        key,
        decodeValue(value),
      ]),
    ),
    raw: document,
  };
}

function assertSafeHKClinic(document) {
  const {id, fields} = document;
  const {coordinate} = fields;

  if (!HK_CLINIC_IDS.has(id)) {
    throw new Error(`Unexpected migration candidate: ${id}`);
  }
  if (fields.reportedBy !== "epetpet-hk") {
    throw new Error(`${id}: unexpected reportedBy value.`);
  }
  if (fields.status != null) {
    throw new Error(`${id}: already has moderation status ${fields.status}.`);
  }
  for (const field of ["id", "name", "address", "phone", "createdAt"]) {
    if (typeof fields[field] !== "string" || fields[field].trim() === "") {
      throw new Error(`${id}: missing required source field ${field}.`);
    }
  }
  if (fields.id !== id) {
    throw new Error(`${id}: document ID and stored ID differ.`);
  }
  if (
    coordinate == null
    || typeof coordinate.latitude !== "number"
    || typeof coordinate.longitude !== "number"
    || coordinate.latitude < 22.1
    || coordinate.latitude > 22.6
    || coordinate.longitude < 113.8
    || coordinate.longitude > 114.5
  ) {
    throw new Error(`${id}: coordinate is outside the Hong Kong safety bounds.`);
  }
}

function normalizedFields(timestamp) {
  return {
    openingHours: {mapValue: {fields: {}}},
    services: {arrayValue: {values: []}},
    avgRating: {doubleValue: 0},
    reviewCount: {integerValue: "0"},
    priceLevel: {integerValue: "0"},
    images: {arrayValue: {values: []}},
    tags: {arrayValue: {values: []}},
    updatedAt: {timestampValue: timestamp},
    verified: {booleanValue: false},
    status: {stringValue: "approved"},
    approvedAt: {timestampValue: timestamp},
    authorId: {stringValue: "vetmap-curation"},
    catalogRegion: {stringValue: "HK"},
    migrationId: {stringValue: MIGRATION_ID},
  };
}

async function patchClinic(document, timestamp) {
  const url = new URL(`${FIRESTORE_ROOT}/clinics/${document.id}`);
  for (const fieldPath of Object.keys(normalizedFields(timestamp))) {
    url.searchParams.append("updateMask.fieldPaths", fieldPath);
  }
  url.searchParams.set(
    "currentDocument.updateTime",
    document.updateTime,
  );

  const response = await fetch(url, {
    method: "PATCH",
    headers: authHeaders({"content-type": "application/json"}),
    body: JSON.stringify({fields: normalizedFields(timestamp)}),
  });
  if (!response.ok) {
    throw new Error(
      `${document.id}: HTTP ${response.status} ${await response.text()}`,
    );
  }
}

const rawCollections = {};
for (const collection of ["clinics", "reviews", "quotes"]) {
  rawCollections[collection] = await listCollection(collection);
}

const decodedClinics = rawCollections.clinics.map(decodeDocument);
const candidates = decodedClinics.filter(
  ({id, fields}) =>
    HK_CLINIC_IDS.has(id)
    || (fields.status == null && fields.reportedBy === "epetpet-hk"),
);

if (candidates.length !== HK_CLINIC_IDS.size) {
  throw new Error(
    `Expected ${HK_CLINIC_IDS.size} HK clinics, found ${candidates.length}.`,
  );
}
for (const clinic of candidates) {
  assertSafeHKClinic(clinic);
}

const foundIDs = new Set(candidates.map(({id}) => id));
for (const expectedID of HK_CLINIC_IDS) {
  if (!foundIDs.has(expectedID)) {
    throw new Error(`Missing expected HK clinic: ${expectedID}`);
  }
}

const backup = {
  projectId: PROJECT_ID,
  databaseId: DATABASE_ID,
  exportedAt: new Date().toISOString(),
  migrationId: MIGRATION_ID,
  collections: rawCollections,
};
const serializedBackup = `${JSON.stringify(backup, null, 2)}\n`;
await mkdir(path.dirname(BACKUP_PATH), {recursive: true});
await writeFile(BACKUP_PATH, serializedBackup, {mode: 0o600});
const backupSHA256 = createHash("sha256")
  .update(serializedBackup)
  .digest("hex");

console.log(JSON.stringify({
  mode: APPLY ? "apply" : "dry-run",
  projectId: PROJECT_ID,
  migrationId: MIGRATION_ID,
  candidateCount: candidates.length,
  candidateIDs: candidates.map(({id}) => id).sort(),
  backupPath: BACKUP_PATH,
  backupSHA256,
  normalization: {
    preserves: ["id", "name", "address", "coordinate", "phone", "createdAt"],
    clearsUnverifiedClaims: [
      "openingHours",
      "services",
      "ratings",
      "reviewCount",
      "priceLevel",
      "images",
      "tags",
    ],
    publishesRegion: "HK",
    publishesLegacyReviews: false,
    publishesLegacyQuotes: false,
  },
}, null, 2));

if (!APPLY) {
  process.exit(0);
}

const migrationTimestamp = new Date().toISOString();
for (const clinic of candidates) {
  await patchClinic(clinic, migrationTimestamp);
}

const verified = (await listCollection("clinics"))
  .map(decodeDocument)
  .filter(({id}) => HK_CLINIC_IDS.has(id));
if (
  verified.length !== HK_CLINIC_IDS.size
  || verified.some(
    ({fields}) =>
      fields.status !== "approved"
      || fields.catalogRegion !== "HK"
      || fields.migrationId !== MIGRATION_ID
      || fields.verified !== false
      || fields.avgRating !== 0
      || fields.reviewCount !== 0
      || fields.priceLevel !== 0
      || Object.keys(fields.openingHours ?? {}).length !== 0
      || (fields.services ?? []).length !== 0
      || (fields.tags ?? []).length !== 0,
  )
) {
  throw new Error("Post-migration verification failed.");
}

console.log(JSON.stringify({
  applied: true,
  verifiedCount: verified.length,
  migrationTimestamp,
}));
