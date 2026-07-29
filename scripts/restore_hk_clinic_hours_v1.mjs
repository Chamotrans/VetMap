import {createHash} from "node:crypto";
import {chmod, mkdir, readFile, writeFile} from "node:fs/promises";
import path from "node:path";

const PROJECT_ID = "vetmap-app";
const DATABASE_ID = "(default)";
const FIRESTORE_ROOT =
  `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}`
  + `/databases/${DATABASE_ID}/documents`;
const MANIFEST_PATH = "catalog/hk_clinic_hours_v1.json";
const CLINIC_MANIFEST_PATH = "catalog/hk_clinics_v1.json";
const MIGRATION_ID = "hk-clinic-hours-v1-2026-07-30";
const ACCESS_TOKEN = process.env.FIREBASE_ACCESS_TOKEN;

let applyRequested = false;
let backupPathArgument;
for (let index = 2; index < process.argv.length; index += 1) {
  const argument = process.argv[index];
  if (argument === "--apply") {
    applyRequested = true;
    continue;
  }
  if (argument === "--backup") {
    const value = process.argv[index + 1];
    if (!value || value.startsWith("--")) {
      throw new Error("--backup requires a path.");
    }
    backupPathArgument = value;
    index += 1;
    continue;
  }
  throw new Error(`Unknown argument: ${argument}`);
}

const APPLY = applyRequested;
const backupTimestamp = new Date()
  .toISOString()
  .replaceAll(":", "-")
  .replace(/\.\d{3}Z$/, "Z");
const BACKUP_PATH = backupPathArgument
  ?? `build/backups/firestore-before-${MIGRATION_ID}-${backupTimestamp}.json`;

if (!ACCESS_TOKEN) {
  throw new Error(
    "Set FIREBASE_ACCESS_TOKEN to a current Firebase/Google OAuth access token.",
  );
}

const OFFICIAL_SOURCE_HOSTS = new Set([
  "amahvet.com.hk",
  "amcvet.com.hk",
  "cityuvmc.com.hk",
  "hvseh.com.hk",
  "n24.vet",
  "victoriavetshk.com",
  "www.creaturecomforts.com.hk",
  "www.spca.org.hk",
  "www.vec.com.hk",
  "www.vsh.com.hk",
]);
const WEEKDAY_KEYS = new Set([
  "sun",
  "mon",
  "tue",
  "wed",
  "thu",
  "fri",
  "sat",
]);
const TIME_PATTERN = /^(?:[01]\d|2[0-3]):[0-5]\d$/;

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
  if ("timestampValue" in value) {
    return new Date(value.timestampValue).toISOString();
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
  if ("geoPointValue" in value) return value.geoPointValue;
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

function encodeValue(value, fieldName = "") {
  if (fieldName === "verifiedAt" || fieldName === "expiresAt") {
    return {timestampValue: new Date(value).toISOString()};
  }
  if (typeof value === "string") return {stringValue: value};
  if (typeof value === "boolean") return {booleanValue: value};
  if (typeof value === "number") {
    return Number.isInteger(value)
      ? {integerValue: String(value)}
      : {doubleValue: value};
  }
  if (Array.isArray(value)) {
    return {
      arrayValue: {
        values: value.map((item) => encodeValue(item)),
      },
    };
  }
  if (value && typeof value === "object") {
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(value).map(([key, child]) => [
            key,
            encodeValue(child, key),
          ]),
        ),
      },
    };
  }
  throw new Error(`Cannot encode ${fieldName || "value"}.`);
}

function expectedAvailability(manifest, clinic) {
  return {
    schemaVersion: manifest.schemaVersion,
    migrationId: MIGRATION_ID,
    timeZoneIdentifier: manifest.timeZoneIdentifier,
    weeklyHours: clinic.weeklyHours,
    is24Hours: clinic.is24Hours,
    offersNightService: clinic.offersNightService,
    displayLabel: clinic.displayLabel,
    serviceNote: clinic.serviceNote,
    sourceURL: clinic.sourceURL,
    sourceName: clinic.sourceName,
    verifiedAt: new Date(manifest.verifiedAt).toISOString(),
    expiresAt: new Date(manifest.expiresAt).toISOString(),
  };
}

function normalizedJSON(value) {
  if (Array.isArray(value)) return value.map(normalizedJSON);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, normalizedJSON(value[key])]),
    );
  }
  return value;
}

function sameJSON(lhs, rhs) {
  return JSON.stringify(normalizedJSON(lhs)) === JSON.stringify(normalizedJSON(rhs));
}

function assertSafeManifest(manifest, clinicManifest) {
  if (
    manifest.schemaVersion !== 1
    || manifest.catalogRegion !== "HK"
    || manifest.timeZoneIdentifier !== "Asia/Hong_Kong"
    || manifest.count !== 11
    || !Array.isArray(manifest.clinics)
    || manifest.clinics.length !== manifest.count
  ) {
    throw new Error("Unexpected hours manifest header or count.");
  }
  const verifiedAt = new Date(manifest.verifiedAt);
  const expiresAt = new Date(manifest.expiresAt);
  if (
    Number.isNaN(verifiedAt.getTime())
    || Number.isNaN(expiresAt.getTime())
    || verifiedAt >= expiresAt
    || expiresAt <= new Date()
    || expiresAt.getTime() - verifiedAt.getTime() > 100 * 24 * 60 * 60 * 1000
  ) {
    throw new Error("Hours verification window is invalid.");
  }

  const authorizedByID = new Map(
    clinicManifest.clinics.map((clinic) => [clinic.id, clinic]),
  );
  const ids = new Set();
  for (const clinic of manifest.clinics) {
    const authorized = authorizedByID.get(clinic.clinicID);
    if (
      !authorized
      || authorized.name !== clinic.expectedName
      || ids.has(clinic.clinicID)
    ) {
      throw new Error(`${clinic.clinicID}: unauthorized, renamed, or duplicate.`);
    }
    ids.add(clinic.clinicID);

    let sourceURL;
    try {
      sourceURL = new URL(clinic.sourceURL);
    } catch {
      throw new Error(`${clinic.clinicID}: invalid source URL.`);
    }
    if (
      sourceURL.protocol !== "https:"
      || !OFFICIAL_SOURCE_HOSTS.has(sourceURL.hostname)
      || typeof clinic.sourceName !== "string"
      || clinic.sourceName.trim() === ""
      || typeof clinic.serviceNote !== "string"
      || clinic.serviceNote.trim() === ""
      || typeof clinic.is24Hours !== "boolean"
      || typeof clinic.offersNightService !== "boolean"
      || typeof clinic.displayLabel !== "string"
      || !clinic.weeklyHours
      || typeof clinic.weeklyHours !== "object"
      || Array.isArray(clinic.weeklyHours)
    ) {
      throw new Error(`${clinic.clinicID}: unsafe availability metadata.`);
    }
    if (clinic.is24Hours && clinic.displayLabel.trim() === "") {
      throw new Error(`${clinic.clinicID}: 24-hour entry needs a display label.`);
    }
    for (const [weekday, intervals] of Object.entries(clinic.weeklyHours)) {
      if (
        !WEEKDAY_KEYS.has(weekday)
        || !Array.isArray(intervals)
        || intervals.some(
          ({opensAt, closesAt}) =>
            !TIME_PATTERN.test(opensAt) || !TIME_PATTERN.test(closesAt),
        )
      ) {
        throw new Error(`${clinic.clinicID}: invalid ${weekday} schedule.`);
      }
    }
    if (!clinic.is24Hours && Object.keys(clinic.weeklyHours).length !== 7) {
      throw new Error(`${clinic.clinicID}: regular schedule must cover 7 days.`);
    }
  }
}

async function updateAvailability(document, availability) {
  const url = new URL(`${FIRESTORE_ROOT}/clinics/${document.id}`);
  url.searchParams.append("updateMask.fieldPaths", "availability");
  url.searchParams.set("currentDocument.updateTime", document.updateTime);
  const response = await fetch(url, {
    method: "PATCH",
    headers: authHeaders({"content-type": "application/json"}),
    body: JSON.stringify({
      fields: {
        availability: encodeValue(availability, "availability"),
      },
    }),
  });
  if (!response.ok) {
    throw new Error(
      `${document.id}: HTTP ${response.status} ${await response.text()}`,
    );
  }
}

const manifest = await readJSON(MANIFEST_PATH);
const clinicManifest = await readJSON(CLINIC_MANIFEST_PATH);
assertSafeManifest(manifest, clinicManifest);

const rawClinics = await listCollection("clinics");
const clinics = rawClinics.map(decodeDocument);
const clinicByID = new Map(clinics.map((clinic) => [clinic.id, clinic]));
const targets = manifest.clinics.map((entry) => {
  const document = clinicByID.get(entry.clinicID);
  if (
    !document
    || document.fields.status !== "approved"
    || document.fields.catalogRegion !== "HK"
    || document.fields.region !== "HK"
    || document.fields.name !== entry.expectedName
  ) {
    throw new Error(`${entry.clinicID}: production target is missing or unsafe.`);
  }
  return {
    entry,
    document,
    availability: expectedAvailability(manifest, entry),
  };
});

const backup = {
  projectId: PROJECT_ID,
  databaseId: DATABASE_ID,
  exportedAt: new Date().toISOString(),
  migrationId: MIGRATION_ID,
  collections: {
    clinics: targets.map(({document}) => document.raw),
  },
};
const serializedBackup = `${JSON.stringify(backup, null, 2)}\n`;
await mkdir(path.dirname(BACKUP_PATH), {recursive: true});
await writeFile(BACKUP_PATH, serializedBackup, {mode: 0o600});
await chmod(BACKUP_PATH, 0o600);
const backupSHA256 = createHash("sha256")
  .update(serializedBackup)
  .digest("hex");

console.log(JSON.stringify({
  mode: APPLY ? "apply" : "dry-run",
  projectId: PROJECT_ID,
  migrationId: MIGRATION_ID,
  manifestPath: MANIFEST_PATH,
  targetCount: targets.length,
  twentyFourHourCount: targets.filter(
    ({availability}) => availability.is24Hours,
  ).length,
  scheduledCount: targets.filter(
    ({availability}) => !availability.is24Hours,
  ).length,
  backupPath: BACKUP_PATH,
  backupSHA256,
}, null, 2));

if (!APPLY) process.exit(0);

for (const target of targets) {
  await updateAvailability(target.document, target.availability);
}

const verifiedByID = new Map(
  (await listCollection("clinics"))
    .map(decodeDocument)
    .map((document) => [document.id, document]),
);
for (const {entry, availability} of targets) {
  const actual = verifiedByID.get(entry.clinicID)?.fields.availability;
  if (!sameJSON(actual, availability)) {
    throw new Error(`${entry.clinicID}: post-migration verification failed.`);
  }
}

console.log(JSON.stringify({
  applied: true,
  verifiedCount: targets.length,
  verifiedAt: new Date(manifest.verifiedAt).toISOString(),
  expiresAt: new Date(manifest.expiresAt).toISOString(),
}, null, 2));
