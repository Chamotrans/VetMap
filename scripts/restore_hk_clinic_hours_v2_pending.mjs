import {createHash} from "node:crypto";
import {chmod, mkdir, readFile, writeFile} from "node:fs/promises";
import path from "node:path";
import {fileURLToPath} from "node:url";
import {
  validateHKClinicHoursV2Pending,
} from "./validate_hk_clinic_hours_v2_pending.mjs";

const PROJECT_ID = "vetmap-app";
const DATABASE_ID = "(default)";
const FIRESTORE_ROOT =
  `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}`
  + `/databases/${DATABASE_ID}/documents`;
const FIRESTORE_DOCUMENT_ROOT =
  `projects/${PROJECT_ID}/databases/${DATABASE_ID}/documents`;
const V1_MIGRATION_ID = "hk-clinic-hours-v1-2026-07-30";
const DEFAULT_PATHS = {
  catalog: "catalog/hk_clinics_v1.json",
  v1Hours: "catalog/hk_clinic_hours_v1.json",
  pending: "catalog/hk_clinic_hours_v2.pending.json",
  report: "catalog/hk_clinics_v1.report.json",
};

function usageError() {
  return new Error(
    "Usage: restore_hk_clinic_hours_v2_pending.mjs [--apply] [--backup PATH]",
  );
}

export function parseOptions(args) {
  let apply = false;
  let backupPath;
  let sawApply = false;
  let sawBackup = false;

  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === "--apply") {
      if (sawApply) throw usageError();
      sawApply = true;
      apply = true;
      continue;
    }
    if (argument === "--backup") {
      if (sawBackup) throw usageError();
      const value = args[index + 1];
      if (!value || value.startsWith("--")) throw usageError();
      sawBackup = true;
      backupPath = value;
      index += 1;
      continue;
    }
    throw usageError();
  }
  return {apply, backupPath};
}

function normalize(value) {
  if (Array.isArray(value)) return value.map(normalize);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.keys(value).sort().map((key) => [key, normalize(value[key])]),
    );
  }
  return value;
}

export function sameNormalizedJSON(lhs, rhs) {
  return JSON.stringify(normalize(lhs)) === JSON.stringify(normalize(rhs));
}

export function buildExpectedAvailability(manifest, clinic, migrationId) {
  return {
    schemaVersion: manifest.schemaVersion,
    migrationId: migrationId ?? manifest.migrationId,
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

export function decodeFirestoreValue(value) {
  if (!value || typeof value !== "object") {
    throw new Error("Unsupported Firestore value.");
  }
  if ("nullValue" in value) return null;
  if ("booleanValue" in value) return value.booleanValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return value.doubleValue;
  if ("timestampValue" in value) {
    return new Date(value.timestampValue).toISOString();
  }
  if ("stringValue" in value) return value.stringValue;
  if ("bytesValue" in value) return value.bytesValue;
  if ("referenceValue" in value) return value.referenceValue;
  if ("geoPointValue" in value) return value.geoPointValue;
  if ("arrayValue" in value) {
    return (value.arrayValue.values ?? []).map(decodeFirestoreValue);
  }
  if ("mapValue" in value) {
    return Object.fromEntries(
      Object.entries(value.mapValue.fields ?? {}).map(([key, child]) => [
        key,
        decodeFirestoreValue(child),
      ]),
    );
  }
  throw new Error("Unsupported Firestore value.");
}

export function decodeFirestoreDocument(raw) {
  if (!raw?.name || !raw?.updateTime) {
    throw new Error("Firestore clinic document is missing name or updateTime.");
  }
  return {
    id: raw.name.split("/").at(-1),
    updateTime: raw.updateTime,
    fields: Object.fromEntries(
      Object.entries(raw.fields ?? {}).map(([key, value]) => [
        key,
        decodeFirestoreValue(value),
      ]),
    ),
    raw,
  };
}

export function encodeFirestoreValue(value, fieldName = "") {
  if (fieldName === "verifiedAt" || fieldName === "expiresAt") {
    const date = new Date(value);
    if (!Number.isFinite(date.getTime())) {
      throw new Error(`${fieldName} must be a valid timestamp.`);
    }
    return {timestampValue: date.toISOString()};
  }
  if (value === null) return {nullValue: null};
  if (typeof value === "boolean") return {booleanValue: value};
  if (typeof value === "string") return {stringValue: value};
  if (typeof value === "number" && Number.isFinite(value)) {
    return Number.isInteger(value)
      ? {integerValue: String(value)}
      : {doubleValue: value};
  }
  if (Array.isArray(value)) {
    return {arrayValue: {values: value.map((child) => encodeFirestoreValue(child))}};
  }
  if (value && typeof value === "object") {
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(value).map(([key, child]) => [
            key,
            encodeFirestoreValue(child, key),
          ]),
        ),
      },
    };
  }
  throw new Error(`Cannot encode ${fieldName || "value"}.`);
}

function assertTargetIdentity(document, clinic) {
  if (!document) throw new Error(`v2 target missing: ${clinic.clinicID}`);
  if (
    typeof document.updateTime !== "string"
    || document.updateTime === ""
    || document.raw?.updateTime !== document.updateTime
    || document.raw?.name?.split("/").at(-1) !== clinic.clinicID
  ) {
    throw new Error(`v2 target snapshot is incomplete: ${clinic.clinicID}`);
  }
  if (document.fields.name !== clinic.expectedName) {
    throw new Error(`v2 target renamed: ${clinic.clinicID}`);
  }
  if (document.fields.status !== "approved") {
    throw new Error(`v2 target is not approved: ${clinic.clinicID}`);
  }
  if (
    document.fields.catalogRegion !== "HK"
    || document.fields.region !== "HK"
  ) {
    throw new Error(`v2 target is not in HK: ${clinic.clinicID}`);
  }
}

export function analyzeInventory(documents, {v1Hours, pending, phase = "pre"}) {
  if (phase !== "pre" && phase !== "post") {
    throw new Error(`Unknown inventory phase: ${phase}`);
  }
  const byID = new Map();
  for (const document of documents) {
    if (byID.has(document.id)) {
      throw new Error(`Duplicate Firestore clinic document: ${document.id}`);
    }
    byID.set(document.id, document);
  }

  const v1Expected = new Map(v1Hours.clinics.map((clinic) => [
    clinic.clinicID,
    buildExpectedAvailability(v1Hours, clinic, V1_MIGRATION_ID),
  ]));
  const v2Expected = new Map(pending.clinics.map((clinic) => [
    clinic.clinicID,
    buildExpectedAvailability(pending, clinic),
  ]));
  const plannedIDs = new Set([...v1Expected.keys(), ...v2Expected.keys()]);

  for (const [clinicID, expected] of v1Expected) {
    const actual = byID.get(clinicID)?.fields.availability;
    if (!sameNormalizedJSON(actual, expected)) {
      throw new Error(`v1 canonical availability drift: ${clinicID}`);
    }
  }
  const v1Values = [...v1Expected.keys()].map(
    (clinicID) => byID.get(clinicID).fields.availability,
  );
  const v1TwentyFourHours = v1Values.filter(({is24Hours}) => is24Hours).length;
  if (v1Values.length !== 11 || v1TwentyFourHours !== 10) {
    throw new Error("v1 availability distribution must be exactly 11/10/1.");
  }

  for (const clinic of pending.clinics) {
    assertTargetIdentity(byID.get(clinic.clinicID), clinic);
  }
  for (const document of documents) {
    if (
      Object.hasOwn(document.fields, "availability")
      && !plannedIDs.has(document.id)
    ) {
      throw new Error(`availability exists outside planned IDs: ${document.id}`);
    }
  }

  const v2States = pending.clinics.map((clinic) => {
    const fields = byID.get(clinic.clinicID).fields;
    if (!Object.hasOwn(fields, "availability")) return "absent";
    const availability = fields.availability;
    return sameNormalizedJSON(availability, v2Expected.get(clinic.clinicID))
      ? "exact"
      : "different";
  });
  const allAbsent = v2States.every((state) => state === "absent");
  const allExact = v2States.every((state) => state === "exact");
  if (!allAbsent && !allExact) {
    throw new Error(
      "v2 target availability must be all absent or all exact canonical.",
    );
  }
  if (phase === "post" && !allExact) {
    throw new Error("post-commit inventory is not the exact v2 canonical plan.");
  }

  const currentTotal = v1Values.length + (allExact ? pending.count : 0);
  const current24Hours = v1TwentyFourHours
    + (allExact ? pending.clinics.filter(({is24Hours}) => is24Hours).length : 0);
  const targets = pending.clinics.map(({clinicID}) => byID.get(clinicID));
  return {
    targets,
    expected: pending.clinics.map(({clinicID}) => v2Expected.get(clinicID)),
    allExact,
    current: {
      total: currentTotal,
      twentyFourHours: current24Hours,
      scheduled: currentTotal - current24Hours,
    },
  };
}

export function buildCommitWrites(targets, expected) {
  if (targets.length !== 4 || expected.length !== 4) {
    throw new Error("Atomic v2 migration must contain exactly four writes.");
  }
  return targets.map((target, index) => ({
    update: {
      name: `${FIRESTORE_DOCUMENT_ROOT}/clinics/${target.id}`,
      fields: {availability: encodeFirestoreValue(expected[index])},
    },
    updateMask: {fieldPaths: ["availability"]},
    currentDocument: {updateTime: target.updateTime},
  }));
}

export async function runMigration({
  options,
  readJSON,
  listClinics,
  writeBackup,
  commit,
  paths = DEFAULT_PATHS,
}) {
  const [catalog, v1Hours, pending, report] = await Promise.all([
    readJSON(paths.catalog),
    readJSON(paths.v1Hours),
    readJSON(paths.pending),
    readJSON(paths.report),
  ]);

  // This validator must finish before the first authoritative network call.
  validateHKClinicHoursV2Pending({catalog, v1Hours, pending, report});

  const before = analyzeInventory(await listClinics(), {v1Hours, pending});
  const backupResult = await writeBackup(before.targets.map(({raw}) => raw));
  if (
    !backupResult
    || typeof backupResult.path !== "string"
    || !/^[a-f0-9]{64}$/.test(backupResult.sha256 ?? "")
  ) {
    throw new Error("Backup did not return a path and SHA-256 digest.");
  }

  const result = {
    mode: options.apply ? "apply" : "dry-run",
    productionApplied: false,
    alreadyApplied: before.allExact,
    currentTotal: before.current.total,
    current24Hours: before.current.twentyFourHours,
    currentScheduled: before.current.scheduled,
    writeCount: before.allExact ? 0 : 4,
    plannedTotal: 15,
    planned24Hours: 11,
    plannedScheduled: 4,
    backupPath: backupResult.path,
    backupSHA256: backupResult.sha256,
  };
  if (!options.apply) return result;

  if (!before.allExact) {
    if (typeof commit !== "function") {
      throw new Error("Apply mode requires an atomic commit seam.");
    }
    const response = await commit({
      writes: buildCommitWrites(before.targets, before.expected),
    });
    if (!response?.ok) {
      throw new Error(`Atomic Firestore commit failed: HTTP ${response?.status ?? "unknown"}.`);
    }
  }

  const after = analyzeInventory(await listClinics(), {
    v1Hours,
    pending,
    phase: "post",
  });
  if (
    after.current.total !== 15
    || after.current.twentyFourHours !== 11
    || after.current.scheduled !== 4
  ) {
    throw new Error("Post-commit distribution must be exactly 15/11/4.");
  }
  return {
    ...result,
    productionApplied: true,
    currentTotal: after.current.total,
    current24Hours: after.current.twentyFourHours,
    currentScheduled: after.current.scheduled,
  };
}

function authHeaders(token, extra = {}) {
  return {authorization: `Bearer ${token}`, ...extra};
}

export async function listFirestoreClinics({fetchImpl, token}) {
  const documents = [];
  let pageToken = "";
  do {
    const url = new URL(`${FIRESTORE_ROOT}/clinics`);
    url.searchParams.set("pageSize", "1000");
    if (pageToken) url.searchParams.set("pageToken", pageToken);
    const response = await fetchImpl(url, {headers: authHeaders(token)});
    if (!response.ok) {
      throw new Error(`Authoritative clinic inventory failed: HTTP ${response.status}.`);
    }
    const body = await response.json();
    documents.push(...(body.documents ?? []).map(decodeFirestoreDocument));
    pageToken = body.nextPageToken ?? "";
  } while (pageToken);
  return documents;
}

export async function writeBackupFile(documents, backupPath) {
  const payload = `${JSON.stringify({documents}, null, 2)}\n`;
  await mkdir(path.dirname(backupPath), {recursive: true});
  await writeFile(backupPath, payload, {encoding: "utf8", mode: 0o600});
  await chmod(backupPath, 0o600);
  return {
    path: backupPath,
    sha256: createHash("sha256").update(payload).digest("hex"),
  };
}

async function main() {
  const options = parseOptions(process.argv.slice(2));
  const token = process.env.FIREBASE_ACCESS_TOKEN;
  if (!token) {
    throw new Error(
      "Set FIREBASE_ACCESS_TOKEN for the authoritative dry-run inventory.",
    );
  }
  const timestamp = new Date().toISOString()
    .replaceAll(":", "-")
    .replace(/\.\d{3}Z$/, "Z");
  const backupPath = options.backupPath
    ?? `build/backups/firestore-before-hk-clinic-hours-v2-${timestamp}.json`;
  const readJSONFile = async (filePath) => JSON.parse(
    await readFile(new URL(`../${filePath}`, import.meta.url), "utf8"),
  );
  const listClinics = () => listFirestoreClinics({fetchImpl: fetch, token});
  const result = await runMigration({
    options,
    readJSON: readJSONFile,
    listClinics,
    writeBackup: (documents) => writeBackupFile(documents, backupPath),
    commit: async ({writes}) => fetch(`${FIRESTORE_ROOT}:commit`, {
      method: "POST",
      headers: authHeaders(token, {"content-type": "application/json"}),
      body: JSON.stringify({writes}),
    }),
  });
  console.log(JSON.stringify(result));
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
