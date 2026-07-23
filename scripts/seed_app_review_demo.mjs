#!/usr/bin/env node

import {execFileSync} from "node:child_process";
import {resolve} from "node:path";

const repoRoot = resolve(import.meta.dirname, "..");
const firebasePlist = resolve(repoRoot, "VetMap", "GoogleService-Info.plist");

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

const apiKey = plistValue("API_KEY");
const projectId = plistValue("PROJECT_ID");
const adminEmail = "appreview-admin@vetmap.app";
const fixtureEmail = "appreview-fixture@vetmap.app";

async function requestJson(url, options = {}, allowedStatuses = [200]) {
  const response = await fetch(url, options);
  const body = await response.json().catch(() => ({}));
  if (!allowedStatuses.includes(response.status)) {
    const message =
      body?.error?.message ??
      body?.error?.status ??
      `HTTP ${response.status}`;
    throw new Error(message);
  }
  return {status: response.status, body};
}

async function signIn(email, password) {
  const {body} = await requestJson(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${encodeURIComponent(apiKey)}`,
    {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({email, password, returnSecureToken: true}),
    },
  );

  if (!body.idToken || !body.localId) {
    throw new Error(`Firebase sign-in did not return an identity for ${email}`);
  }
  return {idToken: body.idToken, uid: body.localId};
}

const adminIdentity = await signIn(
  adminEmail,
  keychainPassword("VetMap App Review Admin", adminEmail),
);
const fixtureIdentity = await signIn(
  fixtureEmail,
  keychainPassword("VetMap App Review Fixture", fixtureEmail),
);

const firestoreBase =
  `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}` +
  "/databases/(default)/documents";

function documentUrl(collection, id) {
  return `${firestoreBase}/${encodeURIComponent(collection)}/${encodeURIComponent(id)}`;
}

function authHeaders() {
  return {
    authorization: `Bearer ${adminIdentity.idToken}`,
    "content-type": "application/json",
  };
}

async function readDocument(collection, id, authenticated = true) {
  return requestJson(
    documentUrl(collection, id),
    {headers: authenticated ? authHeaders() : undefined},
    [200, 404],
  );
}

const adminProfile = await readDocument("users", adminIdentity.uid);
if (
  adminProfile.status !== 200 ||
  adminProfile.body?.fields?.role?.stringValue !== "admin"
) {
  throw new Error("The dedicated App Review admin account is not an admin");
}

const stringValue = (value) => ({stringValue: value});
const boolValue = (value) => ({booleanValue: value});
const integerValue = (value) => ({integerValue: String(value)});
const doubleValue = (value) => ({doubleValue: value});
const timestampValue = (value) => ({timestampValue: value});
const arrayValue = (values) => ({
  arrayValue: {values: values.map(stringValue)},
});
const mapValue = (fields) => ({mapValue: {fields}});

const now = new Date().toISOString();
const clinicId = "vetmap-demo-clinic";
const reviewId = "vetmap-demo-review";
const quoteId = "vetmap-demo-quote";

const documents = [
  {
    collection: "clinics",
    id: clinicId,
    fields: {
      id: stringValue(clinicId),
      name: stringValue("VetMap 示範診所（非真實商戶）"),
      address: stringValue("只供 App Review 功能示範，並非真實診所地址"),
      coordinate: mapValue({
        latitude: doubleValue(22.3193),
        longitude: doubleValue(114.1694),
      }),
      phone: stringValue(""),
      website: stringValue("https://vetmap-app.web.app/support"),
      openingHours: mapValue({}),
      services: arrayValue(["功能示範"]),
      avgRating: doubleValue(3),
      reviewCount: integerValue(1),
      priceLevel: integerValue(1),
      images: arrayValue([]),
      tags: arrayValue(["非真實商戶", "App Review 示範"]),
      createdAt: timestampValue(now),
      updatedAt: timestampValue(now),
      reportedBy: stringValue(fixtureIdentity.uid),
      verified: boolValue(true),
      authorId: stringValue(fixtureIdentity.uid),
      status: stringValue("approved"),
      approvedAt: timestampValue(now),
    },
  },
  {
    collection: "reviews",
    id: reviewId,
    fields: {
      id: stringValue(reviewId),
      clinicId: stringValue(clinicId),
      userId: stringValue(fixtureIdentity.uid),
      userName: stringValue("VetMap 示範用戶"),
      rating: integerValue(3),
      title: stringValue("功能示範（非真實評價）"),
      content: stringValue(
        "此為 VetMap 功能示範內容，並非真實診所評價或醫療經歷。",
      ),
      treatmentType: stringValue("功能示範"),
      images: arrayValue([]),
      createdAt: timestampValue(now),
      updatedAt: timestampValue(now),
      helpfulCount: integerValue(0),
      authorId: stringValue(fixtureIdentity.uid),
      status: stringValue("approved"),
      approvedAt: timestampValue(now),
    },
  },
  {
    collection: "quotes",
    id: quoteId,
    fields: {
      id: stringValue(quoteId),
      clinicId: stringValue(clinicId),
      userId: stringValue(fixtureIdentity.uid),
      treatmentType: stringValue("功能示範"),
      estimatedCost: integerValue(1),
      actualCost: integerValue(1),
      currency: stringValue("HKD"),
      notes: stringValue("此為功能示範，並非真實醫療報價。"),
      createdAt: timestampValue(now),
      authorId: stringValue(fixtureIdentity.uid),
      status: stringValue("approved"),
      approvedAt: timestampValue(now),
    },
  },
];

const outcomes = [];
for (const document of documents) {
  const current = await readDocument(document.collection, document.id);
  if (current.status === 200) {
    const currentStatus = current.body?.fields?.status?.stringValue;
    const currentAuthor = current.body?.fields?.authorId?.stringValue;
    if (
      currentStatus !== "approved" ||
      currentAuthor !== fixtureIdentity.uid
    ) {
      throw new Error(
        `${document.collection}/${document.id} exists with unexpected ownership or status`,
      );
    }
    outcomes.push({path: `${document.collection}/${document.id}`, result: "existing"});
    continue;
  }

  await requestJson(documentUrl(document.collection, document.id), {
    method: "PATCH",
    headers: authHeaders(),
    body: JSON.stringify({fields: document.fields}),
  });
  outcomes.push({path: `${document.collection}/${document.id}`, result: "created"});
}

for (const document of documents) {
  const publicResult = await readDocument(
    document.collection,
    document.id,
    false,
  );
  if (
    publicResult.status !== 200 ||
    publicResult.body?.fields?.status?.stringValue !== "approved"
  ) {
    throw new Error(`${document.collection}/${document.id} is not publicly readable`);
  }
}

console.log(JSON.stringify({
  adminVerified: true,
  fixtureAuthorVerified: true,
  publicReadVerified: true,
  documents: outcomes,
}, null, 2));
