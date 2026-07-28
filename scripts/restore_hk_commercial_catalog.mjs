import {createHash} from "node:crypto";
import {
  chmod,
  mkdir,
  readFile,
  stat,
  writeFile,
} from "node:fs/promises";
import path from "node:path";

const PROJECT_ID = "vetmap-app";
const DATABASE_ID = "(default)";
const FIRESTORE_ROOT =
  `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}`
  + `/databases/${DATABASE_ID}/documents`;
const MIGRATION_ID = "hk-commercial-v1-2026-07-28";
const SOURCE_PATH = new URL(
  "../data_sources/petcircle_businesses.json",
  import.meta.url,
);
const SERVICE_SOURCE_NAME =
  "VetMap operator-supplied Pet Circle business catalog";
const SERVICE_SOURCE_URL = "https://vetmap-app.web.app";
const SERVICE_RIGHTS_BASIS = "existing VetMap operator-supplied catalog";
const INSURANCE_RIGHTS_BASIS = "official provider website";
const EXPIRY_DAYS = 90;
const ACCESS_TOKEN = process.env.FIREBASE_ACCESS_TOKEN;
const backupTimestamp = new Date()
  .toISOString()
  .replaceAll(":", "-")
  .replace(/\.\d{3}Z$/, "Z");
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
const BACKUP_PATH =
  backupPathArgument
    ?? `build/backups/firestore-before-${MIGRATION_ID}-${backupTimestamp}.json`;

if (!ACCESS_TOKEN) {
  throw new Error(
    "Set FIREBASE_ACCESS_TOKEN to a current Firebase/Google OAuth access token.",
  );
}

const CATEGORY_CONFIG = Object.freeze({
  supplies: Object.freeze({
    count: 50,
    category: "用品",
  }),
  grooming: Object.freeze({
    count: 50,
    category: "美容",
  }),
  funeral: Object.freeze({
    count: 24,
    category: "善終",
  }),
});

const INSURANCE_DIRECTORY = Object.freeze([
  Object.freeze({
    id: "insurance-hk-fwd",
    providerName: "FWD",
    planName: "毛孩寵物保",
    description:
      "香港寵物保險官方產品目錄；此計劃由 bolttech 承保。"
      + "保障、保費、投保資格及條款請以官方網站最新資料為準。",
    website: "https://www.fwd.com.hk/online-insurance/pets-insurance/",
    sourceName: "FWD official provider website",
  }),
  Object.freeze({
    id: "insurance-hk-onedegree",
    providerName: "OneDegree",
    planName: "寵物CEO Plan®",
    description:
      "香港寵物保險官方產品目錄。"
      + "保障、保費、投保資格及條款請以官方網站最新資料為準。",
    website: "https://www.onedegree.hk/zh-hk/dog-insurance",
    sourceName: "OneDegree official provider website",
  }),
  Object.freeze({
    id: "insurance-hk-bluecross",
    providerName: "Blue Cross",
    planName: "愛・寵物",
    description:
      "香港寵物保險官方產品目錄。"
      + "保障、保費、投保資格及條款請以官方產品單張最新資料為準。",
    website:
      "https://ap.bluecross.com.hk/shared/leaflets/LovePet_Leaflet.pdf",
    sourceName: "Blue Cross official product brochure",
  }),
]);

const PROHIBITED_ADDRESS_MARKERS =
  /(中國|中国|內地|内地|大陸|大陆|台灣|臺灣|台湾|Taiwan|Taipei|台北|臺北|深圳|Shenzhen|廣州|广州|Guangzhou|東莞|东莞|Dongguan|珠海|Zhuhai|佛山|Foshan|惠州|Huizhou|澳門|澳门|Macau|Macao)/iu;
const HK_ADDRESS_MARKERS =
  /(香港|Hong Kong|HK\b|九龍|九龙|Kowloon|新界|New Territories|中環|Central|灣仔|Wan Chai|銅鑼灣|Causeway Bay|北角|North Point|西營盤|Sai Ying Pun|上環|Sheung Wan|觀塘|Kwun Tong|旺角|Mong Kok|深水埗|Sham Shui Po|荃灣|Tsuen Wan|屯門|Tuen Mun|元朗|Yuen Long|沙田|Sha Tin|葵涌|Kwai Chung|粉嶺|Fanling|火炭|Fo Tan|紅磡|Hung Hom|筲箕灣|Shau Kei Wan|鴨脷洲|Ap Lei Chau|荔枝角|Lai Chi Kok|大角咀|Tai Kok Tsui|黃竹坑|Wong Chuk Hang|跑馬地|Happy Valley|堅尼地城|Kennedy Town|油麻地|Yau Ma Tei|九龍城|Kowloon City|新蒲崗|San Po Kong|黃大仙|Wong Tai Sin|長沙灣|Cheung Sha Wan|土瓜灣|To Kwa Wan|葵青|離島|西貢|大埔|東區|南區|中西區|灣仔區|油尖旺區|觀塘區|深水埗區|九龍城區|黃大仙區|葵青區|荃灣區|屯門區|元朗區|北區|沙田區|大埔區|西貢區)/iu;
const PROHIBITED_SERVICE_FIELDS = new Set([
  "rating",
  "avgRating",
  "reviewCount",
  "hours",
  "openingHours",
  "priceRange",
]);

function authHeaders(extra = {}) {
  return {
    authorization: `Bearer ${ACCESS_TOKEN}`,
    ...extra,
  };
}

function cleanText(value, fieldName, maximumLength) {
  if (typeof value !== "string") {
    throw new Error(`${fieldName}: expected a string.`);
  }
  const unescaped = value.replace(
    /\\u([0-9a-fA-F]{4})/gu,
    (_, hexadecimal) => String.fromCodePoint(Number.parseInt(hexadecimal, 16)),
  );
  const normalized = unescaped
    .normalize("NFC")
    .replace(/[\u0000-\u001F\u007F]/gu, " ")
    .replace(/\s+/gu, " ")
    .trim();
  if (!normalized) {
    throw new Error(`${fieldName}: value is empty after sanitization.`);
  }
  if (normalized.length > maximumLength) {
    throw new Error(
      `${fieldName}: ${normalized.length} characters exceeds ${maximumLength}.`,
    );
  }
  return normalized;
}

function cleanOptionalText(value, fieldName, maximumLength) {
  if (value == null || value === "") return "";
  return cleanText(value, fieldName, maximumLength);
}

function assertHKAddress(address, sourceId) {
  if (PROHIBITED_ADDRESS_MARKERS.test(address)) {
    throw new Error(`${sourceId}: rejected non-Hong Kong address: ${address}`);
  }
  if (!HK_ADDRESS_MARKERS.test(address)) {
    throw new Error(`${sourceId}: address has no Hong Kong locality marker.`);
  }
}

function isRejectedAddress(record) {
  return typeof record?.address !== "string"
    || PROHIBITED_ADDRESS_MARKERS.test(record.address);
}

function selectServiceRecords(sourceCatalog) {
  const selected = [];
  const rejectedByCategory = {};

  for (const [sourceCategory, config] of Object.entries(CATEGORY_CONFIG)) {
    const records = sourceCatalog[sourceCategory];
    if (!Array.isArray(records)) {
      throw new Error(`Source catalog is missing ${sourceCategory}.`);
    }

    const rejected = records.filter(isRejectedAddress);
    const candidates = records
      .filter((record) => !isRejectedAddress(record))
      .toSorted((left, right) =>
        String(left.id ?? "").localeCompare(
          String(right.id ?? ""),
          "en",
          {numeric: true},
        ),
      );
    rejectedByCategory[sourceCategory] = rejected.length;

    if (candidates.length < config.count) {
      throw new Error(
        `${sourceCategory}: expected at least ${config.count} safe records, `
        + `found ${candidates.length}.`,
      );
    }

    for (const record of candidates.slice(0, config.count)) {
      const sourceId = cleanText(
        record.id,
        `${sourceCategory}.id`,
        100,
      );
      if (!/^[a-z]{3}-\d{3}$/u.test(sourceId)) {
        throw new Error(`${sourceId}: unexpected source ID format.`);
      }
      const name = cleanText(record.name, `${sourceId}.name`, 200);
      const address = cleanText(record.address, `${sourceId}.address`, 500);
      const district = cleanOptionalText(
        record.district,
        `${sourceId}.district`,
        100,
      );
      const contactPhone = cleanOptionalText(
        record.phone,
        `${sourceId}.phone`,
        50,
      );
      assertHKAddress(address, sourceId);
      if (
        contactPhone
        && !/^[+()\d\s-]+$/u.test(contactPhone)
      ) {
        throw new Error(`${sourceId}: phone contains unexpected characters.`);
      }

      selected.push({
        sourceId,
        name,
        address,
        district,
        contactPhone,
        category: config.category,
      });
    }
  }

  const expectedTotal = Object.values(CATEGORY_CONFIG)
    .reduce((total, config) => total + config.count, 0);
  if (selected.length !== expectedTotal) {
    throw new Error(
      `Expected exactly ${expectedTotal} selected services, `
      + `found ${selected.length}.`,
    );
  }
  const uniqueSourceIDs = new Set(selected.map(({sourceId}) => sourceId));
  if (uniqueSourceIDs.size !== selected.length) {
    throw new Error("Selected service source IDs are not unique.");
  }

  return {selected, rejectedByCategory};
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
  throw new Error("Unsupported Firestore value in catalog migration.");
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

function encodeValue(value) {
  if (value === null) return {nullValue: null};
  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) {
      throw new Error("Cannot encode an invalid timestamp.");
    }
    return {timestampValue: value.toISOString()};
  }
  if (typeof value === "string") return {stringValue: value};
  if (typeof value === "boolean") return {booleanValue: value};
  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      throw new Error("Cannot encode a non-finite number.");
    }
    return Number.isInteger(value)
      ? {integerValue: String(value)}
      : {doubleValue: value};
  }
  if (Array.isArray(value)) {
    return {arrayValue: {values: value.map(encodeValue)}};
  }
  if (typeof value === "object") {
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(value).map(([key, child]) => [
            key,
            encodeValue(child),
          ]),
        ),
      },
    };
  }
  throw new Error(`Unsupported value type: ${typeof value}`);
}

function encodeFields(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, encodeValue(value)]),
  );
}

function existingTimestamp(existingDocument, fieldName, fallback) {
  const value = existingDocument?.fields?.[fieldName];
  if (typeof value !== "string") return fallback;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? fallback : parsed;
}

function catalogMetadata({
  sourceName,
  sourceURL,
  rightsBasis,
  verifiedAt,
  expiresAt,
}) {
  return {
    status: "approved",
    region: "HK",
    catalogRegion: "HK",
    sourceName,
    sourceURL,
    rightsBasis,
    verifiedAt,
    expiresAt,
    migrationId: MIGRATION_ID,
  };
}

function buildServiceDocument(record, existingDocument, verifiedAt, expiresAt) {
  const id = `hk-service-${record.sourceId}`;
  if (
    existingDocument
    && existingDocument.fields.migrationId !== MIGRATION_ID
  ) {
    throw new Error(
      `${id}: refusing to overwrite a document not owned by ${MIGRATION_ID}.`,
    );
  }
  const createdAt = existingTimestamp(
    existingDocument,
    "createdAt",
    verifiedAt,
  );

  return {
    id,
    name: record.name,
    description:
      `${record.category}商戶目錄：${record.name}，地址：${record.address}。`
      + "資料只供目錄參考；服務及聯絡詳情請直接向商戶確認。",
    category: record.category,
    price: 0,
    currency: "HKD",
    clinicId: null,
    affiliateURL: null,
    imageURL: null,
    tags: [],
    createdAt,
    address: record.address,
    district: record.district,
    contactPhone: record.contactPhone,
    sourceRecordId: record.sourceId,
    hasPublishedPrice: false,
    ...catalogMetadata({
      sourceName: SERVICE_SOURCE_NAME,
      sourceURL: SERVICE_SOURCE_URL,
      rightsBasis: SERVICE_RIGHTS_BASIS,
      verifiedAt,
      expiresAt,
    }),
  };
}

function buildInsuranceDocument(entry, verifiedAt, expiresAt) {
  return {
    id: entry.id,
    providerName: entry.providerName,
    planName: entry.planName,
    description: entry.description,
    monthlyPremium: 0,
    annualPremium: 0,
    coverage: [],
    exclusions: [],
    website: entry.website,
    contactPhone: "",
    ...catalogMetadata({
      sourceName: entry.sourceName,
      sourceURL: entry.website,
      rightsBasis: INSURANCE_RIGHTS_BASIS,
      verifiedAt,
      expiresAt,
    }),
  };
}

function assertSanitizedServiceDocument(document) {
  const requiredModelFields = [
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
  ];
  for (const field of requiredModelFields) {
    if (!(field in document)) {
      throw new Error(`${document.id}: missing PetProduct field ${field}.`);
    }
  }
  for (const field of PROHIBITED_SERVICE_FIELDS) {
    if (field in document) {
      throw new Error(`${document.id}: prohibited claim field ${field}.`);
    }
  }
  if (
    document.price !== 0
    || document.currency !== "HKD"
    || document.clinicId !== null
    || document.affiliateURL !== null
    || document.imageURL !== null
    || document.tags.length !== 0
    || document.hasPublishedPrice !== false
  ) {
    throw new Error(`${document.id}: unsafe commercial product values.`);
  }
  assertHKAddress(document.address, document.id);
}

function assertNormalizedInsuranceDocument(document) {
  const requiredModelFields = [
    "id",
    "providerName",
    "planName",
    "description",
    "monthlyPremium",
    "annualPremium",
    "coverage",
    "exclusions",
    "website",
    "contactPhone",
  ];
  for (const field of requiredModelFields) {
    if (!(field in document)) {
      throw new Error(`${document.id}: missing Insurance field ${field}.`);
    }
  }
  if (
    document.monthlyPremium !== 0
    || document.annualPremium !== 0
    || document.coverage.length !== 0
    || document.exclusions.length !== 0
    || document.contactPhone !== ""
    || document.sourceURL !== document.website
  ) {
    throw new Error(`${document.id}: insurance claims were not cleared.`);
  }
}

async function createBackup(rawCollections) {
  const backup = {
    projectId: PROJECT_ID,
    databaseId: DATABASE_ID,
    exportedAt: new Date().toISOString(),
    migrationId: MIGRATION_ID,
    collections: rawCollections,
  };
  const serialized = `${JSON.stringify(backup, null, 2)}\n`;
  await mkdir(path.dirname(BACKUP_PATH), {recursive: true});
  await writeFile(BACKUP_PATH, serialized, {
    encoding: "utf8",
    flag: "wx",
    mode: 0o600,
  });
  await chmod(BACKUP_PATH, 0o600);
  const backupMode = (await stat(BACKUP_PATH)).mode & 0o777;
  if (backupMode !== 0o600) {
    throw new Error(
      `${BACKUP_PATH}: expected mode 0600, found ${backupMode.toString(8)}.`,
    );
  }
  return {
    backupPath: BACKUP_PATH,
    backupSHA256: createHash("sha256").update(serialized).digest("hex"),
  };
}

function updateWrite(collection, id, data, existingDocument) {
  const desiredFields = encodeFields(data);
  const fieldPaths = new Set(Object.keys(desiredFields));
  for (const fieldPath of Object.keys(existingDocument?.raw?.fields ?? {})) {
    fieldPaths.add(fieldPath);
  }
  const write = {
    update: {
      name:
        `projects/${PROJECT_ID}/databases/${DATABASE_ID}`
        + `/documents/${collection}/${id}`,
      fields: desiredFields,
    },
    updateMask: {
      fieldPaths: [...fieldPaths].sort(),
    },
    currentDocument: existingDocument
      ? {updateTime: existingDocument.updateTime}
      : {exists: false},
  };
  return write;
}

async function commitWrites(writes) {
  if (writes.length !== 127) {
    throw new Error(`Expected exactly 127 writes, found ${writes.length}.`);
  }
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}`
      + `/databases/${DATABASE_ID}/documents:commit`,
    {
      method: "POST",
      headers: authHeaders({"content-type": "application/json"}),
      body: JSON.stringify({writes}),
    },
  );
  if (!response.ok) {
    throw new Error(
      `Commit: HTTP ${response.status} ${await response.text()}`,
    );
  }
  const body = await response.json();
  if ((body.writeResults ?? []).length !== writes.length) {
    throw new Error(
      `Commit returned ${body.writeResults?.length ?? 0} write results.`,
    );
  }
  return body.commitTime;
}

function isCurrentPublicHKDocument(document, now) {
  const expiry = new Date(document.fields.expiresAt ?? "");
  return document.fields.status === "approved"
    && document.fields.catalogRegion === "HK"
    && !Number.isNaN(expiry.getTime())
    && expiry > now;
}

function verifyLegacyDocumentsPreserved({
  before,
  after,
  migrationTargetIDs,
  collection,
}) {
  const afterIDs = new Set(after.map(({id}) => id));
  const missing = before
    .map(({id}) => id)
    .filter((id) => !migrationTargetIDs.has(id) && !afterIDs.has(id));
  if (missing.length > 0) {
    throw new Error(
      `${collection}: legacy documents disappeared: ${missing.join(", ")}`,
    );
  }
}

const sourceCatalog = JSON.parse(await readFile(SOURCE_PATH, "utf8"));
const {selected: selectedServices, rejectedByCategory} =
  selectServiceRecords(sourceCatalog);

const rawCollections = {
  products: await listCollection("products"),
  insurances: await listCollection("insurances"),
};
const backupEvidence = await createBackup(rawCollections);
const existingProducts = rawCollections.products
  .map(decodeDocument);
const existingInsurances = rawCollections.insurances
  .map(decodeDocument);
const productByID = new Map(existingProducts.map((document) => [
  document.id,
  document,
]));
const insuranceByID = new Map(existingInsurances.map((document) => [
  document.id,
  document,
]));

const verifiedAt = new Date();
const expiresAt = new Date(
  verifiedAt.getTime() + EXPIRY_DAYS * 24 * 60 * 60 * 1000,
);
const serviceDocuments = selectedServices.map((record) => {
  const id = `hk-service-${record.sourceId}`;
  return buildServiceDocument(
    record,
    productByID.get(id),
    verifiedAt,
    expiresAt,
  );
});
const insuranceDocuments = INSURANCE_DIRECTORY.map((entry) =>
  buildInsuranceDocument(entry, verifiedAt, expiresAt),
);
const serviceTargetIDs = new Set(serviceDocuments.map(({id}) => id));
const insuranceTargetIDs = new Set(insuranceDocuments.map(({id}) => id));
const unexpectedCurrentProducts = existingProducts
  .filter((document) =>
    isCurrentPublicHKDocument(document, verifiedAt)
      && !serviceTargetIDs.has(document.id),
  )
  .map(({id}) => id);
const unexpectedCurrentInsurances = existingInsurances
  .filter((document) =>
    isCurrentPublicHKDocument(document, verifiedAt)
      && !insuranceTargetIDs.has(document.id),
  )
  .map(({id}) => id);
if (
  unexpectedCurrentProducts.length > 0
  || unexpectedCurrentInsurances.length > 0
) {
  throw new Error(
    "Unexpected current HK catalog documents would make the published counts "
    + `ambiguous: products=${unexpectedCurrentProducts.join(",") || "none"}; `
    + `insurances=${unexpectedCurrentInsurances.join(",") || "none"}.`,
  );
}

for (const document of serviceDocuments) {
  assertSanitizedServiceDocument(document);
}
for (const document of insuranceDocuments) {
  assertNormalizedInsuranceDocument(document);
}

const categoryCounts = Object.fromEntries(
  Object.values(CATEGORY_CONFIG).map(({category}) => [
    category,
    serviceDocuments.filter((document) => document.category === category).length,
  ]),
);
const expectedCategoryCounts = Object.fromEntries(
  Object.values(CATEGORY_CONFIG).map(({category, count}) => [category, count]),
);
if (
  JSON.stringify(categoryCounts) !== JSON.stringify(expectedCategoryCounts)
) {
  throw new Error(
    `Unexpected category counts: ${JSON.stringify(categoryCounts)}`,
  );
}
if (insuranceDocuments.length !== 3) {
  throw new Error(
    `Expected exactly 3 insurance documents, found ${insuranceDocuments.length}.`,
  );
}

console.log(JSON.stringify({
  mode: APPLY ? "apply" : "dry-run",
  projectId: PROJECT_ID,
  migrationId: MIGRATION_ID,
  serviceDocuments: serviceDocuments.length,
  categoryCounts,
  insuranceDocuments: insuranceDocuments.map(
    ({id, providerName, planName, website}) => ({
      id,
      providerName,
      planName,
      website,
    }),
  ),
  rejectedSourceAddresses: rejectedByCategory,
  metadata: {
    status: "approved",
    catalogRegion: "HK",
    region: "HK",
    verifiedAt: verifiedAt.toISOString(),
    expiresAt: expiresAt.toISOString(),
    expiryDays: EXPIRY_DAYS,
  },
  sanitization: {
    servicePriceSentinel: 0,
    publishedPrice: false,
    omittedClaims: [...PROHIBITED_SERVICE_FIELDS].sort(),
    insurancePremiums: 0,
    insuranceCoverageAndExclusions: "empty",
    deletesLegacyDocuments: false,
  },
  ...backupEvidence,
}, null, 2));

if (!APPLY) {
  process.exit(0);
}

const writes = [
  ...serviceDocuments.map((document) =>
    updateWrite(
      "products",
      document.id,
      document,
      productByID.get(document.id),
    ),
  ),
  ...insuranceDocuments.map((document) =>
    updateWrite(
      "insurances",
      document.id,
      document,
      insuranceByID.get(document.id),
    ),
  ),
];
const commitTime = await commitWrites(writes);
console.log(JSON.stringify({
  applied: true,
  commitTime,
  postCommitVerification: "pending",
  rollbackBackupPath: backupEvidence.backupPath,
  rollbackBackupSHA256: backupEvidence.backupSHA256,
}, null, 2));

const verifiedProducts = (await listCollection("products")).map(decodeDocument);
const verifiedInsurances = (await listCollection("insurances")).map(decodeDocument);
const verificationTime = new Date();
const publicProducts = verifiedProducts.filter((document) =>
  isCurrentPublicHKDocument(document, verificationTime),
);
const publicInsurances = verifiedInsurances.filter((document) =>
  isCurrentPublicHKDocument(document, verificationTime),
);
if (publicProducts.length !== 124) {
  throw new Error(
    `Post-migration products: expected 124, found ${publicProducts.length}.`,
  );
}
if (publicInsurances.length !== 3) {
  throw new Error(
    `Post-migration insurances: expected 3, found ${publicInsurances.length}.`,
  );
}

for (const document of publicProducts) {
  assertSanitizedServiceDocument(document.fields);
  if (
    document.fields.migrationId !== MIGRATION_ID
    || document.fields.region !== "HK"
    || document.fields.expiresAt !== expiresAt.toISOString()
  ) {
    throw new Error(`${document.id}: unexpected product publication metadata.`);
  }
}
for (const document of publicInsurances) {
  assertNormalizedInsuranceDocument(document.fields);
  if (
    document.fields.migrationId !== MIGRATION_ID
    || document.fields.region !== "HK"
    || document.fields.expiresAt !== expiresAt.toISOString()
  ) {
    throw new Error(
      `${document.id}: unexpected insurance publication metadata.`,
    );
  }
}

verifyLegacyDocumentsPreserved({
  before: existingProducts,
  after: verifiedProducts,
  migrationTargetIDs: serviceTargetIDs,
  collection: "products",
});
verifyLegacyDocumentsPreserved({
  before: existingInsurances,
  after: verifiedInsurances,
  migrationTargetIDs: insuranceTargetIDs,
  collection: "insurances",
});

console.log(JSON.stringify({
  applied: true,
  commitTime,
  verifiedPublicProducts: publicProducts.length,
  verifiedPublicInsurances: publicInsurances.length,
  legacyDocumentsPreserved: true,
}, null, 2));
