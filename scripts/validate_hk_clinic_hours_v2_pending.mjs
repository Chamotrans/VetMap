import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { validateHKCatalogIntegrity } from "./validate_hk_catalog_integrity.mjs";

const EXPECTED_TOP_LEVEL = {
  schemaVersion: 1,
  migrationId: "hk-clinic-hours-v2-2026-08-02",
  deploymentStatus: "pending",
  catalogRegion: "HK",
  timeZoneIdentifier: "Asia/Hong_Kong",
  verifiedAt: "2026-08-02T00:00:00+08:00",
  expiresAt: "2026-10-31T00:00:00+08:00",
  count: 4,
};

const CANONICAL_ENTRIES = new Map([
  ["clinic-hk-vetmap-seed-pets-central", {
    expectedName: "Pets Central 旺角動物醫院",
    is24Hours: true,
    offersNightService: true,
    displayLabel: "24 小時急症",
    serviceNote: "提供夜間急症服務；到診前請先致電確認。",
    sourceName: "Pets Central 官方網站",
    sourceURL: "https://pets-central.com/en/AboutUs/Hospitals",
    weeklyHours: {},
  }],
  ["clinic-hk-vetmap-vet-141", {
    expectedName: "將軍澳動物醫院",
    is24Hours: false,
    offersNightService: false,
    displayLabel: "",
    serviceNote: "官方頁面未列出公眾假期例外；出發前請先致電確認。",
    sourceName: "Pets Central 官方網站",
    sourceURL: "https://pets-central.com/en/AboutUs/Hospitals",
    weeklyHours: Object.fromEntries(["mon", "tue", "wed", "thu", "fri", "sat", "sun"].map((day) => [day, [{opensAt: "08:30", closesAt: "20:30"}]])),
  }],
  ["clinic-hk-vetmap-vet-159", {
    expectedName: "Southside Vets",
    is24Hours: false,
    offersNightService: false,
    displayLabel: "",
    serviceNote: "官方頁面未列出公眾假期例外；出發前請先致電確認。",
    sourceName: "Southside Vets 官方網站",
    sourceURL: "https://www.southsidevets.hk/contactus",
    weeklyHours: {
      mon: [{opensAt: "10:00", closesAt: "19:00"}], tue: [{opensAt: "10:00", closesAt: "19:00"}], wed: [{opensAt: "10:00", closesAt: "19:00"}], thu: [{opensAt: "10:00", closesAt: "19:00"}], fri: [{opensAt: "10:00", closesAt: "19:00"}], sat: [{opensAt: "10:00", closesAt: "18:00"}], sun: [{opensAt: "10:00", closesAt: "14:00"}],
    },
  }],
  ["clinic-hk-vetmap-vet-156", {
    expectedName: "Trinity Vets",
    is24Hours: false,
    offersNightService: false,
    displayLabel: "",
    serviceNote: "官方頁面未列出公眾假期例外；出發前請先致電確認。",
    sourceName: "Trinity Vets 官方網站",
    sourceURL: "https://trinityvets.com.hk/hk/contact/",
    weeklyHours: Object.fromEntries(["mon", "tue", "wed", "thu", "fri", "sat"].map((day) => [day, [{opensAt: "09:00", closesAt: "13:00"}, {opensAt: "14:00", closesAt: "19:00"}]]).concat([["sun", [{opensAt: "10:00", closesAt: "13:00"}, {opensAt: "14:00", closesAt: "19:00"}]]])),
  }],
]);

function assert(condition, message) {
  if (!condition) throw new Error(`HK clinic hours v2 pending: ${message}`);
}

function sameJSON(lhs, rhs) {
  return JSON.stringify(lhs) === JSON.stringify(rhs);
}

export function validateHKClinicHoursV2Pending({ catalog, v1Hours, pending, report }) {
  for (const [key, value] of Object.entries(EXPECTED_TOP_LEVEL)) {
    assert(pending?.[key] === value, `${key} must equal ${JSON.stringify(value)}`);
  }
  assert(Array.isArray(pending.clinics) && pending.clinics.length === pending.count,
    "count must match pending clinics length");

  const catalogNames = new Map(catalog.clinics.map((clinic) => [clinic.id, clinic.name]));
  const v1IDs = new Set(v1Hours.clinics.map(({ clinicID }) => clinicID));
  const pendingIDs = new Set();
  for (const clinic of pending.clinics) {
    assert(!pendingIDs.has(clinic.clinicID), `duplicate pending clinicID: ${clinic.clinicID}`);
    pendingIDs.add(clinic.clinicID);
    assert(catalogNames.has(clinic.clinicID), `clinicID is not in catalog: ${clinic.clinicID}`);
    assert(!v1IDs.has(clinic.clinicID), `clinicID overlaps v1: ${clinic.clinicID}`);
    assert(clinic.expectedName === catalogNames.get(clinic.clinicID),
      `expectedName must match catalog: ${clinic.clinicID}`);

    const canonical = CANONICAL_ENTRIES.get(clinic.clinicID);
    assert(canonical, `unexpected pending clinicID: ${clinic.clinicID}`);
    for (const field of ["expectedName", "is24Hours", "offersNightService", "displayLabel", "serviceNote", "sourceName", "sourceURL"]) {
      assert(clinic[field] === canonical[field], `${clinic.clinicID}: ${field} must match canonical value`);
    }
    assert(sameJSON(clinic.weeklyHours, canonical.weeklyHours),
      `${clinic.clinicID}: weeklyHours must match canonical schedule`);
    assert(typeof clinic.sourceURL === "string" && clinic.sourceURL.startsWith("https://"),
      `${clinic.clinicID}: sourceURL must be official HTTPS`);
    if (!clinic.is24Hours) {
      assert(/公眾假期/.test(clinic.serviceNote) && /致電/.test(clinic.serviceNote),
        `${clinic.clinicID}: serviceNote must mention public-holiday exceptions and calling ahead`);
    }
  }
  assert(pendingIDs.size === CANONICAL_ENTRIES.size
    && [...CANONICAL_ENTRIES.keys()].every((id) => pendingIDs.has(id)),
  "pending clinic IDs must match the approved v2 plan");

  const mergedHours = {
    ...pending,
    count: v1Hours.count + pending.count,
    clinics: [...v1Hours.clinics, ...pending.clinics],
  };
  validateHKCatalogIntegrity({ catalog, hours: mergedHours, report });
  const planned24Hours = mergedHours.clinics.filter(({ is24Hours }) => is24Hours).length;
  const plannedScheduled = mergedHours.count - planned24Hours;
  assert(mergedHours.count === 15, "planned total must be 15");
  assert(planned24Hours === 11, "planned 24-hour count must be 11");
  assert(plannedScheduled === 4, "planned scheduled count must be 4");

  return {
    deploymentStatus: pending.deploymentStatus,
    productionApplied: false,
    pendingCount: pending.count,
    plannedTotal: mergedHours.count,
    planned24Hours,
    plannedScheduled,
  };
}

async function readJSON(path) {
  return JSON.parse(await readFile(path, "utf8"));
}

async function main() {
  const [catalog, v1Hours, pending, report] = await Promise.all([
    readJSON(new URL("../catalog/hk_clinics_v1.json", import.meta.url)),
    readJSON(new URL("../catalog/hk_clinic_hours_v1.json", import.meta.url)),
    readJSON(new URL("../catalog/hk_clinic_hours_v2.pending.json", import.meta.url)),
    readJSON(new URL("../catalog/hk_clinics_v1.report.json", import.meta.url)),
  ]);
  console.log(JSON.stringify(validateHKClinicHoursV2Pending({ catalog, v1Hours, pending, report })));
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
