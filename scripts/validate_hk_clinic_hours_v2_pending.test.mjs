import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { validateHKClinicHoursV2Pending } from "./validate_hk_clinic_hours_v2_pending.mjs";

async function fixture() {
  const readJSON = async (path) => JSON.parse(await readFile(new URL(path, import.meta.url), "utf8"));
  return {
    catalog: await readJSON("../catalog/hk_clinics_v1.json"),
    v1Hours: await readJSON("../catalog/hk_clinic_hours_v1.json"),
    pending: await readJSON("../catalog/hk_clinic_hours_v2.pending.json"),
    report: await readJSON("../catalog/hk_clinics_v1.report.json"),
  };
}

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

test("pending v2 plan validates without applying it to production", async () => {
  const result = validateHKClinicHoursV2Pending(await fixture());
  assert.deepEqual(result, {
    deploymentStatus: "pending",
    productionApplied: false,
    pendingCount: 4,
    plannedTotal: 15,
    planned24Hours: 11,
    plannedScheduled: 4,
  });
});

test("duplicate and v1-overlap pending clinic IDs fail", async () => {
  const duplicate = clone(await fixture());
  duplicate.pending.clinics[1].clinicID = duplicate.pending.clinics[0].clinicID;
  assert.throws(() => validateHKClinicHoursV2Pending(duplicate), /duplicate pending clinicID/);

  const overlap = clone(await fixture());
  overlap.pending.clinics[0].clinicID = overlap.v1Hours.clinics[0].clinicID;
  assert.throws(() => validateHKClinicHoursV2Pending(overlap), /clinicID overlaps v1/);
});

test("pending names and source URLs must remain canonical official HTTPS values", async () => {
  const mismatch = clone(await fixture());
  mismatch.pending.clinics[0].expectedName = "Pets Central";
  assert.throws(() => validateHKClinicHoursV2Pending(mismatch), /expectedName must match catalog/);

  const nonHTTPS = clone(await fixture());
  nonHTTPS.pending.clinics[1].sourceURL = "http://pets-central.com/en/AboutUs/Hospitals";
  assert.throws(() => validateHKClinicHoursV2Pending(nonHTTPS), /sourceURL must match canonical value/);

  const nonOfficial = clone(await fixture());
  nonOfficial.pending.clinics[1].sourceURL = "https://example.com/pets-central";
  assert.throws(() => validateHKClinicHoursV2Pending(nonOfficial), /sourceURL must match canonical value/);

  const URLDrift = clone(await fixture());
  URLDrift.pending.clinics[2].sourceURL = "https://www.southsidevets.hk/about";
  assert.throws(() => validateHKClinicHoursV2Pending(URLDrift), /sourceURL must match canonical value/);
});

test("scheduled entries require every canonical weekday and valid times", async () => {
  const missingWeekday = clone(await fixture());
  delete missingWeekday.pending.clinics[1].weeklyHours.sun;
  assert.throws(() => validateHKClinicHoursV2Pending(missingWeekday), /weeklyHours must match canonical schedule/);

  const invalidTime = clone(await fixture());
  invalidTime.pending.clinics[2].weeklyHours.mon[0].opensAt = "25:00";
  assert.throws(() => validateHKClinicHoursV2Pending(invalidTime), /weeklyHours must match canonical schedule/);
});

test("Trinity lunch break cannot be merged or removed", async () => {
  const merged = clone(await fixture());
  merged.pending.clinics[3].weeklyHours.mon = [{opensAt: "09:00", closesAt: "19:00"}];
  assert.throws(() => validateHKClinicHoursV2Pending(merged), /weeklyHours must match canonical schedule/);

  const removed = clone(await fixture());
  removed.pending.clinics[3].weeklyHours.sun.pop();
  assert.throws(() => validateHKClinicHoursV2Pending(removed), /weeklyHours must match canonical schedule/);
});

test("Pets Central remains 24-hour and the plan remains pending", async () => {
  const non24Hour = clone(await fixture());
  non24Hour.pending.clinics[0].is24Hours = false;
  assert.throws(() => validateHKClinicHoursV2Pending(non24Hour), /is24Hours must match canonical value/);

  const deployed = clone(await fixture());
  deployed.pending.deploymentStatus = "deployed";
  assert.throws(() => validateHKClinicHoursV2Pending(deployed), /deploymentStatus must equal "pending"/);
});

test("canonical service notes reject contradictory availability claims", async () => {
  const petsContradiction = clone(await fixture());
  petsContradiction.pending.clinics[0].serviceNote = "只提供日間服務；毋須致電";
  assert.throws(() => validateHKClinicHoursV2Pending(petsContradiction), /serviceNote must match canonical value/);

  const scheduledContradiction = clone(await fixture());
  scheduledContradiction.pending.clinics[1].serviceNote = "公眾假期必定照常，毋須致電";
  assert.throws(() => validateHKClinicHoursV2Pending(scheduledContradiction), /serviceNote must match canonical value/);
});
