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
  if ("geoPointValue" in value) return value.geoPointValue;
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

const expectedApprovedCounts = {
  clinics: 11,
  reviews: 1,
  quotes: 1,
};

for (const [collection, expectedCount] of Object.entries(expectedApprovedCounts)) {
  const rawDocuments = await listApproved(collection);
  const documents = rawDocuments.map(decodeDocument);
  if (documents.length !== expectedCount) {
    throw new Error(
      `${collection}: expected ${expectedCount} approved documents, `
      + `found ${documents.length}`,
    );
  }
  console.log(JSON.stringify({
    collection,
    publiclyVisibleApproved: documents.length,
    documentIDs: documents.map(({id}) => id).slice(0, 20),
  }));
  if (collection === "clinics") {
    const hkClinics = documents.filter(
      (document) =>
        document.catalogRegion === "HK"
        && document.migrationId === "hk-v1-normalize-2026-07-24",
    );
    if (
      hkClinics.length !== 10
      || hkClinics.some(
        (document) =>
          document.verified !== false
          || document.avgRating !== 0
          || document.reviewCount !== 0
          || document.priceLevel !== 0
          || (document.services ?? []).length !== 0
          || (document.tags ?? []).length !== 0,
      )
    ) {
      throw new Error("The public Hong Kong clinic catalog is not normalized.");
    }
  }
}

for (const collection of ["officialClinicCatalog", "products", "insurances"]) {
  await assertAnonymousQueryDenied(collection);
  console.log(JSON.stringify({
    collection,
    anonymousReadDenied: true,
  }));
}
