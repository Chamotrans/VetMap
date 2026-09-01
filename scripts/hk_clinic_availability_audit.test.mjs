import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import test from "node:test";
import {
  buildAvailabilityExpectation,
  parseAuditOptions,
  verifyApprovedClinicParity,
  verifyHKClinicAvailability,
  verifyNoAvailabilityOutsidePlan,
} from "./hk_clinic_availability_audit.mjs";

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

async function fixtures() {
  const readJSON = async (relativePath) => JSON.parse(await readFile(
    new URL(relativePath, import.meta.url),
    "utf8",
  ));
  return {
    catalog: await readJSON("../catalog/hk_clinics_v1.json"),
    v1Hours: await readJSON("../catalog/hk_clinic_hours_v1.json"),
    pending: await readJSON("../catalog/hk_clinic_hours_v2.pending.json"),
    v3Hours: await readJSON("../catalog/hk_clinic_hours_v3.pending.json"),
    report: await readJSON("../catalog/hk_clinics_v1.report.json"),
  };
}

function buildDocuments(values, expectation) {
  return values.catalog.clinics.map((clinic) => ({
    id: clinic.id,
    name: clinic.name,
    status: "approved",
    catalogRegion: "HK",
    region: "HK",
    ...(expectation.availabilityByID.has(clinic.id)
      ? {availability: clone(expectation.availabilityByID.get(clinic.id))}
      : {}),
  }));
}

function expectation(values, availabilityState) {
  return buildAvailabilityExpectation({...values, availabilityState});
}

test("CLI defaults fail-closed to deployed-v1", () => {
  assert.deepEqual(parseAuditOptions([]), {
    publicOnly: false,
    auditMode: "full",
    availabilityState: "deployed-v1",
  });
  assert.deepEqual(parseAuditOptions(["--public-only"]), {
    publicOnly: true,
    auditMode: "public-only",
    availabilityState: "deployed-v1",
  });
});

test("CLI accepts all states and order-independent flags", () => {
  assert.deepEqual(
    parseAuditOptions(["--availability-state", "deployed-v1"]),
    {
      publicOnly: false,
      auditMode: "full",
      availabilityState: "deployed-v1",
    },
  );
  assert.deepEqual(
    parseAuditOptions(["--availability-state", "deployed-v1", "--public-only"]),
    parseAuditOptions(["--public-only", "--availability-state", "deployed-v1"]),
  );
  assert.equal(
    parseAuditOptions(["--availability-state", "post-apply-v2"])
      .availabilityState,
    "post-apply-v2",
  );
  assert.equal(
    parseAuditOptions(["--availability-state", "post-apply-v3"])
      .availabilityState,
    "post-apply-v3",
  );
});

test("CLI rejects unknown, duplicate, missing, and public-only post-apply options", () => {
  for (const args of [
    ["--unknown"],
    ["--public-only", "--public-only"],
    ["--availability-state"],
    ["--availability-state", "unknown"],
    ["--availability-state", "deployed-v1", "--availability-state", "deployed-v1"],
  ]) {
    assert.throws(() => parseAuditOptions(args), /Usage:/);
  }
  assert.throws(
    () => parseAuditOptions([
      "--public-only",
      "--availability-state",
      "post-apply-v2",
    ]),
    /requires a full authenticated authoritative audit/,
  );
  assert.throws(
    () => parseAuditOptions([
      "--public-only",
      "--availability-state",
      "post-apply-v3",
    ]),
    /requires a full authenticated authoritative audit/,
  );
});

test("selected manifests fail before a network seam can start", async () => {
  const values = await fixtures();
  const invalid = clone(values);
  invalid.pending.deploymentStatus = "deployed";
  let networkCalled = false;
  const validateThenNetwork = async () => {
    const result = expectation(invalid, "post-apply-v2");
    networkCalled = true;
    return result;
  };
  await assert.rejects(validateThenNetwork(), /deploymentStatus/);
  assert.equal(networkCalled, false);
});

test("post-apply-v3 rejects an expired v3 verification window", async () => {
  const values = clone(await fixtures());
  values.v3Hours.expiresAt = "2026-08-31T23:59:59+08:00";
  assert.throws(
    () => expectation(values, "post-apply-v3"),
    /verification window is stale or overlong/,
  );
});

test("deployed-v1 exact overlay passes at 11/10/1", async () => {
  const values = await fixtures();
  const expected = expectation(values, "deployed-v1");
  assert.deepEqual({
    total: expected.total,
    twentyFourHours: expected.twentyFourHours,
    scheduled: expected.scheduled,
  }, {total: 11, twentyFourHours: 10, scheduled: 1});
  assert.deepEqual(
    verifyHKClinicAvailability(
      buildDocuments(values, expected),
      expected,
      "public clinics",
    ),
    {total: 11, twentyFourHours: 10, scheduled: 1},
  );
});

test("post-apply-v2 exact merged overlay passes at 15/11/4", async () => {
  const values = await fixtures();
  const expected = expectation(values, "post-apply-v2");
  assert.deepEqual({
    total: expected.total,
    twentyFourHours: expected.twentyFourHours,
    scheduled: expected.scheduled,
  }, {total: 15, twentyFourHours: 11, scheduled: 4});
  assert.deepEqual(
    verifyHKClinicAvailability(
      buildDocuments(values, expected),
      expected,
      "authenticated clinics",
    ),
    {total: 15, twentyFourHours: 11, scheduled: 4},
  );
});

test("post-apply-v3 exact merged overlay passes at 33/14/19", async () => {
  const values = await fixtures();
  const expected = expectation(values, "post-apply-v3");
  assert.deepEqual({
    total: expected.total,
    twentyFourHours: expected.twentyFourHours,
    scheduled: expected.scheduled,
  }, {total: 33, twentyFourHours: 14, scheduled: 19});
  assert.deepEqual(
    verifyHKClinicAvailability(
      buildDocuments(values, expected),
      expected,
      "authenticated clinics",
    ),
    {total: 33, twentyFourHours: 14, scheduled: 19},
  );
});

test("expectations pin v1 and v2 migration IDs", async () => {
  const values = await fixtures();
  const v1 = expectation(values, "deployed-v1");
  assert.deepEqual(
    new Set([...v1.availabilityByID.values()].map(({migrationId}) => migrationId)),
    new Set(["hk-clinic-hours-v1-2026-07-30"]),
  );
  const v2 = expectation(values, "post-apply-v2");
  assert.deepEqual(
    new Set([...v2.availabilityByID.values()].map(({migrationId}) => migrationId)),
    new Set([
      "hk-clinic-hours-v1-2026-07-30",
      "hk-clinic-hours-v2-2026-08-02",
    ]),
  );
  const v3 = expectation(values, "post-apply-v3");
  assert.deepEqual(
    new Set([...v3.availabilityByID.values()].map(({migrationId}) => migrationId)),
    new Set([
      "hk-clinic-hours-v1-2026-07-30",
      "hk-clinic-hours-v2-2026-08-02",
      "hk-clinic-hours-v3-2026-09-01",
    ]),
  );
});

test("missing, extra, and partial availability fail closed", async () => {
  const values = await fixtures();
  const expected = expectation(values, "post-apply-v2");

  const missing = buildDocuments(values, expected);
  delete missing.find(({id}) => expected.availabilityByID.has(id)).availability;
  assert.throws(
    () => verifyHKClinicAvailability(missing, expected, "public clinics"),
    /availability missing/,
  );

  const extra = buildDocuments(values, expected);
  extra.find(({id}) => !expected.availabilityByID.has(id)).availability = {};
  assert.throws(
    () => verifyHKClinicAvailability(extra, expected, "public clinics"),
    /outside planned IDs/,
  );

  const partial = buildDocuments(values, expectation(values, "deployed-v1"));
  partial.find(({id}) => values.pending.clinics.some(
    ({clinicID}) => clinicID === id,
  )).availability = clone(
    expected.availabilityByID.get(values.pending.clinics[0].clinicID),
  );
  assert.throws(
    () => verifyHKClinicAvailability(partial, expected, "public clinics"),
    /availability missing|availability drift/,
  );
});

test("wrong note, schedule, timestamp, and expiry fail exact comparison", async (t) => {
  const values = await fixtures();
  const expected = expectation(values, "post-apply-v2");
  const targetID = values.pending.clinics.at(-1).clinicID;
  const mutations = [
    ["note", (availability) => {
      availability.serviceNote = "wrong";
    }],
    ["schedule", (availability) => {
      availability.weeklyHours.mon[0].opensAt = "00:00";
    }],
    ["timestamp", (availability) => {
      availability.verifiedAt = "2026-08-03T00:00:00.000Z";
    }],
    ["expiry", (availability) => {
      availability.expiresAt = "2026-11-01T00:00:00.000Z";
    }],
  ];
  for (const [name, mutate] of mutations) {
    await t.test(name, () => {
      const documents = buildDocuments(values, expected);
      mutate(documents.find(({id}) => id === targetID).availability);
      assert.throws(
        () => verifyHKClinicAvailability(documents, expected, "public clinics"),
        /availability drift/,
      );
    });
  }
});

test("unexpected clinic IDs and identity drift fail", async () => {
  const values = await fixtures();
  const expected = expectation(values, "deployed-v1");
  const unexpected = buildDocuments(values, expected);
  unexpected[0].id = "unexpected-clinic";
  assert.throws(
    () => verifyHKClinicAvailability(unexpected, expected, "public clinics"),
    /catalog IDs are incomplete or extra/,
  );

  const renamed = buildDocuments(values, expected);
  renamed[0].name = "Renamed";
  assert.throws(
    () => verifyHKClinicAvailability(renamed, expected, "public clinics"),
    /identity drift/,
  );
});

test("public/authenticated approved ID or availability mismatch fails", async () => {
  const values = await fixtures();
  const expected = expectation(values, "deployed-v1");
  const publicDocuments = buildDocuments(values, expected);
  const authenticated = clone(publicDocuments);

  authenticated.pop();
  assert.throws(
    () => verifyApprovedClinicParity(publicDocuments, authenticated),
    /approved IDs do not match/,
  );

  const availabilityMismatch = clone(publicDocuments);
  availabilityMismatch.find(({availability}) => availability)
    .availability.serviceNote = "different";
  assert.throws(
    () => verifyApprovedClinicParity(publicDocuments, availabilityMismatch),
    /availability mismatch/,
  );
});

test("demo clinic participates in approved parity but is excluded from HK overlay", async () => {
  const values = await fixtures();
  const expected = expectation(values, "deployed-v1");
  const publicHK = buildDocuments(values, expected);
  const demo = {
    id: "vetmap-demo-clinic",
    name: "VetMap Demo Clinic",
    status: "approved",
    catalogRegion: "demo",
    region: "demo",
  };
  const publicApproved = [...publicHK, demo];
  const authenticatedApproved = clone(publicApproved);
  assert.doesNotThrow(
    () => verifyApprovedClinicParity(
      publicApproved,
      authenticatedApproved,
      expected,
    ),
  );
  const authenticatedHK = authenticatedApproved.filter(
    ({id}) => expected.catalogIDs.has(id),
  );
  assert.equal(authenticatedHK.length, 179);
  assert.deepEqual(
    verifyHKClinicAvailability(authenticatedHK, expected, "authenticated clinics"),
    {total: 11, twentyFourHours: 10, scheduled: 1},
  );

  const demoWithAvailability = clone(authenticatedApproved);
  demoWithAvailability.at(-1).availability = {};
  assert.throws(
    () => verifyApprovedClinicParity(
      publicApproved,
      demoWithAvailability,
      expected,
    ),
    /outside planned IDs/,
  );
  assert.throws(
    () => verifyNoAvailabilityOutsidePlan(
      demoWithAvailability,
      expected,
      "public clinics",
    ),
    /outside planned IDs/,
  );
});

test("non-approved authoritative stray availability fails before approved parity", async () => {
  const values = await fixtures();
  const expected = expectation(values, "deployed-v1");
  const publicHK = buildDocuments(values, expected);
  const demo = {
    id: "vetmap-demo-clinic",
    name: "VetMap Demo Clinic",
    status: "approved",
    catalogRegion: "demo",
    region: "demo",
  };
  const publicApproved = [...publicHK, demo];
  const rejectedStray = {
    id: "rejected-stray-clinic",
    name: "Rejected stray",
    status: "rejected",
    catalogRegion: "HK",
    region: "HK",
    availability: {migrationId: "stray"},
  };
  const authoritativeInventory = [
    ...clone(publicApproved),
    rejectedStray,
  ];

  assert.throws(
    () => verifyNoAvailabilityOutsidePlan(
      authoritativeInventory,
      expected,
      "authenticated clinic inventory",
    ),
    /outside planned IDs at rejected-stray-clinic/,
  );

  delete authoritativeInventory.at(-1).availability;
  const authoritativeApproved = authoritativeInventory.filter(
    ({status}) => status === "approved",
  );
  assert.doesNotThrow(
    () => verifyApprovedClinicParity(
      publicApproved,
      authoritativeApproved,
      expected,
    ),
  );
});
