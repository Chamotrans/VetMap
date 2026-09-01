import { readFile } from "node:fs/promises";
import {
  buildAvailabilityExpectation,
  parseAuditOptions,
  verifyApprovedClinicParity,
  verifyHKClinicAvailability,
  verifyNoAvailabilityOutsidePlan,
} from "./hk_clinic_availability_audit.mjs";

const options = parseAuditOptions(process.argv.slice(2));
const auditMode = options.auditMode;
const availabilityState = options.availabilityState;
const authoritativeInventoryChecked = auditMode === "full";
const projectId = "vetmap-app";
const demoClinicID = "vetmap-demo-clinic";
const demoClinicName = "VetMap 示範診所（非真實商戶）";
const accessToken = process.env.FIREBASE_ACCESS_TOKEN;
const plistURL = new URL("../VetMap/GoogleService-Info.plist", import.meta.url);
const plist = await readFile(plistURL, "utf8");
const clinicManifestURL = new URL(
  "../catalog/hk_clinics_v1.json",
  import.meta.url,
);
const clinicManifest = JSON.parse(await readFile(clinicManifestURL, "utf8"));
const clinicHoursManifestURL = new URL(
  "../catalog/hk_clinic_hours_v1.json",
  import.meta.url,
);
const clinicHoursManifest = JSON.parse(
  await readFile(clinicHoursManifestURL, "utf8"),
);
const pendingHoursManifest = JSON.parse(await readFile(
  new URL("../catalog/hk_clinic_hours_v2.pending.json", import.meta.url),
  "utf8",
));
const v3HoursManifest = JSON.parse(await readFile(
  new URL("../catalog/hk_clinic_hours_v3.pending.json", import.meta.url),
  "utf8",
));
const clinicReport = JSON.parse(await readFile(
  new URL("../catalog/hk_clinics_v1.report.json", import.meta.url),
  "utf8",
));
const availabilityExpectation = buildAvailabilityExpectation({
  catalog: clinicManifest,
  v1Hours: clinicHoursManifest,
  pending: pendingHoursManifest,
  v3Hours: v3HoursManifest,
  report: clinicReport,
  availabilityState,
});
const apiKeyMatch = plist.match(
  /<key>API_KEY<\/key>\s*<string>([^<]+)<\/string>/,
);

if (!apiKeyMatch) {
  throw new Error("GoogleService-Info.plist is missing API_KEY");
}
if (authoritativeInventoryChecked && !accessToken) {
  throw new Error(
    "Set FIREBASE_ACCESS_TOKEN so the audit can detect every potentially "
    + "public catalog document, including records with a different expiry.",
  );
}

console.log(JSON.stringify({
  auditMode,
  availabilityState,
  authoritativeInventoryChecked,
  ...(authoritativeInventoryChecked ? {} : {
    warning: "Public-only audit cannot detect documents hidden from anonymous queries, documents with a different expiry, or stray documents.",
  }),
}));

async function listAuthoritativeCollection(collection) {
  const documents = [];
  let pageToken = "";
  do {
    const url = new URL(
      `https://firestore.googleapis.com/v1/projects/${projectId}`
        + `/databases/(default)/documents/${collection}`,
    );
    url.searchParams.set("pageSize", "1000");
    if (pageToken) url.searchParams.set("pageToken", pageToken);
    const response = await fetch(url, {
      headers: {authorization: `Bearer ${accessToken}`},
    });
    if (!response.ok) {
      throw new Error(
        `${collection} authoritative inventory: HTTP ${response.status} `
        + `${await response.text()}`,
      );
    }
    const body = await response.json();
    documents.push(...(body.documents ?? []));
    pageToken = body.nextPageToken ?? "";
  } while (pageToken);
  return documents;
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

async function listCurrentHKCatalog(collection, catalogExpiry) {
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
          compositeFilter: {
            op: "AND",
            filters: [
              {
                fieldFilter: {
                  field: {fieldPath: "status"},
                  op: "EQUAL",
                  value: {stringValue: "approved"},
                },
              },
              {
                fieldFilter: {
                  field: {fieldPath: "catalogRegion"},
                  op: "EQUAL",
                  value: {stringValue: "HK"},
                },
              },
              {
                fieldFilter: {
                  field: {fieldPath: "region"},
                  op: "EQUAL",
                  value: {stringValue: "HK"},
                },
              },
              {
                fieldFilter: {
                  field: {fieldPath: "expiresAt"},
                  op: "EQUAL",
                  value: {timestampValue: catalogExpiry.toISOString()},
                },
              },
            ],
          },
        },
        limit: 300,
      },
    }),
  });
  if (!response.ok) {
    throw new Error(
      `${collection}: HTTP ${response.status} ${await response.text()}`,
    );
  }
  const rows = await response.json();
  return rows.flatMap((row) => row.document ? [row.document] : []);
}

async function getAnonymousDocument(collection, documentId) {
  const url = new URL(
    `https://firestore.googleapis.com/v1/projects/${projectId}`
      + `/databases/(default)/documents/${collection}/${documentId}`,
  );
  url.searchParams.set("key", apiKeyMatch[1]);
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(
      `${collection}/${documentId}: HTTP ${response.status} `
      + `${await response.text()}`,
    );
  }
  return response.json();
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

async function assertAnonymousDocumentDenied(collection, documentId) {
  const url = new URL(
    `https://firestore.googleapis.com/v1/projects/${projectId}`
      + `/databases/(default)/documents/${collection}/${documentId}`,
  );
  url.searchParams.set("key", apiKeyMatch[1]);
  const response = await fetch(url);
  if (response.status !== 403) {
    throw new Error(
      `${collection}/${documentId}: expected anonymous denial, `
      + `received HTTP ${response.status}`,
    );
  }
}

function decodeValue(value) {
  if ("nullValue" in value) return null;
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
  clinics: clinicManifest.count + 1,
  reviews: 1,
  quotes: 1,
};

let publicAvailabilitySummary;
let authenticatedAvailabilitySummary;
let authenticatedInertClinicExtras = [];

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
    verifyNoAvailabilityOutsidePlan(
      documents,
      availabilityExpectation,
      "public clinics",
    );
    const expectedClinicsByID = new Map(
      clinicManifest.clinics.map((clinic) => [clinic.id, clinic]),
    );
    const expectedClinicIDs = new Set(expectedClinicsByID.keys());
    const hkClinics = documents.filter(
      (document) =>
        document.catalogRegion === "HK"
        && document.migrationId === "hk-clinics-v2-2026-07-28",
    );
    const demoClinic = documents.find(({id}) => id === demoClinicID);
    const mappableClinics = hkClinics.filter(({coordinate}) => coordinate);
    if (
      hkClinics.length !== clinicManifest.count
      || mappableClinics.length
        !== clinicManifest.clinics.filter(({coordinate}) => coordinate).length
      || !documents.some(({id}) => id === demoClinicID)
      || demoClinic?.name !== demoClinicName
      || demoClinic?.status !== "approved"
      || Object.hasOwn(demoClinic ?? {}, "availability")
      || (demoClinic?.catalogRegion !== undefined && demoClinic.catalogRegion !== "demo")
      || (demoClinic?.region !== undefined && demoClinic.region !== "demo")
      || hkClinics.some(({id}) => !expectedClinicIDs.has(id))
      || hkClinics.some(
        (document) => {
          const expected = expectedClinicsByID.get(document.id);
          return !expected
          || document.name !== expected.name
          || document.address !== expected.address
          || document.phone !== expected.phone
          || document.district !== expected.district
          || JSON.stringify(document.sourceRecordIDs)
            !== JSON.stringify(expected.sourceRecordIDs)
          || document.verified !== false
          || document.region !== "HK"
          || document.sourceName
            !== "VetMap authorized Hong Kong clinic database"
          || document.rightsBasis
            !== "Owner confirmed database was created in-house or licensed for use"
          || Number.isNaN(new Date(document.rightsConfirmedAt).getTime())
          || Number.isNaN(new Date(document.verifiedAt).getTime())
          || new Date(document.expiresAt) <= new Date()
          || document.avgRating !== 0
          || document.reviewCount !== 0
          || document.priceLevel !== 0
          || Object.keys(document.openingHours ?? {}).length !== 0
          || (document.services ?? []).length !== 0
          || (document.tags ?? []).length !== 0
          || (document.coordinate != null && (
            document.coordinate.latitude < 22.1
            || document.coordinate.latitude > 22.6
            || document.coordinate.longitude < 113.8
            || document.coordinate.longitude > 114.5
            || typeof document.coordinateSource !== "string"
            || document.coordinateMatchScore < 75
          ))
          || /(中國|中国|內地|内地|台灣|臺灣|台湾|Taiwan|Taipei|深圳|廣州|广州|澳門|澳门|Macau|Macao)/iu
            .test(document.address);
        },
      )
    ) {
      throw new Error("The public Hong Kong clinic catalog is not normalized.");
    }
    const uniqueSourceRecordIDs = new Set(
      hkClinics.flatMap(({sourceRecordIDs}) => sourceRecordIDs ?? []),
    );
    if (uniqueSourceRecordIDs.size !== 205) {
      throw new Error(
        "The public Hong Kong clinic catalog does not cover all 205 "
        + `authorized source records; found ${uniqueSourceRecordIDs.size}.`,
      );
    }
    publicAvailabilitySummary = verifyHKClinicAvailability(
      hkClinics,
      availabilityExpectation,
      "public clinics",
    );

    if (authoritativeInventoryChecked) {
      const authoritativeClinicInventory = (
        await listAuthoritativeCollection("clinics")
      ).map(decodeDocument);
      authenticatedInertClinicExtras = authoritativeClinicInventory.filter(
        (document) => !expectedClinicIDs.has(document.id)
          && document.id !== demoClinicID,
      );
      for (const document of authenticatedInertClinicExtras) {
        if (
          Object.hasOwn(document, "availability")
          || document.status === "approved"
          || document.catalogRegion === "HK"
          || document.region === "HK"
        ) {
          throw new Error(
            `authenticated clinic inventory: inert extra is unsafe at ${document.id}.`,
          );
        }
      }
      verifyNoAvailabilityOutsidePlan(
        authoritativeClinicInventory,
        availabilityExpectation,
        "authenticated clinic inventory",
      );
      const authoritativeApprovedClinics = authoritativeClinicInventory
        .filter(({status}) => status === "approved");
      verifyApprovedClinicParity(
        documents,
        authoritativeApprovedClinics,
        availabilityExpectation,
      );
      const authoritativeHKClinics = authoritativeApprovedClinics.filter(
        ({id}) => availabilityExpectation.catalogIDs.has(id),
      );
      authenticatedAvailabilitySummary = verifyHKClinicAvailability(
        authoritativeHKClinics,
        availabilityExpectation,
        "authenticated clinics",
      );
    }
    console.log(JSON.stringify({
      collection: "clinics",
      authorizedCatalogEntries: hkClinics.length,
      demoEntries: documents.length - hkClinics.length,
      authenticatedInertNonPublicEntries: authenticatedInertClinicExtras.length,
      mappableEntries: mappableClinics.length,
      listOnlyEntries: hkClinics.length - mappableClinics.length,
      uniqueAuthorizedSourceRecords: uniqueSourceRecordIDs.size,
      availabilityEntries: publicAvailabilitySummary.total,
      twentyFourHourEntries: publicAvailabilitySummary.twentyFourHours,
      scheduledEntries: publicAvailabilitySummary.scheduled,
    }));
  }
}

const catalogExpectations = {
  products: 124,
  insurances: 3,
};
const expiryFloor = new Date(Date.now() + 60 * 1000);
const bootstrapInsurance = decodeDocument(
  await getAnonymousDocument("insurances", "insurance-hk-fwd"),
);
const catalogExpiry = new Date(bootstrapInsurance.expiresAt ?? "");
if (
  Number.isNaN(catalogExpiry.getTime())
  || catalogExpiry <= expiryFloor
) {
  throw new Error(
    "insurances/insurance-hk-fwd: missing a safe shared catalog expiry.",
  );
}
const migrationId = "hk-commercial-v1-2026-07-28";
const commonCatalogFields = [
  "status",
  "region",
  "catalogRegion",
  "sourceName",
  "sourceURL",
  "rightsBasis",
  "verifiedAt",
  "expiresAt",
  "migrationId",
];
const prohibitedProductFields = [
  "rating",
  "avgRating",
  "reviewCount",
  "hours",
  "openingHours",
  "priceRange",
];
const catalogAuditTime = new Date();

for (const [collection, expectedCount] of Object.entries(catalogExpectations)) {
  const rawDocuments = await listCurrentHKCatalog(collection, catalogExpiry);
  const documents = rawDocuments.map(decodeDocument);
  if (documents.length !== expectedCount) {
    throw new Error(
      `${collection}: expected ${expectedCount} current approved HK documents, `
      + `found ${documents.length}`,
    );
  }
  if (authoritativeInventoryChecked) {
    const authoritativePublicDocuments = (
      await listAuthoritativeCollection(collection)
    )
      .map(decodeDocument)
      .filter((document) => {
        const expiresAt = new Date(document.expiresAt ?? "");
        return document.status === "approved"
          && document.catalogRegion === "HK"
          && document.region === "HK"
          && !Number.isNaN(expiresAt.getTime())
          && expiresAt > catalogAuditTime;
      });
    const anonymousIDs = documents.map(({id}) => id).sort();
    const authoritativePublicIDs = authoritativePublicDocuments
      .map(({id}) => id)
      .sort();
    if (
      authoritativePublicDocuments.length !== expectedCount
      || JSON.stringify(authoritativePublicIDs) !== JSON.stringify(anonymousIDs)
    ) {
      throw new Error(
        `${collection}: anonymous exact-expiry results do not cover every `
        + `rule-public document; anonymous=${JSON.stringify(anonymousIDs)}, `
        + `authoritative=${JSON.stringify(authoritativePublicIDs)}`,
      );
    }
  }
  for (const document of documents) {
    for (const field of commonCatalogFields) {
      if (!(field in document)) {
        throw new Error(`${collection}/${document.id}: missing ${field}.`);
      }
    }
    const verifiedAt = new Date(document.verifiedAt);
    const expiresAt = new Date(document.expiresAt);
    if (
      document.status !== "approved"
      || document.catalogRegion !== "HK"
      || document.region !== "HK"
      || document.migrationId !== migrationId
      || typeof document.sourceName !== "string"
      || document.sourceName.trim() === ""
      || typeof document.sourceURL !== "string"
      || !document.sourceURL.startsWith("https://")
      || typeof document.rightsBasis !== "string"
      || document.rightsBasis.trim() === ""
      || Number.isNaN(verifiedAt.getTime())
      || Number.isNaN(expiresAt.getTime())
      || expiresAt.getTime() !== catalogExpiry.getTime()
    ) {
      throw new Error(
        `${collection}/${document.id}: invalid publication metadata.`,
      );
    }
  }

  if (collection === "products") {
    const requiredProductFields = [
      "id",
      "name",
      "description",
      "category",
      "price",
      "currency",
      "clinicId",
      "affiliateURL",
      "imageURL",
      "tags",
      "createdAt",
      "address",
      "district",
      "contactPhone",
      "sourceRecordId",
      "hasPublishedPrice",
    ];
    for (const document of documents) {
      for (const field of requiredProductFields) {
        if (!(field in document)) {
          throw new Error(`products/${document.id}: missing ${field}.`);
        }
      }
      if (
        document.id !== `hk-service-${document.sourceRecordId}`
        || document.price !== 0
        || document.hasPublishedPrice !== false
        || document.currency !== "HKD"
        || document.clinicId !== null
        || document.affiliateURL !== null
        || document.imageURL !== null
        || !Array.isArray(document.tags)
        || document.tags.length !== 0
        || document.rightsBasis
          !== "existing VetMap operator-supplied catalog"
        || prohibitedProductFields.some((field) => field in document)
        || /(中國|中国|內地|内地|台灣|臺灣|台湾|Taiwan|Taipei|深圳|廣州|广州|澳門|澳门|Macau|Macao)/iu
          .test(document.address)
      ) {
        throw new Error(`products/${document.id}: unsafe service catalog data.`);
      }
    }
    const categoryCounts = Object.fromEntries(
      ["用品", "美容", "善終"].map((category) => [
        category,
        documents.filter((document) => document.category === category).length,
      ]),
    );
    if (
      categoryCounts["用品"] !== 50
      || categoryCounts["美容"] !== 50
      || categoryCounts["善終"] !== 24
    ) {
      throw new Error(
        `products: unexpected category counts ${JSON.stringify(categoryCounts)}`,
      );
    }
  } else {
    const expectedInsuranceDirectory = new Map([
      [
        "insurance-hk-fwd",
        {
          providerName: "FWD",
          planName: "毛孩寵物保",
          website: "https://www.fwd.com.hk/online-insurance/pets-insurance/",
        },
      ],
      [
        "insurance-hk-onedegree",
        {
          providerName: "OneDegree",
          planName: "寵物CEO Plan®",
          website: "https://www.onedegree.hk/zh-hk/dog-insurance",
        },
      ],
      [
        "insurance-hk-bluecross",
        {
          providerName: "Blue Cross",
          planName: "愛・寵物",
          website:
            "https://ap.bluecross.com.hk/shared/leaflets/LovePet_Leaflet.pdf",
        },
      ],
    ]);
    for (const document of documents) {
      const expected = expectedInsuranceDirectory.get(document.id);
      if (
        !expected
        || document.providerName !== expected.providerName
        || document.planName !== expected.planName
        || document.website !== expected.website
        || document.sourceURL !== expected.website
        || document.monthlyPremium !== 0
        || document.annualPremium !== 0
        || !Array.isArray(document.coverage)
        || document.coverage.length !== 0
        || !Array.isArray(document.exclusions)
        || document.exclusions.length !== 0
        || document.contactPhone !== ""
        || document.rightsBasis !== "official provider website"
      ) {
        throw new Error(
          `insurances/${document.id}: unsafe or unexpected directory data.`,
        );
      }
    }
  }

  console.log(JSON.stringify({
    collection,
    publiclyVisibleApprovedHK: documents.length,
    documentIDs: documents.map(({id}) => id).sort().slice(0, 20),
  }));
}

for (const collection of ["officialClinicCatalog", "products", "insurances"]) {
  await assertAnonymousQueryDenied(collection);
  console.log(JSON.stringify({
    collection,
    anonymousReadDenied: true,
  }));
}

for (const [collection, documentId] of [
  ["products", "product-fish-oil"],
  ["insurances", "insurance-tw-cathay-c"],
]) {
  await assertAnonymousDocumentDenied(collection, documentId);
  console.log(JSON.stringify({
    collection,
    documentId,
    anonymousLegacyReadDenied: true,
  }));
}

console.log(JSON.stringify({
  auditMode,
  availabilityState,
  authoritativeInventoryChecked,
  availabilityStateVerified: true,
  publicAvailability: publicAvailabilitySummary,
  ...(authenticatedAvailabilitySummary
    ? {authenticatedAvailability: authenticatedAvailabilitySummary}
    : {}),
}));
