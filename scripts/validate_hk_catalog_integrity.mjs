import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";

const HONG_KONG_BOUNDS = {
  latitude: [22.1, 22.6],
  longitude: [113.8, 114.5],
};
const WEEKDAYS = new Set(["sun", "mon", "tue", "wed", "thu", "fri", "sat"]);
const TIME_PATTERN = /^([01]\d|2[0-3]):[0-5]\d$/;

function assert(condition, message) {
  if (!condition) throw new Error(`HK catalog integrity: ${message}`);
}

function nonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function validDate(value) {
  const date = new Date(value);
  return Number.isFinite(date.getTime()) ? date : null;
}

function isHongKongCoordinate(coordinate) {
  return coordinate
    && Number.isFinite(coordinate.latitude)
    && Number.isFinite(coordinate.longitude)
    && coordinate.latitude >= HONG_KONG_BOUNDS.latitude[0]
    && coordinate.latitude <= HONG_KONG_BOUNDS.latitude[1]
    && coordinate.longitude >= HONG_KONG_BOUNDS.longitude[0]
    && coordinate.longitude <= HONG_KONG_BOUNDS.longitude[1];
}

function validateClinicCatalog(catalog) {
  assert(catalog?.schemaVersion === 1, "clinic schemaVersion must be 1");
  assert(catalog.catalogRegion === "HK", "clinic catalogRegion must be HK");
  assert(Array.isArray(catalog.clinics), "clinic catalog must contain clinics");
  assert(catalog.count === catalog.clinics.length, "clinic count must match clinics length");
  assert(catalog.count >= 179, "clinic count must be at least 179");

  const clinicIDs = new Set();
  const clinicNames = new Map();
  const lineageIDs = new Set();
  const awaitingCoordinateIDs = new Set();
  let coordinateCount = 0;
  const lineageCoverage = { petcircle: 0, seed: 0 };

  for (const clinic of catalog.clinics) {
    assert(nonEmptyString(clinic.id), "clinic id must be nonempty");
    assert(!clinicIDs.has(clinic.id), `duplicate clinic ID: ${clinic.id}`);
    clinicIDs.add(clinic.id);
    assert(nonEmptyString(clinic.name), `${clinic.id}: name must be nonempty`);
    clinicNames.set(clinic.id, clinic.name);
    assert(nonEmptyString(clinic.address), `${clinic.id}: address must be nonempty`);
    assert(nonEmptyString(clinic.phone), `${clinic.id}: phone must be nonempty`);
    assert(Array.isArray(clinic.sourceRecordIDs) && clinic.sourceRecordIDs.length > 0,
      `${clinic.id}: sourceRecordIDs must be nonempty`);

    for (const lineageID of clinic.sourceRecordIDs) {
      assert(nonEmptyString(lineageID), `${clinic.id}: sourceRecordID must be nonempty`);
      assert(!lineageIDs.has(lineageID), `duplicate lineage ID: ${lineageID}`);
      lineageIDs.add(lineageID);
      if (lineageID.startsWith("petcircle:")) lineageCoverage.petcircle += 1;
      if (lineageID.startsWith("seed:")) lineageCoverage.seed += 1;
    }

    if (clinic.coordinate !== undefined && clinic.coordinate !== null) {
      assert(isHongKongCoordinate(clinic.coordinate), `${clinic.id}: coordinate must be finite and inside Hong Kong`);
      coordinateCount += 1;
    } else {
      awaitingCoordinateIDs.add(clinic.id);
    }
  }

  assert(lineageIDs.size >= 205, "unique lineage IDs must be at least 205");
  return {
    clinicIDs,
    clinicNames,
    coordinateCount,
    awaitingCoordinateCount: catalog.count - coordinateCount,
    awaitingCoordinateIDs,
    lineageIDs,
    lineageCoverage,
  };
}

function validateHoursManifest(hours, clinicIDs, clinicNames) {
  assert(hours?.schemaVersion === 1, "hours schemaVersion must be 1");
  assert(hours.catalogRegion === "HK", "hours catalogRegion must be HK");
  assert(hours.timeZoneIdentifier === "Asia/Hong_Kong", "hours timezone must be Asia/Hong_Kong");
  assert(Array.isArray(hours.clinics), "hours manifest must contain clinics");
  assert(hours.count === hours.clinics.length, "hours count must match clinics length");
  assert(hours.count >= 11, "hours count must be at least 11");
  const verifiedAt = validDate(hours.verifiedAt);
  const expiresAt = validDate(hours.expiresAt);
  assert(verifiedAt && expiresAt && verifiedAt < expiresAt, "hours verifiedAt must be before expiresAt");

  const hourClinicIDs = new Set();
  let twentyFourHourCount = 0;
  for (const clinic of hours.clinics) {
    assert(nonEmptyString(clinic.clinicID) && clinicIDs.has(clinic.clinicID),
      `orphan hours clinicID: ${clinic.clinicID}`);
    assert(!hourClinicIDs.has(clinic.clinicID), `duplicate hours clinicID: ${clinic.clinicID}`);
    hourClinicIDs.add(clinic.clinicID);
    assert(typeof clinic.is24Hours === "boolean", `${clinic.clinicID}: is24Hours must be boolean`);
    assert(typeof clinic.offersNightService === "boolean", `${clinic.clinicID}: offersNightService must be boolean`);
    assert(nonEmptyString(clinic.expectedName), `${clinic.clinicID}: expectedName must be nonempty`);
    assert(clinic.expectedName === clinicNames.get(clinic.clinicID),
      `${clinic.clinicID}: expectedName must match catalog clinic name`);
    assert(nonEmptyString(clinic.sourceName), `${clinic.clinicID}: sourceName must be nonempty`);
    assert(nonEmptyString(clinic.serviceNote), `${clinic.clinicID}: serviceNote must be nonempty`);
    let sourceURL;
    try { sourceURL = new URL(clinic.sourceURL); } catch { sourceURL = null; }
    assert(sourceURL?.protocol === "https:", `${clinic.clinicID}: sourceURL must be HTTPS`);
    assert(clinic.weeklyHours && typeof clinic.weeklyHours === "object" && !Array.isArray(clinic.weeklyHours),
      `${clinic.clinicID}: weeklyHours must be an object`);

    for (const [weekday, intervals] of Object.entries(clinic.weeklyHours)) {
      assert(WEEKDAYS.has(weekday) && Array.isArray(intervals), `${clinic.clinicID}: invalid weekday schedule`);
      for (const interval of intervals) {
        assert(TIME_PATTERN.test(interval?.opensAt) && TIME_PATTERN.test(interval?.closesAt),
          `${clinic.clinicID}: invalid time interval`);
      }
    }
    if (clinic.is24Hours === true) {
      assert(nonEmptyString(clinic.displayLabel), `${clinic.clinicID}: 24-hour displayLabel must be nonempty`);
      twentyFourHourCount += 1;
    } else {
      assert(Object.keys(clinic.weeklyHours).length === 7, `${clinic.clinicID}: regular schedule must cover 7 days`);
      assert([...WEEKDAYS].every((weekday) => Array.isArray(clinic.weeklyHours[weekday])),
        `${clinic.clinicID}: regular schedule must use every weekday`);
    }
  }
  assert(twentyFourHourCount >= 10, "24-hour clinic count must be at least 10");
}

function validateReport(report, catalog, summary) {
  assert(report?.generatedAt === catalog.generatedAt, "report generatedAt must match clinic catalog");
  assert(report.expectedCount === catalog.count && report.actualCount === catalog.count,
    "report expectedCount and actualCount must match clinic count");
  assert(report.coordinateCount === summary.coordinateCount,
    "report coordinateCount must match clinic coordinates");
  assert(report.awaitingCoordinateCount === summary.awaitingCoordinateCount,
    "report awaitingCoordinateCount must match clinics without coordinates");
  assert(summary.coordinateCount + summary.awaitingCoordinateCount === catalog.count,
    "coordinates plus awaiting coordinates must match clinic count");

  const coverage = report.sourceCoverage;
  assert(coverage?.petcircle?.expected >= 176 && coverage.petcircle.covered >= 176,
    "petcircle coverage must be at least 176");
  assert(coverage?.seed?.expected >= 29 && coverage.seed.covered >= 29,
    "seed coverage must be at least 29");
  assert(coverage?.uniqueLineageIDs >= 205, "reported unique lineage IDs must be at least 205");
  assert(coverage.petcircle.expected === coverage.petcircle.covered,
    "report petcircle expected and covered counts must match");
  assert(coverage.seed.expected === coverage.seed.covered,
    "report seed expected and covered counts must match");
  assert(summary.lineageCoverage.petcircle === coverage.petcircle.covered,
    "report petcircle coverage must match catalog lineage coverage");
  assert(summary.lineageCoverage.seed === coverage.seed.covered,
    "report seed coverage must match catalog lineage coverage");
  assert(summary.lineageIDs.size === coverage.uniqueLineageIDs,
    "reported unique lineage IDs must match catalog");
  assert(Array.isArray(report.awaitingCoordinate), "report awaitingCoordinate must be an array");
  assert(report.awaitingCoordinate.length === summary.awaitingCoordinateCount,
    "report awaitingCoordinate entries must match awaiting coordinate count");
  const reportAwaitingIDs = new Set();
  for (const entry of report.awaitingCoordinate) {
    assert(nonEmptyString(entry?.id), "report awaitingCoordinate entry id must be nonempty");
    assert(!reportAwaitingIDs.has(entry.id), `duplicate report awaitingCoordinate ID: ${entry.id}`);
    reportAwaitingIDs.add(entry.id);
  }
  assert(reportAwaitingIDs.size === summary.awaitingCoordinateIDs.size
    && [...reportAwaitingIDs].every((id) => summary.awaitingCoordinateIDs.has(id)),
  "report awaitingCoordinate IDs must exactly match clinics without coordinates");
}

export function validateHKCatalogIntegrity({ catalog, hours, report }) {
  const summary = validateClinicCatalog(catalog);
  validateHoursManifest(hours, summary.clinicIDs, summary.clinicNames);
  validateReport(report, catalog, summary);
  return {
    clinicCount: catalog.count,
    coordinateCount: summary.coordinateCount,
    awaitingCoordinateCount: summary.awaitingCoordinateCount,
    uniqueLineageIDs: summary.lineageIDs.size,
    hoursCount: hours.count,
  };
}

async function readJSON(path) {
  return JSON.parse(await readFile(path, "utf8"));
}

async function main() {
  const [catalog, hours, report] = await Promise.all([
    readJSON(new URL("../catalog/hk_clinics_v1.json", import.meta.url)),
    readJSON(new URL("../catalog/hk_clinic_hours_v1.json", import.meta.url)),
    readJSON(new URL("../catalog/hk_clinics_v1.report.json", import.meta.url)),
  ]);
  console.log(JSON.stringify(validateHKCatalogIntegrity({ catalog, hours, report })));
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
