import {createHash} from "node:crypto";
import {mkdir, readFile, writeFile} from "node:fs/promises";
import path from "node:path";

const PROJECT_ID = "vetmap-app";
const DATABASE_ID = "(default)";
const FIRESTORE_ROOT =
  `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}`
  + `/databases/${DATABASE_ID}/documents`;
const MANIFEST_PATH = "catalog/hk_clinics_v1.json";
const MIGRATION_ID = "hk-clinics-v2-2026-07-28";
const APPLY = process.argv.includes("--apply");
const BACKUP_ARGUMENT_INDEX = process.argv.indexOf("--backup");
const BACKUP_PATH =
  BACKUP_ARGUMENT_INDEX >= 0
    ? process.argv[BACKUP_ARGUMENT_INDEX + 1]
    : `build/backups/firestore-before-${MIGRATION_ID}-${new Date()
      .toISOString()
      .replaceAll(":", "-")
      .replaceAll(".", "-")}.json`;
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

async function readJSON(filePath) {
  return JSON.parse(await readFile(filePath, "utf8"));
}

async function listCollection(collection) {
  const documents = [];
  let pageToken = "";
  do {
    const url = new URL(`${FIRESTORE_ROOT}/${collection}`);
    url.searchParams.set("pageSize", "1000");
    if (pageToken) url.searchParams.set("pageToken", pageToken);
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

function stringValue(value) {
  return {stringValue: value};
}

function timestampValue(value) {
  return {timestampValue: value};
}

function numberValue(value) {
  return Number.isInteger(value)
    ? {integerValue: String(value)}
    : {doubleValue: value};
}

function arrayValue(values) {
  return {arrayValue: {values: values.map(stringValue)}};
}

function coordinateValue(coordinate) {
  return {
    mapValue: {
      fields: {
        latitude: {doubleValue: coordinate.latitude},
        longitude: {doubleValue: coordinate.longitude},
      },
    },
  };
}

function assertSafeManifest(manifest) {
  if (
    manifest.schemaVersion !== 1
    || manifest.catalogRegion !== "HK"
    || manifest.count !== 179
    || !Array.isArray(manifest.clinics)
    || manifest.clinics.length !== 179
  ) {
    throw new Error("Unexpected clinic manifest header or count.");
  }
  const ids = new Set();
  for (const clinic of manifest.clinics) {
    if (
      typeof clinic.id !== "string"
      || !/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(clinic.id)
      || ids.has(clinic.id)
    ) {
      throw new Error(`Invalid or duplicate clinic ID: ${clinic.id}`);
    }
    ids.add(clinic.id);
    for (const field of ["name", "address", "sourceName", "rightsBasis"]) {
      if (typeof clinic[field] !== "string" || clinic[field].trim() === "") {
        throw new Error(`${clinic.id}: missing ${field}.`);
      }
    }
    if (
      clinic.rightsBasis
        !== "Owner confirmed database was created in-house or licensed for use"
      || clinic.rightsConfirmedAt !== manifest.rightsConfirmedAt
      || clinic.expiresAt !== manifest.expiresAt
      || /(中國|中国|內地|内地|台灣|臺灣|台湾|Taiwan|Taipei|深圳|廣州|广州|澳門|澳门|Macau|Macao)/iu
        .test(clinic.address)
    ) {
      throw new Error(`${clinic.id}: unsafe source or region metadata.`);
    }
    if (clinic.coordinate) {
      const {latitude, longitude} = clinic.coordinate;
      if (
        !Number.isFinite(latitude)
        || !Number.isFinite(longitude)
        || latitude < 22.1
        || latitude > 22.6
        || longitude < 113.8
        || longitude > 114.5
        || typeof clinic.coordinateSource !== "string"
        || !Number.isFinite(clinic.coordinateMatchScore)
      ) {
        throw new Error(`${clinic.id}: unsafe coordinate.`);
      }
    }
  }
  const expiry = new Date(manifest.expiresAt);
  if (Number.isNaN(expiry.getTime()) || expiry <= new Date()) {
    throw new Error("Clinic manifest has expired.");
  }
}

function firestoreFields(clinic, existing, timestamp) {
  const createdAt =
    existing?.fields.createdAt
    && !Number.isNaN(new Date(existing.fields.createdAt).getTime())
      ? existing.fields.createdAt
      : timestamp;
  const fields = {
    id: stringValue(clinic.id),
    name: stringValue(clinic.name),
    address: stringValue(clinic.address),
    phone: stringValue(clinic.phone ?? ""),
    openingHours: {mapValue: {fields: {}}},
    services: arrayValue([]),
    avgRating: {doubleValue: 0},
    reviewCount: {integerValue: "0"},
    priceLevel: {integerValue: "0"},
    images: arrayValue([]),
    tags: arrayValue([]),
    createdAt: timestampValue(createdAt),
    updatedAt: timestampValue(timestamp),
    reportedBy: stringValue("vetmap-catalog"),
    verified: {booleanValue: false},
    authorId: stringValue("vetmap-curation"),
    status: stringValue("approved"),
    approvedAt: timestampValue(timestamp),
    catalogRegion: stringValue("HK"),
    region: stringValue("HK"),
    migrationId: stringValue(MIGRATION_ID),
    district: stringValue(clinic.district ?? ""),
    sourceRecordIDs: arrayValue(clinic.sourceRecordIDs ?? []),
    sourceName: stringValue(clinic.sourceName),
    rightsBasis: stringValue(clinic.rightsBasis),
    rightsConfirmedAt: timestampValue(clinic.rightsConfirmedAt),
    verifiedAt: timestampValue(clinic.verifiedAt),
    expiresAt: timestampValue(clinic.expiresAt),
  };
  if (clinic.coordinate) {
    fields.coordinate = coordinateValue(clinic.coordinate);
    fields.coordinateSource = stringValue(clinic.coordinateSource);
    fields.coordinateMatchScore = numberValue(clinic.coordinateMatchScore);
  }
  return fields;
}

const updateMask = [
  "id",
  "name",
  "address",
  "coordinate",
  "phone",
  "website",
  "openingHours",
  "services",
  "avgRating",
  "reviewCount",
  "priceLevel",
  "images",
  "tags",
  "createdAt",
  "updatedAt",
  "reportedBy",
  "verified",
  "authorId",
  "status",
  "approvedAt",
  "catalogRegion",
  "region",
  "migrationId",
  "district",
  "sourceRecordIDs",
  "sourceName",
  "rightsBasis",
  "rightsConfirmedAt",
  "verifiedAt",
  "expiresAt",
  "coordinateSource",
  "coordinateMatchScore",
];

async function upsertClinic(clinic, existing, timestamp) {
  const url = new URL(`${FIRESTORE_ROOT}/clinics/${clinic.id}`);
  for (const fieldPath of updateMask) {
    url.searchParams.append("updateMask.fieldPaths", fieldPath);
  }
  if (existing?.updateTime) {
    url.searchParams.set("currentDocument.updateTime", existing.updateTime);
  } else {
    url.searchParams.set("currentDocument.exists", "false");
  }
  const response = await fetch(url, {
    method: "PATCH",
    headers: authHeaders({"content-type": "application/json"}),
    body: JSON.stringify({
      fields: firestoreFields(clinic, existing, timestamp),
    }),
  });
  if (!response.ok) {
    throw new Error(
      `${clinic.id}: HTTP ${response.status} ${await response.text()}`,
    );
  }
}

const manifest = await readJSON(MANIFEST_PATH);
assertSafeManifest(manifest);

const rawClinics = await listCollection("clinics");
const decodedClinics = rawClinics.map(decodeDocument);
const existingByID = new Map(decodedClinics.map((document) => [document.id, document]));
const manifestIDs = new Set(manifest.clinics.map(({id}) => id));
const existingTargetCount = manifest.clinics.filter(
  ({id}) => existingByID.has(id),
).length;
const unexpectedPublishedHK = decodedClinics.filter(
  ({id, fields}) =>
    !manifestIDs.has(id)
    && id !== "vetmap-demo-clinic"
    && fields.status === "approved"
    && fields.catalogRegion === "HK",
);
if (unexpectedPublishedHK.length > 0) {
  throw new Error(
    "Unexpected approved HK clinics outside the manifest: "
      + unexpectedPublishedHK.map(({id}) => id).join(", "),
  );
}

const backup = {
  projectId: PROJECT_ID,
  databaseId: DATABASE_ID,
  exportedAt: new Date().toISOString(),
  migrationId: MIGRATION_ID,
  collections: {clinics: rawClinics},
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
  manifestPath: MANIFEST_PATH,
  manifestCount: manifest.clinics.length,
  mappableCount: manifest.clinics.filter(({coordinate}) => coordinate).length,
  listOnlyCount: manifest.clinics.filter(({coordinate}) => !coordinate).length,
  existingTargetCount,
  createCount: manifest.clinics.length - existingTargetCount,
  preservedDemo: existingByID.has("vetmap-demo-clinic"),
  backupPath: BACKUP_PATH,
  backupSHA256,
}, null, 2));

if (!APPLY) process.exit(0);

const migrationTimestamp = new Date().toISOString();
for (const [index, clinic] of manifest.clinics.entries()) {
  await upsertClinic(clinic, existingByID.get(clinic.id), migrationTimestamp);
  if ((index + 1) % 25 === 0) {
    console.error(`Migrated ${index + 1}/${manifest.clinics.length} clinics.`);
  }
}

const verified = (await listCollection("clinics"))
  .map(decodeDocument)
  .filter(({id}) => manifestIDs.has(id));
const mappableCount = verified.filter(({fields}) => fields.coordinate).length;
if (
  verified.length !== 179
  || mappableCount
    !== manifest.clinics.filter(({coordinate}) => coordinate).length
  || verified.some(
    ({fields}) =>
      fields.status !== "approved"
      || fields.catalogRegion !== "HK"
      || fields.region !== "HK"
      || fields.migrationId !== MIGRATION_ID
      || fields.verified !== false
      || fields.avgRating !== 0
      || fields.reviewCount !== 0
      || fields.priceLevel !== 0
      || (fields.services ?? []).length !== 0
      || (fields.tags ?? []).length !== 0,
  )
) {
  throw new Error("Post-migration clinic verification failed.");
}

console.log(JSON.stringify({
  applied: true,
  verifiedCount: verified.length,
  mappableCount,
  listOnlyCount: verified.length - mappableCount,
  migrationTimestamp,
}, null, 2));
