import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import test from "node:test";
import {validateHKClinicHoursV3Pending} from "./validate_hk_clinic_hours_v3_pending.mjs";

async function fixture() {
  const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8").then(JSON.parse);
  return {catalog: await read("catalog/hk_clinics_v1.json"), v1Hours: await read("catalog/hk_clinic_hours_v1.json"), v2Hours: await read("catalog/hk_clinic_hours_v2.pending.json"), pending: await read("catalog/hk_clinic_hours_v3.pending.json")};
}
const clone = (value) => JSON.parse(JSON.stringify(value));
test("v3 plan adds 18 traceable Hong Kong clinics without overlap", async () => {
  const result = validateHKClinicHoursV3Pending(await fixture());
  assert.equal(result.pendingCount, 18); assert.equal(result.priorPlannedTotal, 15); assert.equal(result.plannedTotal, 33); assert.equal(result.planned24Hours, 14); assert.equal(result.plannedScheduled, 19);
});
test("v3 rejects overlap, identity drift, unsafe sources, invalid hours, and stale windows", async () => {
  const base = await fixture();
  for (const [mutate, message] of [
    [(x) => { x.pending.clinics[0].clinicID = x.v1Hours.clinics[0].clinicID; }, /overlaps/],
    [(x) => { x.pending.clinics[0].expectedPhone = "wrong"; }, /expectedPhone/],
    [(x) => { x.pending.clinics[0].sourceURL = "http://example.com"; }, /source name\/URL/],
    [(x) => { x.pending.clinics[0].sourceURL = "https://example.com"; }, /source name\/URL/],
    [(x) => { x.pending.clinics[0].sourceURL = "https://www.concordiapetcare.com/contact"; }, /source name\/URL/],
    [(x) => { x.pending.clinics[0].sourceName = "Pet Space 官方網站"; }, /source name\/URL/],
    [(x) => { x.pending.clinics[1].weeklyHours.mon[0].closesAt = "09:00"; }, /overnight/],
    [(x) => { x.pending.expiresAt = "2027-01-01T00:00:00+08:00"; }, /window/],
  ]) { const value = clone(base); mutate(value); assert.throws(() => validateHKClinicHoursV3Pending(value), message); }
});
test("every canonical source tuple is exact; query drift and cross-clinic tuple remaps fail", async () => {
  const base = await fixture();
  for (const [index, clinic] of base.pending.clinics.entries()) {
    const exact = clone(base);
    exact.pending.clinics[index].sourceName = clinic.sourceName;
    exact.pending.clinics[index].sourceURL = clinic.sourceURL;
    assert.doesNotThrow(() => validateHKClinicHoursV3Pending(exact));

    const queryDrift = clone(base);
    const separator = clinic.sourceURL.includes("?") ? "&" : "?";
    queryDrift.pending.clinics[index].sourceURL = `${clinic.sourceURL}${separator}vetmapAudit=1`;
    assert.throws(
      () => validateHKClinicHoursV3Pending(queryDrift),
      /source name\/URL/,
      `${clinic.clinicID} must reject a query-only source URL mutation`,
    );

    const remap = clone(base);
    const other = base.pending.clinics.find((candidate) =>
      candidate.sourceName !== clinic.sourceName
        || candidate.sourceURL !== clinic.sourceURL,
    );
    assert.ok(other, `${clinic.clinicID} needs a distinct tuple fixture`);
    remap.pending.clinics[index].sourceName = other.sourceName;
    remap.pending.clinics[index].sourceURL = other.sourceURL;
    assert.throws(
      () => validateHKClinicHoursV3Pending(remap),
      /source name\/URL/,
      `${clinic.clinicID} must reject another clinic's otherwise valid tuple`,
    );
  }
});
