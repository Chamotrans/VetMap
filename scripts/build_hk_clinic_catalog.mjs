import {createHash} from "node:crypto";
import {mkdir, readFile, writeFile} from "node:fs/promises";
import path from "node:path";

const PETCIRCLE_PATH = "data_sources/petcircle_businesses.json";
const SEED_PATH = "data_sources/hk_clinics_seed.json";
const OUTPUT_PATH = "catalog/hk_clinics_v1.json";
const REPORT_PATH = "catalog/hk_clinics_v1.report.json";
const CACHE_PATH = "build/clinic-catalog/als-cache.json";
const RIGHTS_CONFIRMED_AT = "2026-07-28T00:00:00+08:00";
const EXPIRES_AT = "2027-01-28T00:00:00+08:00";
const SKIP_GEOCODING = process.argv.includes("--no-geocode");
const MIN_ALS_SCORE = 75;
const ALS_LOOKUP_VERSION = 2;

const preservedIDs = new Map([
  ["vet-001", "hk-peace-avenue-veterinary-clinic---cityu-a"],
  ["vet-003", "hk-69dad98a3b2c2f0a8731"],
  ["vet-018", "hk-69dcead9f1da3469d949"],
  ["vet-064", "hk-animal-medical-centre"],
  ["vet-066", "hk-69dad9893b2c2f0a8731"],
  ["vet-074", "hk-macpherson-animal-clinic"],
  ["vet-075", "hk-npv-non-profit-vet-services-npv29"],
  ["vet-162", "hk-hung-hom-veterinary-clinic"],
]);

const explicitSeedResolution = new Map([
  [
    "太平道寵物診所 (PAVC) / 城大動物醫療中心",
    {petcircleID: "vet-001", reuseCoordinate: true, reason: "same current premises"},
  ],
  [
    "動物醫療中心",
    {petcircleID: "vet-064", reuseCoordinate: false, reason: "superseded premises"},
  ],
  [
    "紅磡獸醫診所",
    {petcircleID: "vet-162", reuseCoordinate: false, reason: "superseded premises"},
  ],
  [
    "NPV非牟利獸醫服務協會（NPV29）",
    {petcircleID: "vet-075", reuseCoordinate: false, reason: "superseded premises"},
  ],
  [
    "麥花臣動物診所",
    {petcircleID: "vet-074", reuseCoordinate: true, reason: "same current premises"},
  ],
  [
    "恩典動物醫院",
    {petcircleID: "vet-167", reuseCoordinate: true, reason: "same current premises"},
  ],
  [
    "24 hours Animal Emergency Centre 24小時動物急診中心",
    {petcircleID: "vet-018", reuseCoordinate: false, reason: "superseded premises"},
  ],
]);

const extraSeedNames = new Set([
  "Once And For All Veterinary Centre",
  "Pets Central 旺角動物醫院",
  "萊奧動物醫療中心 LEAO Animal Medical Center",
  "Hong Kong Veterinary Specialty Services",
  "豐盈動物腫瘤中心",
]);

const preservedExtraIDs = new Map([
  ["Once And For All Veterinary Centre", "hk-69dc64ed544efd16046c"],
  ["萊奧動物醫療中心 LEAO Animal Medical Center", "hk-69dceac485c5cd6a0637"],
]);

function cleanText(value) {
  return String(value ?? "")
    .replaceAll("\\u0026", "&")
    .replaceAll("號號", "號")
    .replace(/\s+/g, " ")
    .trim();
}

function mergePhoneValues(...values) {
  const numbers = values
    .flatMap((value) => cleanText(value).split(/\s*[/,;|]\s*/))
    .map((value) => value.trim())
    .filter(Boolean);
  return [...new Set(numbers)].join(" / ");
}

function normalizeAddress(value) {
  return cleanText(value)
    .toLocaleLowerCase("zh-HK")
    .replaceAll("&", "及")
    .replace(/[香港九龍新界\s\-–—()（）/.,，。·號地舖铺樓楼層层室]/g, "");
}

function safeIDPart(value) {
  return cleanText(value)
    .toLocaleLowerCase("en")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}

function seedRecordID(seed) {
  const fingerprint = createHash("sha256")
    .update(`${cleanText(seed.name)}\n${cleanText(seed.address)}`)
    .digest("hex")
    .slice(0, 12);
  return `seed:${seed.id}:${fingerprint}`;
}

function sourceCoordinate(seed) {
  const latitude = Number(seed.lat);
  const longitude = Number(seed.lng);
  if (
    !Number.isFinite(latitude)
    || !Number.isFinite(longitude)
    || latitude < 22.1
    || latitude > 22.6
    || longitude < 113.8
    || longitude > 114.5
  ) {
    return null;
  }
  return {
    latitude,
    longitude,
    coordinateSource: "VetMap authorized source coordinate",
    coordinateMatchScore: 100,
  };
}

function stableClinicID(sourceID, name) {
  const preserved = preservedIDs.get(sourceID);
  if (preserved) return preserved;
  const slug = safeIDPart(sourceID) || safeIDPart(name);
  return `clinic-hk-vetmap-${slug}`;
}

function manifestClinic({
  id,
  name,
  address,
  phone,
  district,
  sourceRecordIDs,
  coordinate,
}) {
  return {
    id,
    name: cleanText(name),
    address: cleanText(address),
    phone: cleanText(phone),
    district: cleanText(district),
    ...(coordinate ? {
      coordinate: {
        latitude: coordinate.latitude,
        longitude: coordinate.longitude,
      },
      coordinateSource: coordinate.coordinateSource,
      coordinateMatchScore: coordinate.coordinateMatchScore,
    } : {}),
    sourceRecordIDs: [...new Set(sourceRecordIDs)].sort(),
    sourceName: "VetMap authorized Hong Kong clinic database",
    rightsBasis: "Owner confirmed database was created in-house or licensed for use",
    rightsConfirmedAt: RIGHTS_CONFIRMED_AT,
    verifiedAt: new Date().toISOString(),
    expiresAt: EXPIRES_AT,
  };
}

async function readJSON(filePath) {
  return JSON.parse(await readFile(filePath, "utf8"));
}

async function readCache() {
  try {
    return await readJSON(CACHE_PATH);
  } catch (error) {
    if (error.code === "ENOENT") return {};
    throw error;
  }
}

async function persistCache(cache) {
  await mkdir(path.dirname(CACHE_PATH), {recursive: true});
  await writeFile(CACHE_PATH, `${JSON.stringify(cache, null, 2)}\n`);
}

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function alsLookupQueries(address) {
  const withoutRegionPrefix = cleanText(address)
    .replace(/^香港(?:九龍|新界)?/, "")
    .replace(/\s*\([^)]*\)\s*$/, "")
    .replace(/\s*（[^）]*）\s*$/, "");
  const withoutUnit = withoutRegionPrefix
    .replace(
      /(?:地下|地舖|地铺|低座|[一二三四五六七八九十0-9]+樓|[一二三四五六七八九十0-9]+至[一二三四五六七八九十0-9]+樓).*$/,
      "",
    )
    .replace(/[，,]\s*[A-Z]?N?\d.*$/i, "");
  return [...new Set(
    [cleanText(address), withoutRegionPrefix, withoutUnit].filter(Boolean),
  )];
}

async function fetchALSSuggestion(query) {
  const url = new URL("https://www.als.gov.hk/lookup");
  url.searchParams.set("q", query);
  url.searchParams.set("n", "1");
  url.searchParams.set("t", "80");

  let lastError;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      const response = await fetch(url, {
        headers: {
          accept: "application/json",
          "accept-language": "en,zh-Hant",
          "user-agent": "VetMap catalog curator (contact: translation@chamotrans.com)",
        },
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      const payload = await response.json();
      const suggestion = payload.SuggestedAddress?.[0];
      const premises = suggestion?.Address?.PremisesAddress;
      const spatial = premises?.GeospatialInformation;
      const score = Number(suggestion?.ValidationInformation?.Score);
      const latitude = Number(spatial?.Latitude);
      const longitude = Number(spatial?.Longitude);
      if (
        !Number.isFinite(score)
        || !Number.isFinite(latitude)
        || !Number.isFinite(longitude)
      ) {
        return {status: "no-match"};
      }
      return {
        status: "matched",
        query,
        score,
        latitude,
        longitude,
        geoAddress: premises.GeoAddress ?? "",
      };
    } catch (error) {
      lastError = error;
      await sleep(500 * attempt);
    }
  }
  return {status: "error", error: lastError?.message ?? "Unknown ALS error"};
}

async function fetchALS(address) {
  const suggestions = [];
  for (const query of alsLookupQueries(address)) {
    const suggestion = await fetchALSSuggestion(query);
    if (suggestion.status === "matched") suggestions.push(suggestion);
    await sleep(120);
  }
  if (suggestions.length === 0) return {status: "no-match"};
  return suggestions.sort((left, right) => right.score - left.score)[0];
}

const petcircle = await readJSON(PETCIRCLE_PATH);
const seeds = await readJSON(SEED_PATH);
const rawVets = petcircle.vet;
if (!Array.isArray(rawVets) || rawVets.length !== 176) {
  throw new Error(`Expected 176 VetMap clinic source rows, found ${rawVets?.length}.`);
}
if (!Array.isArray(seeds) || seeds.length !== 29) {
  throw new Error(`Expected 29 VetMap seed rows, found ${seeds?.length}.`);
}

const candidates = [];
const candidateBySourceID = new Map();
const candidateByAddress = new Map();
const duplicateSourceRows = [];

for (const raw of [...rawVets].sort((left, right) => left.id.localeCompare(right.id))) {
  const addressKey = normalizeAddress(raw.address);
  if (!addressKey) {
    throw new Error(`${raw.id}: empty normalized address.`);
  }
  if (candidateByAddress.has(addressKey)) {
    const existing = candidateByAddress.get(addressKey);
    if (cleanText(existing.name) !== cleanText(raw.name)) {
      throw new Error(
        `${raw.id}: same address as ${existing.sourceID}, but clinic names differ. `
        + "Review explicitly instead of merging by address.",
      );
    }
    existing.sourceRecordIDs.push(`petcircle:${raw.id}`);
    existing.phone = mergePhoneValues(existing.phone, raw.phone);
    duplicateSourceRows.push({
      kept: existing.sourceID,
      merged: raw.id,
      address: cleanText(raw.address),
      phones: existing.phone,
    });
    continue;
  }

  const candidate = {
    sourceID: raw.id,
    name: cleanText(raw.name),
    address: cleanText(raw.address),
    phone: cleanText(raw.phone),
    district: cleanText(raw.district),
    sourceRecordIDs: [`petcircle:${raw.id}`],
    coordinate: null,
  };
  candidates.push(candidate);
  candidateBySourceID.set(candidate.sourceID, candidate);
  candidateByAddress.set(addressKey, candidate);
}

const seedResolutionReport = [];
for (const seed of seeds) {
  const seedSourceRecordID = seedRecordID(seed);
  const exact = candidateByAddress.get(normalizeAddress(seed.address));
  if (exact) {
    exact.sourceRecordIDs.push(seedSourceRecordID);
    exact.coordinate ??= sourceCoordinate(seed);
    seedResolutionReport.push({
      seedName: seed.name,
      resolution: "merged-exact-address",
      target: exact.sourceID,
    });
    continue;
  }

  const explicit = explicitSeedResolution.get(seed.name);
  if (explicit) {
    const target = candidateBySourceID.get(explicit.petcircleID);
    if (!target) {
      throw new Error(`${seed.name}: missing target ${explicit.petcircleID}.`);
    }
    target.sourceRecordIDs.push(seedSourceRecordID);
    if (explicit.reuseCoordinate) {
      target.coordinate ??= sourceCoordinate(seed);
    }
    seedResolutionReport.push({
      seedName: seed.name,
      resolution: explicit.reason,
      target: target.sourceID,
    });
    continue;
  }

  if (!extraSeedNames.has(seed.name)) {
    throw new Error(`Unreviewed seed resolution: ${seed.name}.`);
  }
  const candidate = {
    sourceID: `seed-${safeIDPart(seed.name)}`,
    name: cleanText(seed.name),
    address: cleanText(seed.address),
    phone: cleanText(seed.phone),
    district: cleanText(seed.district),
    sourceRecordIDs: [seedSourceRecordID],
    coordinate: sourceCoordinate(seed),
    preservedID: preservedExtraIDs.get(seed.name),
  };
  candidates.push(candidate);
  candidateBySourceID.set(candidate.sourceID, candidate);
  seedResolutionReport.push({
    seedName: seed.name,
    resolution: "retained-authorized-extra",
    target: candidate.sourceID,
  });
}

if (candidates.length !== 179) {
  throw new Error(`Expected 179 deduplicated clinics, found ${candidates.length}.`);
}

const lineageIDs = candidates.flatMap(({sourceRecordIDs}) => sourceRecordIDs);
const duplicateLineageIDs = lineageIDs.filter(
  (sourceRecordID, index) => lineageIDs.indexOf(sourceRecordID) !== index,
);
const expectedPetcircleIDs = rawVets.map(({id}) => `petcircle:${id}`);
const expectedSeedIDs = seeds.map(
  (seed) => seedRecordID(seed),
);
const missingPetcircleIDs = expectedPetcircleIDs.filter(
  (sourceRecordID) => !lineageIDs.includes(sourceRecordID),
);
const missingSeedIDs = expectedSeedIDs.filter(
  (sourceRecordID) => !lineageIDs.includes(sourceRecordID),
);
if (
  duplicateLineageIDs.length > 0
  || missingPetcircleIDs.length > 0
  || missingSeedIDs.length > 0
) {
  throw new Error(JSON.stringify({
    duplicateLineageIDs,
    missingPetcircleIDs,
    missingSeedIDs,
  }));
}

const cache = await readCache();
let cacheChanged = false;
let lookupCount = 0;
for (const [index, candidate] of candidates.entries()) {
  if (candidate.coordinate || SKIP_GEOCODING) continue;
  const cacheKey = createHash("sha256").update(candidate.address).digest("hex");
  let result = cache[cacheKey];
  if (!result || (
    result.lookupVersion !== ALS_LOOKUP_VERSION
    && !(result.status === "matched" && result.score >= MIN_ALS_SCORE)
  )) {
    result = await fetchALS(candidate.address);
    cache[cacheKey] = {
      address: candidate.address,
      fetchedAt: new Date().toISOString(),
      lookupVersion: ALS_LOOKUP_VERSION,
      ...result,
    };
    cacheChanged = true;
    lookupCount += 1;
    if (lookupCount % 10 === 0) {
      await persistCache(cache);
      console.error(`ALS: ${lookupCount} new lookups; source row ${index + 1}/${candidates.length}`);
    }
    await sleep(180);
  }

  if (
    result.status === "matched"
    && result.score >= MIN_ALS_SCORE
    && result.latitude >= 22.1
    && result.latitude <= 22.6
    && result.longitude >= 113.8
    && result.longitude <= 114.5
  ) {
    candidate.coordinate = {
      latitude: result.latitude,
      longitude: result.longitude,
      coordinateSource: "HKSAR Digital Policy Office Address Lookup Service",
      coordinateMatchScore: result.score,
    };
  }
}
if (cacheChanged) {
  await persistCache(cache);
}

const clinics = candidates
  .map((candidate) => manifestClinic({
    id: candidate.preservedID
      ?? stableClinicID(candidate.sourceID, candidate.name),
    ...candidate,
  }))
  .sort((left, right) => left.id.localeCompare(right.id));

const duplicateIDs = clinics.filter(
  (clinic, index) => clinics.findIndex((item) => item.id === clinic.id) !== index,
);
if (duplicateIDs.length > 0) {
  throw new Error(`Duplicate manifest IDs: ${duplicateIDs.map(({id}) => id).join(", ")}`);
}

const generatedAt = new Date().toISOString();
const manifest = {
  schemaVersion: 1,
  generatedAt,
  catalogRegion: "HK",
  rightsConfirmedAt: RIGHTS_CONFIRMED_AT,
  expiresAt: EXPIRES_AT,
  count: clinics.length,
  clinics,
};
const report = {
  generatedAt,
  expectedCount: 179,
  actualCount: clinics.length,
  sourceCoverage: {
    petcircle: {
      expected: expectedPetcircleIDs.length,
      covered: expectedPetcircleIDs.length - missingPetcircleIDs.length,
    },
    seed: {
      expected: expectedSeedIDs.length,
      covered: expectedSeedIDs.length - missingSeedIDs.length,
    },
    uniqueLineageIDs: lineageIDs.length,
  },
  coordinateCount: clinics.filter(({coordinate}) => coordinate).length,
  awaitingCoordinateCount: clinics.filter(({coordinate}) => !coordinate).length,
  newALSLookupCount: lookupCount,
  duplicateSourceRows,
  seedResolutionReport,
  awaitingCoordinate: clinics
    .filter(({coordinate}) => !coordinate)
    .map(({id, name, address}) => ({id, name, address})),
};

await mkdir(path.dirname(OUTPUT_PATH), {recursive: true});
await writeFile(OUTPUT_PATH, `${JSON.stringify(manifest, null, 2)}\n`);
await writeFile(REPORT_PATH, `${JSON.stringify(report, null, 2)}\n`);

console.log(JSON.stringify({
  manifest: OUTPUT_PATH,
  report: REPORT_PATH,
  count: clinics.length,
  coordinateCount: report.coordinateCount,
  awaitingCoordinateCount: report.awaitingCoordinateCount,
  newALSLookupCount: lookupCount,
}, null, 2));
