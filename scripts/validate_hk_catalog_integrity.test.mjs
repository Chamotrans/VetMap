import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { validateHKCatalogIntegrity } from "./validate_hk_catalog_integrity.mjs";

async function fixture() {
  const readJSON = async (path) => JSON.parse(await readFile(new URL(path, import.meta.url), "utf8"));
  return {
    catalog: await readJSON("../catalog/hk_clinics_v1.json"),
    hours: await readJSON("../catalog/hk_clinic_hours_v1.json"),
    report: await readJSON("../catalog/hk_clinics_v1.report.json"),
  };
}

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

test("current Hong Kong catalog passes integrity validation", async () => {
  const result = validateHKCatalogIntegrity(await fixture());
  assert.equal(result.clinicCount, 179);
  assert.equal(result.hoursCount, 11);
});

test("count synchronized at 178 still fails the clinic floor", async () => {
  const data = clone(await fixture());
  data.catalog.clinics.pop();
  data.catalog.count = 178;
  data.report.expectedCount = 178;
  data.report.actualCount = 178;
  data.report.coordinateCount = data.catalog.clinics.filter((clinic) => clinic.coordinate).length;
  data.report.awaitingCoordinateCount = 178 - data.report.coordinateCount;
  assert.throws(() => validateHKCatalogIntegrity(data), /clinic count must be at least 179/);
});

test("duplicate clinic ID fails", async () => {
  const data = clone(await fixture());
  data.catalog.clinics[1].id = data.catalog.clinics[0].id;
  assert.throws(() => validateHKCatalogIntegrity(data), /duplicate clinic ID/);
});

test("duplicate lineage ID fails", async () => {
  const data = clone(await fixture());
  data.catalog.clinics[1].sourceRecordIDs[0] = data.catalog.clinics[0].sourceRecordIDs[0];
  assert.throws(() => validateHKCatalogIntegrity(data), /duplicate lineage ID/);
});

test("stale lower report source coverage fails", async () => {
  const data = clone(await fixture());
  const clinic = clone(data.catalog.clinics[0]);
  clinic.id = "clinic-hk-vetmap-stale-coverage";
  clinic.sourceRecordIDs = ["petcircle:stale-coverage"];
  delete clinic.coordinate;
  data.catalog.clinics.push(clinic);
  data.catalog.count = 180;
  data.report.expectedCount = 180;
  data.report.actualCount = 180;
  data.report.awaitingCoordinateCount += 1;
  data.report.awaitingCoordinate.push({ id: clinic.id });
  data.report.sourceCoverage.uniqueLineageIDs += 1;
  assert.throws(() => validateHKCatalogIntegrity(data), /report petcircle coverage must match catalog lineage coverage/);
});

test("missing or replaced awaiting coordinate IDs fail", async () => {
  const missing = clone(await fixture());
  missing.report.awaitingCoordinate = [];
  assert.throws(() => validateHKCatalogIntegrity(missing), /entries must match awaiting coordinate count/);

  const replaced = clone(await fixture());
  replaced.report.awaitingCoordinate[0].id = replaced.catalog.clinics[0].id;
  assert.throws(() => validateHKCatalogIntegrity(replaced), /IDs must exactly match clinics without coordinates/);
});

test("orphan hours entry fails", async () => {
  const data = clone(await fixture());
  data.hours.clinics[0].clinicID = "clinic-hk-orphan";
  assert.throws(() => validateHKCatalogIntegrity(data), /orphan hours clinicID/);
});

test("unsafe hours metadata fails", async () => {
  const invalid24Hours = clone(await fixture());
  invalid24Hours.hours.clinics[0].is24Hours = "true";
  assert.throws(() => validateHKCatalogIntegrity(invalid24Hours), /is24Hours must be boolean/);

  const invalidNightService = clone(await fixture());
  invalidNightService.hours.clinics[0].offersNightService = 1;
  assert.throws(() => validateHKCatalogIntegrity(invalidNightService), /offersNightService must be boolean/);

  const mismatchedName = clone(await fixture());
  mismatchedName.hours.clinics[0].expectedName = "錯誤診所名稱";
  assert.throws(() => validateHKCatalogIntegrity(mismatchedName), /expectedName must match catalog clinic name/);

  const blankLabel = clone(await fixture());
  blankLabel.hours.clinics[0].displayLabel = " ";
  assert.throws(() => validateHKCatalogIntegrity(blankLabel), /24-hour displayLabel must be nonempty/);
});

test("outside or invalid coordinate fails", async () => {
  const outside = clone(await fixture());
  outside.catalog.clinics[0].coordinate = { latitude: 25.0381, longitude: 121.5432 };
  assert.throws(() => validateHKCatalogIntegrity(outside), /coordinate must be finite and inside Hong Kong/);

  const invalid = clone(await fixture());
  invalid.catalog.clinics[0].coordinate = { latitude: Number.NaN, longitude: 114.1 };
  assert.throws(() => validateHKCatalogIntegrity(invalid), /coordinate must be finite and inside Hong Kong/);
});

test("a valid petcircle 180th clinic with synchronized report passes", async () => {
  const data = clone(await fixture());
  const clinic = clone(data.catalog.clinics[0]);
  clinic.id = "clinic-hk-vetmap-test-180";
  clinic.name = "完整性測試診所";
  clinic.sourceRecordIDs = ["petcircle:catalog-integrity-180"];
  delete clinic.coordinate;
  data.catalog.clinics.push(clinic);
  data.catalog.count = 180;
  data.report.expectedCount = 180;
  data.report.actualCount = 180;
  data.report.awaitingCoordinateCount += 1;
  data.report.awaitingCoordinate.push({ id: clinic.id });
  data.report.sourceCoverage.petcircle.expected += 1;
  data.report.sourceCoverage.petcircle.covered += 1;
  data.report.sourceCoverage.uniqueLineageIDs += 1;

  const result = validateHKCatalogIntegrity(data);
  assert.equal(result.clinicCount, 180);
  assert.equal(result.coordinateCount, 161);
  assert.equal(result.awaitingCoordinateCount, 19);
  assert.equal(result.uniqueLineageIDs, 206);
});
