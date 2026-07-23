import { readFile } from "node:fs/promises";

const projectId = "vetmap-app";
const plistURL = new URL("../VetMap/GoogleService-Info.plist", import.meta.url);
const plist = await readFile(plistURL, "utf8");
const apiKeyMatch = plist.match(
  /<key>API_KEY<\/key>\s*<string>([^<]+)<\/string>/,
);

if (!apiKeyMatch) {
  throw new Error("GoogleService-Info.plist is missing API_KEY");
}

async function listApproved(collection) {
  const url = new URL(
    `https://firestore.googleapis.com/v1/projects/${projectId}`
      + "/databases/(default)/documents:runQuery",
  );
  url.searchParams.set("key", apiKeyMatch[1]);

  const response = await fetch(url, {
    method: "POST",
    headers: {"content-type": "application/json"},
    body: JSON.stringify({
      structuredQuery: {
        from: [{collectionId: collection}],
        where: {
          fieldFilter: {
            field: {fieldPath: "status"},
            op: "EQUAL",
            value: {stringValue: "approved"},
          },
        },
        limit: 300,
      },
    }),
  });
  if (!response.ok) {
    throw new Error(`${collection}: HTTP ${response.status}`);
  }
  const rows = await response.json();
  return rows.flatMap((row) => row.document ? [row.document] : []);
}

async function listOfficialCatalog() {
  const url = new URL(
    `https://firestore.googleapis.com/v1/projects/${projectId}`
      + "/databases/(default)/documents:runQuery",
  );
  url.searchParams.set("key", apiKeyMatch[1]);

  const response = await fetch(url, {
    method: "POST",
    headers: {"content-type": "application/json"},
    body: JSON.stringify({
      structuredQuery: {
        from: [{collectionId: "officialClinicCatalog"}],
        where: {
          fieldFilter: {
            field: {fieldPath: "datasetId"},
            op: "EQUAL",
            value: {stringValue: "tw-moa-vet-license-078"},
          },
        },
        limit: 100,
      },
    }),
  });
  if (!response.ok) {
    throw new Error(`officialClinicCatalog: HTTP ${response.status}`);
  }
  const rows = await response.json();
  return rows.flatMap((row) => row.document ? [row.document] : []);
}

async function assertAnonymousQueryDenied(collection) {
  const url = new URL(
    `https://firestore.googleapis.com/v1/projects/${projectId}`
      + "/databases/(default)/documents:runQuery",
  );
  url.searchParams.set("key", apiKeyMatch[1]);
  const response = await fetch(url, {
    method: "POST",
    headers: {"content-type": "application/json"},
    body: JSON.stringify({
      structuredQuery: {
        from: [{collectionId: collection}],
        limit: 1,
      },
    }),
  });
  if (response.status !== 403) {
    throw new Error(
      `${collection}: expected anonymous denial, received HTTP ${response.status}`,
    );
  }
}

function decodeValue(value) {
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
  throw new Error("Unsupported Firestore value in public audit");
}

function decodeDocument(document) {
  return {
    id: document.name.split("/").at(-1),
    ...Object.fromEntries(
      Object.entries(document.fields ?? {}).map(([key, value]) => [
        key,
        decodeValue(value),
      ]),
    ),
  };
}

for (const collection of ["clinics", "reviews", "quotes"]) {
  const documents = await listApproved(collection);

  console.log(JSON.stringify({
    collection,
    publiclyVisibleApproved: documents.length,
    documentIDs: documents
      .map((document) => document.name.split("/").at(-1))
      .slice(0, 20),
  }));
}

const officialDocuments = (await listOfficialCatalog()).map(decodeDocument);
const manifest = officialDocuments.find(
  (document) => document.id === "tw-moa-078-manifest",
);
if (
  !manifest
  || manifest.status !== "published"
  || manifest.licenseName !== "OGDL-Taiwan-1.0"
  || manifest.recordCount <= 0
  || manifest.shardCount <= 0
) {
  throw new Error("Official clinic catalog manifest is missing or invalid");
}

const officialRecords = [];
for (let index = 0; index < manifest.shardCount; index += 1) {
  const id =
    `tw-moa-078-${manifest.snapshotDate}-shard-`
    + String(index).padStart(3, "0");
  const shard = officialDocuments.find((document) => document.id === id);
  if (
    !shard
    || shard.kind !== "shard"
    || shard.index !== index
    || shard.snapshotDate !== manifest.snapshotDate
  ) {
    throw new Error(`Official clinic catalog shard ${index} is invalid`);
  }
  officialRecords.push(...shard.records);
}

const officialRecordIDs = new Set(officialRecords.map((record) => record.id));
if (
  officialRecords.length !== manifest.recordCount
  || officialRecordIDs.size !== manifest.recordCount
  || officialRecords.some((record) => "responsibleVeterinarian" in record)
) {
  throw new Error("Official clinic catalog record validation failed");
}

console.log(JSON.stringify({
  collection: "officialClinicCatalog",
  publiclyReadable: true,
  datasetId: manifest.datasetId,
  snapshotDate: manifest.snapshotDate,
  licenseName: manifest.licenseName,
  recordCount: officialRecords.length,
  shardCount: manifest.shardCount,
  responsibleVeterinarianExcluded: true,
}));

for (const collection of ["products", "insurances"]) {
  await assertAnonymousQueryDenied(collection);
  console.log(JSON.stringify({
    collection,
    anonymousReadDenied: true,
  }));
}
