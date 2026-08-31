import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import {mkdtemp, readFile, rm, stat} from "node:fs/promises";
import {tmpdir} from "node:os";
import path from "node:path";
import test from "node:test";
import {
  analyzeInventory,
  buildExpectedAvailability,
  decodeFirestoreDocument,
  encodeFirestoreValue,
  listFirestoreClinics,
  parseOptions,
  runMigration,
  writeBackupFile,
} from "./restore_hk_clinic_hours_v2_pending.mjs";

const V1_MIGRATION_ID = "hk-clinic-hours-v1-2026-07-30";
const PATHS = {
  catalog: "catalog/hk_clinics_v1.json",
  v1Hours: "catalog/hk_clinic_hours_v1.json",
  pending: "catalog/hk_clinic_hours_v2.pending.json",
  report: "catalog/hk_clinics_v1.report.json",
};
const BACKUP_RESULT = {
  path: "build/backups/test.json",
  sha256: "a".repeat(64),
};

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

async function fixtures() {
  const readJSON = async (relativePath) => JSON.parse(
    await readFile(new URL(`../${relativePath}`, import.meta.url), "utf8"),
  );
  return {
    catalog: await readJSON(PATHS.catalog),
    v1Hours: await readJSON(PATHS.v1Hours),
    pending: await readJSON(PATHS.pending),
    report: await readJSON(PATHS.report),
  };
}

function fixtureReader(values) {
  const byPath = new Map([
    [PATHS.catalog, values.catalog],
    [PATHS.v1Hours, values.v1Hours],
    [PATHS.pending, values.pending],
    [PATHS.report, values.report],
  ]);
  return async (filePath) => clone(byPath.get(filePath));
}

function makeDocument(id, fields, index) {
  const updateTime = `2026-08-02T00:00:${String(index).padStart(2, "0")}.000Z`;
  return {
    id,
    updateTime,
    fields,
    raw: {
      name: `projects/vetmap-app/databases/(default)/documents/clinics/${id}`,
      fields: {fixture: {stringValue: id}},
      createTime: "2026-07-01T00:00:00.000Z",
      updateTime,
    },
  };
}

function makeInventory(values, v2State = "absent") {
  const catalogByID = new Map(values.catalog.clinics.map((clinic) => [
    clinic.id,
    clinic,
  ]));
  const documents = values.v1Hours.clinics.map((clinic, index) => makeDocument(
    clinic.clinicID,
    {
      name: clinic.expectedName,
      status: "approved",
      catalogRegion: "HK",
      region: "HK",
      availability: buildExpectedAvailability(
        values.v1Hours,
        clinic,
        V1_MIGRATION_ID,
      ),
    },
    index,
  ));
  values.pending.clinics.forEach((clinic, index) => {
    const availability = v2State === "exact"
      ? buildExpectedAvailability(values.pending, clinic)
      : undefined;
    documents.push(makeDocument(
      clinic.clinicID,
      {
        name: catalogByID.get(clinic.clinicID).name,
        status: "approved",
        catalogRegion: "HK",
        region: "HK",
        ...(availability === undefined ? {} : {availability}),
      },
      index + values.v1Hours.count,
    ));
  });
  return documents;
}

function baseRunArguments(values, inventory) {
  return {
    options: parseOptions([]),
    readJSON: fixtureReader(values),
    listClinics: async () => inventory,
    writeBackup: async () => BACKUP_RESULT,
  };
}

test("strict CLI parser permits only explicit, complete, unique flags", () => {
  assert.deepEqual(parseOptions([]), {apply: false, backupPath: undefined});
  assert.deepEqual(parseOptions(["--apply"]), {
    apply: true,
    backupPath: undefined,
  });
  assert.deepEqual(parseOptions(["--backup", "tmp/backup.json", "--apply"]), {
    apply: true,
    backupPath: "tmp/backup.json",
  });
  for (const args of [
    ["--unknown"],
    ["--apply", "--apply"],
    ["--backup"],
    ["--backup", "--apply"],
    ["--backup", "one", "--backup", "two"],
  ]) {
    assert.throws(() => parseOptions(args), /Usage:/);
  }
});

test("canonical manifest validation completes before authoritative network", async () => {
  const values = await fixtures();
  values.pending.deploymentStatus = "deployed";
  let networkCalled = false;
  let backupCalled = false;
  await assert.rejects(runMigration({
    options: parseOptions([]),
    readJSON: fixtureReader(values),
    listClinics: async () => {
      networkCalled = true;
      return [];
    },
    writeBackup: async () => {
      backupCalled = true;
      return BACKUP_RESULT;
    },
  }), /deploymentStatus/);
  assert.equal(networkCalled, false);
  assert.equal(backupCalled, false);
});

test("default mode dry-runs, backs up four raw targets, and never commits", async () => {
  const values = await fixtures();
  const inventory = makeInventory(values);
  let commitCount = 0;
  let backedUp;
  const result = await runMigration({
    ...baseRunArguments(values, inventory),
    writeBackup: async (documents) => {
      backedUp = documents;
      return BACKUP_RESULT;
    },
    commit: async () => {
      commitCount += 1;
      return {ok: true};
    },
  });
  assert.equal(commitCount, 0);
  assert.equal(backedUp.length, 4);
  assert.deepEqual(
    backedUp.map(({name}) => name.split("/").at(-1)),
    values.pending.clinics.map(({clinicID}) => clinicID),
  );
  assert.ok(backedUp.every(({updateTime}) => typeof updateTime === "string"));
  assert.deepEqual(result, {
    mode: "dry-run",
    productionApplied: false,
    alreadyApplied: false,
    currentTotal: 11,
    current24Hours: 10,
    currentScheduled: 1,
    writeCount: 4,
    plannedTotal: 15,
    planned24Hours: 11,
    plannedScheduled: 4,
    backupPath: BACKUP_RESULT.path,
    backupSHA256: BACKUP_RESULT.sha256,
  });
});

test("v2 targets must exist with exact name, approved status, and HK regions", async (t) => {
  const values = await fixtures();
  const mutations = [
    ["missing", /target missing/, (documents) => documents.pop()],
    ["renamed", /target renamed/, (documents) => {
      documents.at(-1).fields.name = "Renamed clinic";
    }],
    ["not approved", /not approved/, (documents) => {
      documents.at(-1).fields.status = "pending";
    }],
    ["wrong catalog region", /not in HK/, (documents) => {
      documents.at(-1).fields.catalogRegion = "TW";
    }],
    ["wrong operational region", /not in HK/, (documents) => {
      documents.at(-1).fields.region = "TW";
    }],
  ];
  for (const [name, error, mutate] of mutations) {
    await t.test(name, () => {
      const documents = makeInventory(values);
      mutate(documents);
      assert.throws(
        () => analyzeInventory(documents, values),
        error,
      );
    });
  }
});

test("all eleven v1 records and their 11/10/1 distribution stay canonical", async () => {
  const values = await fixtures();
  const contentDrift = makeInventory(values);
  contentDrift[0].fields.availability.serviceNote = "drift";
  assert.throws(
    () => analyzeInventory(contentDrift, values),
    /v1 canonical availability drift/,
  );

  const distributionDrift = makeInventory(values);
  distributionDrift[0].fields.availability.is24Hours = false;
  assert.throws(
    () => analyzeInventory(distributionDrift, values),
    /v1 canonical availability drift/,
  );
});

test("unexpected, partial, or different v2 availability is rejected", async () => {
  const values = await fixtures();
  const unexpected = makeInventory(values);
  unexpected.push(makeDocument("unexpected-clinic", {
    availability: null,
  }, 30));
  assert.throws(
    () => analyzeInventory(unexpected, values),
    /outside planned IDs/,
  );

  const partial = makeInventory(values);
  partial.at(-1).fields.availability = buildExpectedAvailability(
    values.pending,
    values.pending.clinics.at(-1),
  );
  assert.throws(
    () => analyzeInventory(partial, values),
    /all absent or all exact canonical/,
  );

  const different = makeInventory(values, "exact");
  different.at(-1).fields.availability.displayLabel = "wrong";
  assert.throws(
    () => analyzeInventory(different, values),
    /all absent or all exact canonical/,
  );

  const nullAvailability = makeInventory(values);
  nullAvailability.at(-1).fields.availability = null;
  assert.throws(
    () => analyzeInventory(nullAvailability, values),
    /all absent or all exact canonical/,
  );
});

test("backup failure aborts before any atomic commit", async () => {
  const values = await fixtures();
  let commitCount = 0;
  await assert.rejects(runMigration({
    ...baseRunArguments(values, makeInventory(values)),
    options: parseOptions(["--apply"]),
    writeBackup: async () => {
      throw new Error("disk full");
    },
    commit: async () => {
      commitCount += 1;
      return {ok: true};
    },
  }), /disk full/);
  assert.equal(commitCount, 0);
});

test("real backup contains only four raw documents with 0600 mode and valid SHA-256", async (t) => {
  const values = await fixtures();
  const rawDocuments = makeInventory(values)
    .slice(values.v1Hours.count)
    .map(({raw}) => raw);
  const directory = await mkdtemp(path.join(tmpdir(), "vetmap-hours-v2-"));
  t.after(() => rm(directory, {recursive: true, force: true}));
  const backupPath = path.join(directory, "backup.json");

  const result = await writeBackupFile(rawDocuments, backupPath);
  const payload = await readFile(backupPath, "utf8");
  const parsed = JSON.parse(payload);
  const metadata = await stat(backupPath);

  assert.deepEqual(Object.keys(parsed), ["documents"]);
  assert.deepEqual(parsed, {documents: rawDocuments});
  assert.equal(parsed.documents.length, 4);
  assert.ok(parsed.documents.every(({updateTime}) => typeof updateTime === "string"));
  assert.equal(metadata.mode & 0o777, 0o600);
  assert.deepEqual(result, {
    path: backupPath,
    sha256: createHash("sha256").update(payload).digest("hex"),
  });
});

test("Firestore encoding uses timestampValue and decoding preserves ISO timestamps", () => {
  const availability = encodeFirestoreValue({
    verifiedAt: "2026-08-01T16:00:00.000Z",
    expiresAt: "2026-10-30T16:00:00.000Z",
    serviceNote: "call first",
  });
  assert.deepEqual(
    availability.mapValue.fields.verifiedAt,
    {timestampValue: "2026-08-01T16:00:00.000Z"},
  );
  assert.deepEqual(
    availability.mapValue.fields.expiresAt,
    {timestampValue: "2026-10-30T16:00:00.000Z"},
  );
  assert.deepEqual(
    availability.mapValue.fields.serviceNote,
    {stringValue: "call first"},
  );

  const raw = {
    name: "projects/p/databases/(default)/documents/clinics/a",
    updateTime: "2026-08-02T00:00:00Z",
    fields: {availability},
  };
  assert.equal(
    decodeFirestoreDocument(raw).fields.availability.verifiedAt,
    "2026-08-01T16:00:00.000Z",
  );
});

test("apply sends one atomic four-write payload with masks and preconditions", async () => {
  const values = await fixtures();
  const before = makeInventory(values);
  const after = makeInventory(values, "exact");
  let listCount = 0;
  const commits = [];
  const result = await runMigration({
    ...baseRunArguments(values, before),
    options: parseOptions(["--apply"]),
    listClinics: async () => (listCount++ === 0 ? before : after),
    commit: async (payload) => {
      commits.push(payload);
      return {ok: true, status: 200};
    },
  });
  assert.equal(commits.length, 1);
  assert.equal(commits[0].writes.length, 4);
  commits[0].writes.forEach((write, index) => {
    assert.equal(
      write.update.name,
      `projects/vetmap-app/databases/(default)/documents/clinics/${values.pending.clinics[index].clinicID}`,
    );
    assert.doesNotMatch(write.update.name, /^https?:/);
    assert.deepEqual(write.updateMask, {fieldPaths: ["availability"]});
    assert.deepEqual(write.currentDocument, {
      updateTime: before.at(values.v1Hours.count + index).updateTime,
    });
    assert.deepEqual(Object.keys(write.update.fields), ["availability"]);
    assert.ok(write.update.fields.availability.mapValue.fields.verifiedAt.timestampValue);
    assert.ok(write.update.fields.availability.mapValue.fields.expiresAt.timestampValue);
  });
  assert.equal(result.productionApplied, true);
  assert.equal(result.writeCount, 4);
  assert.equal(result.currentTotal, 15);
  assert.equal(result.current24Hours, 11);
  assert.equal(result.currentScheduled, 4);
  assert.equal(listCount, 2);
});

test("HTTP 409 is not success and prevents post-commit verification", async () => {
  const values = await fixtures();
  let listCount = 0;
  await assert.rejects(runMigration({
    ...baseRunArguments(values, makeInventory(values)),
    options: parseOptions(["--apply"]),
    listClinics: async () => {
      listCount += 1;
      return makeInventory(values);
    },
    commit: async () => ({ok: false, status: 409}),
  }), /HTTP 409/);
  assert.equal(listCount, 1);
});

test("post-commit mismatch never reports productionApplied", async () => {
  const values = await fixtures();
  let listCount = 0;
  await assert.rejects(runMigration({
    ...baseRunArguments(values, makeInventory(values)),
    options: parseOptions(["--apply"]),
    listClinics: async () => {
      listCount += 1;
      return makeInventory(values);
    },
    commit: async () => ({ok: true, status: 200}),
  }), /post-commit inventory/);
  assert.equal(listCount, 2);
});

test("successful post-read proves exact 15/11/4 distribution", async () => {
  const values = await fixtures();
  const before = makeInventory(values);
  const after = makeInventory(values, "exact");
  const proof = analyzeInventory(after, {...values, phase: "post"});
  assert.deepEqual(proof.current, {
    total: 15,
    twentyFourHours: 11,
    scheduled: 4,
  });

  let listCount = 0;
  const result = await runMigration({
    ...baseRunArguments(values, before),
    options: parseOptions(["--apply"]),
    listClinics: async () => (listCount++ === 0 ? before : after),
    commit: async () => ({ok: true, status: 200}),
  });
  assert.equal(result.productionApplied, true);
  assert.equal(result.currentTotal, 15);
  assert.equal(result.current24Hours, 11);
  assert.equal(result.currentScheduled, 4);
  assert.equal(result.plannedTotal, 15);
  assert.equal(result.planned24Hours, 11);
  assert.equal(result.plannedScheduled, 4);
});

test("all-canonical state is idempotent with zero writes", async () => {
  const values = await fixtures();
  const exact = makeInventory(values, "exact");
  let commitCount = 0;
  const dryRun = await runMigration({
    ...baseRunArguments(values, exact),
    commit: async () => {
      commitCount += 1;
      return {ok: true};
    },
  });
  assert.equal(dryRun.alreadyApplied, true);
  assert.equal(dryRun.productionApplied, false);
  assert.equal(dryRun.writeCount, 0);
  assert.equal(dryRun.currentTotal, 15);

  const apply = await runMigration({
    ...baseRunArguments(values, exact),
    options: parseOptions(["--apply"]),
    commit: async () => {
      commitCount += 1;
      return {ok: true};
    },
  });
  assert.equal(apply.alreadyApplied, true);
  assert.equal(apply.productionApplied, true);
  assert.equal(apply.writeCount, 0);
  assert.equal(commitCount, 0);
});

test("authoritative Firestore listing follows pagination and decodes fields", async () => {
  const requests = [];
  const responses = [
    {
      documents: [{
        name: "projects/p/databases/(default)/documents/clinics/one",
        updateTime: "2026-08-02T00:00:00Z",
        fields: {name: {stringValue: "One"}},
      }],
      nextPageToken: "next-token",
    },
    {
      documents: [{
        name: "projects/p/databases/(default)/documents/clinics/two",
        updateTime: "2026-08-02T00:00:01Z",
        fields: {name: {stringValue: "Two"}},
      }],
    },
  ];
  const result = await listFirestoreClinics({
    token: "secret-token",
    fetchImpl: async (url, options) => {
      requests.push({url: String(url), options});
      return {ok: true, json: async () => responses.shift()};
    },
  });
  assert.deepEqual(result.map(({id}) => id), ["one", "two"]);
  assert.deepEqual(result.map(({fields}) => fields.name), ["One", "Two"]);
  assert.match(requests[1].url, /pageToken=next-token/);
  assert.equal(requests[0].options.headers.authorization, "Bearer secret-token");
});
