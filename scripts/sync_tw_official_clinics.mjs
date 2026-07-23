#!/usr/bin/env node

import {createHash} from "node:crypto";
import {execFileSync} from "node:child_process";
import {resolve} from "node:path";

const DATASET_ID = "tw-moa-vet-license-078";
const COLLECTION = "officialClinicCatalog";
const MANIFEST_ID = "tw-moa-078-manifest";
const SHARD_SIZE = 100;
const DATA_URL =
  "https://data.moa.gov.tw/Service/OpenData/DataFileService.aspx"
  + "?UnitId=078&IsTransData=1";
const SOURCE_URL = "https://data.gov.tw/dataset/8705";
const DETAILS_URL = "https://data.moa.gov.tw/open_detail.aspx?id=078";
const LICENSE_URL = "https://data.gov.tw/license";
const LICENSE_NAME = "OGDL-Taiwan-1.0";
const ADMIN_EMAIL = "appreview-admin@vetmap.app";

const repoRoot = resolve(import.meta.dirname, "..");
const firebasePlist = resolve(repoRoot, "VetMap", "GoogleService-Info.plist");
const apply = process.argv.includes("--apply");

function argumentValue(name) {
  const inline = process.argv.find((argument) => argument.startsWith(`${name}=`));
  if (inline) return inline.slice(name.length + 1);
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

const requestedSnapshotDate = argumentValue("--snapshot-date");
if (!requestedSnapshotDate || !/^\d{4}-\d{2}-\d{2}$/.test(requestedSnapshotDate)) {
  throw new Error(
    "Pass the verified source date as --snapshot-date YYYY-MM-DD. "
    + "Use --apply only after reviewing the dry-run summary.",
  );
}

function plistValue(key) {
  return execFileSync(
    "/usr/bin/plutil",
    ["-extract", key, "raw", firebasePlist],
    {encoding: "utf8"},
  ).trim();
}

function keychainPassword(service, account) {
  return execFileSync(
    "/usr/bin/security",
    ["find-generic-password", "-s", service, "-a", account, "-w"],
    {encoding: "utf8"},
  ).trim();
}

async function requestJSON(url, options = {}, allowedStatuses = [200]) {
  const response = await fetch(url, options);
  const body = await response.json().catch(() => ({}));
  if (!allowedStatuses.includes(response.status)) {
    const message =
      body?.error?.message
      ?? body?.error?.status
      ?? `HTTP ${response.status}`;
    throw new Error(message);
  }
  return {status: response.status, body};
}

function normalizedString(value, required = true) {
  const result = String(value ?? "").normalize("NFKC").trim();
  if (required && !result) throw new Error("Official row contains an empty field");
  return result;
}

function stableRecordID(city, licenseNumber) {
  const digest = createHash("sha256")
    .update(`${city}\u0000${licenseNumber}`, "utf8")
    .digest("hex")
    .slice(0, 24);
  return `tw-moa-078-${digest}`;
}

function normalizeRecord(row) {
  const city = normalizedString(row["縣市"]);
  const licenseNumber = normalizedString(row["字號"]);
  return {
    id: stableRecordID(city, licenseNumber),
    city,
    licenseNumber,
    licenseType: normalizedString(row["執照類別"]),
    licenseStatus: normalizedString(row["狀態"]),
    institutionName: normalizedString(row["機構名稱"]),
    phone: normalizedString(row["機構電話"], false),
    issueDate: normalizedString(row["發照日期"], false),
    address: normalizedString(row["機構地址"]),
  };
}

function chunks(values, size) {
  const result = [];
  for (let index = 0; index < values.length; index += size) {
    result.push(values.slice(index, index + size));
  }
  return result;
}

function firestoreValue(value, key = "") {
  if (key === "updatedAt") return {timestampValue: value};
  if (typeof value === "string") return {stringValue: value};
  if (typeof value === "number" && Number.isInteger(value)) {
    return {integerValue: String(value)};
  }
  if (typeof value === "number") return {doubleValue: value};
  if (typeof value === "boolean") return {booleanValue: value};
  if (Array.isArray(value)) {
    return {
      arrayValue: {
        values: value.map((item) => firestoreValue(item)),
      },
    };
  }
  if (value && typeof value === "object") {
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(value).map(([childKey, childValue]) => [
            childKey,
            firestoreValue(childValue, childKey),
          ]),
        ),
      },
    };
  }
  throw new Error(`Unsupported Firestore value for ${key || "root"}`);
}

function firestoreFields(document) {
  return Object.fromEntries(
    Object.entries(document).map(([key, value]) => [
      key,
      firestoreValue(value, key),
    ]),
  );
}

const [detailsResponse, dataResponse] = await Promise.all([
  fetch(DETAILS_URL, {headers: {"cache-control": "no-cache"}}),
  fetch(DATA_URL, {headers: {"cache-control": "no-cache"}}),
]);
if (!detailsResponse.ok || !dataResponse.ok) {
  throw new Error(
    `Official source unavailable: details=${detailsResponse.status}, `
    + `data=${dataResponse.status}`,
  );
}

const detailsHTML = await detailsResponse.text();
const sourceDateMatch = detailsHTML.match(
  /資料更新日期[\s\S]{0,500}?(\d{4})\/(\d{2})\/(\d{2})/,
);
if (!sourceDateMatch) {
  throw new Error("Could not verify the source update date");
}
const sourceSnapshotDate =
  `${sourceDateMatch[1]}-${sourceDateMatch[2]}-${sourceDateMatch[3]}`;
if (sourceSnapshotDate !== requestedSnapshotDate) {
  throw new Error(
    `Source date is ${sourceSnapshotDate}, not ${requestedSnapshotDate}; `
    + "review the new source before publishing.",
  );
}

const sourceRows = await dataResponse.json();
if (!Array.isArray(sourceRows) || sourceRows.length < 100) {
  throw new Error("Official endpoint returned an implausible record set");
}

const records = sourceRows.map(normalizeRecord).sort((left, right) => {
  const cityOrder = left.city.localeCompare(right.city, "zh-Hant");
  if (cityOrder !== 0) return cityOrder;
  const nameOrder = left.institutionName.localeCompare(
    right.institutionName,
    "zh-Hant",
  );
  if (nameOrder !== 0) return nameOrder;
  return left.licenseNumber.localeCompare(right.licenseNumber, "zh-Hant");
});

const ids = new Set(records.map((record) => record.id));
if (ids.size !== records.length) {
  throw new Error("Official endpoint contains duplicate city/licence identities");
}

const recordShards = chunks(records, SHARD_SIZE);
const shardDocuments = recordShards.map((shardRecords, index) => ({
  id:
    `tw-moa-078-${requestedSnapshotDate}-shard-`
    + String(index).padStart(3, "0"),
  data: {
    kind: "shard",
    datasetId: DATASET_ID,
    snapshotDate: requestedSnapshotDate,
    index,
    records: shardRecords,
  },
}));

const manifest = {
  kind: "manifest",
  datasetId: DATASET_ID,
  sourceName:
    `農業部／動植物防疫檢疫署 ${requestedSnapshotDate.slice(0, 4)}`
    + "〈獸醫師(佐)開業執照〉",
  sourceURL: SOURCE_URL,
  licenseName: LICENSE_NAME,
  licenseURL: LICENSE_URL,
  snapshotDate: requestedSnapshotDate,
  recordCount: records.length,
  shardCount: shardDocuments.length,
  updatedAt: new Date().toISOString(),
  status: "published",
};

const statusCounts = Object.fromEntries(
  [...new Set(records.map((record) => record.licenseStatus))]
    .sort()
    .map((status) => [
      status,
      records.filter((record) => record.licenseStatus === status).length,
    ]),
);
const summary = {
  mode: apply ? "apply" : "dry-run",
  datasetId: DATASET_ID,
  snapshotDate: requestedSnapshotDate,
  recordCount: records.length,
  shardCount: shardDocuments.length,
  statusCounts,
  responsibleVeterinarianExcluded: sourceRows.every(
    (row) => !Object.hasOwn(normalizeRecord(row), "負責獸醫"),
  ),
};

if (!apply) {
  console.log(JSON.stringify(summary, null, 2));
  process.exit(0);
}

const apiKey = plistValue("API_KEY");
const projectId = plistValue("PROJECT_ID");
const password = keychainPassword("VetMap App Review Admin", ADMIN_EMAIL);
const signIn = await requestJSON(
  `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword`
    + `?key=${encodeURIComponent(apiKey)}`,
  {
    method: "POST",
    headers: {"content-type": "application/json"},
    body: JSON.stringify({
      email: ADMIN_EMAIL,
      password,
      returnSecureToken: true,
    }),
  },
);
const idToken = signIn.body.idToken;
const uid = signIn.body.localId;
if (!idToken || !uid) throw new Error("Firebase admin sign-in failed");

const firestoreBase =
  `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}`
  + "/databases/(default)/documents";
const authHeaders = {
  authorization: `Bearer ${idToken}`,
  "content-type": "application/json",
};

const profile = await requestJSON(
  `${firestoreBase}/users/${encodeURIComponent(uid)}`,
  {headers: authHeaders},
);
if (profile.body?.fields?.role?.stringValue !== "admin") {
  throw new Error("The publishing account is not a VetMap admin");
}

async function writeDocument(documentID, data) {
  await requestJSON(
    `${firestoreBase}/${COLLECTION}/${encodeURIComponent(documentID)}`,
    {
      method: "PATCH",
      headers: authHeaders,
      body: JSON.stringify({fields: firestoreFields(data)}),
    },
  );
}

// Publish every immutable shard first. The manifest is the final promotion
// pointer, so a failed upload cannot expose a partial new snapshot to the app.
for (const shard of shardDocuments) {
  await writeDocument(shard.id, shard.data);
}
await writeDocument(MANIFEST_ID, manifest);

const publicManifest = await requestJSON(
  `${firestoreBase}/${COLLECTION}/${MANIFEST_ID}`,
);
const publicFirstShard = await requestJSON(
  `${firestoreBase}/${COLLECTION}/${encodeURIComponent(shardDocuments[0].id)}`,
);
if (
  publicManifest.body?.fields?.status?.stringValue !== "published"
  || publicFirstShard.body?.fields?.kind?.stringValue !== "shard"
) {
  throw new Error("Published official catalog is not anonymously readable");
}

console.log(JSON.stringify({
  ...summary,
  adminVerified: true,
  publicReadVerified: true,
}, null, 2));
