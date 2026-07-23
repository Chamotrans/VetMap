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
