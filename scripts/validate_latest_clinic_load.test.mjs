import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const mapViewModelPath = new URL("../VetMap/ViewModels/MapViewModel.swift", import.meta.url);
const clinicsViewModelPath = new URL("../VetMap/ViewModels/ClinicsViewModel.swift", import.meta.url);

function initializerBody(source, typeName) {
  const start = source.indexOf("    init(");
  assert.notEqual(start, -1, `${typeName} initializer missing`);
  const nextMember = source.indexOf("\n    var ", start);
  assert.notEqual(nextMember, -1, `${typeName} initializer boundary missing`);
  return source.slice(start, nextMember);
}

function assertLatestRequestWins(source, typeName) {
  assert.match(source, /@ObservationIgnored private var loadRequestGeneration = 0/);
  assert.match(source, /loadRequestGeneration &\+= 1/);
  assert.match(
    source,
    /defer\s*\{\s*if requestGeneration == loadRequestGeneration\s*\{\s*isLoading = false/,
    `${typeName} must not let an older request clear a newer loading state`,
  );

  const currentRequestGuards = source.match(
    /guard requestGeneration == loadRequestGeneration else \{ return \}/g,
  ) ?? [];
  assert.ok(
    currentRequestGuards.length >= 3,
    `${typeName} must gate fetched data, errors, and final state`,
  );
  assert.match(source, /let fetchedClinics = try await firebase\.fetchClinics\(\)/);
  assert.match(source, /guard requestGeneration == loadRequestGeneration else \{ return \}\s+clinics = fetchedClinics/);
}

test("map clinic loads are generation isolated", async () => {
  const source = await readFile(mapViewModelPath, "utf8");
  assertLatestRequestWins(source, "MapViewModel");
  assert.match(
    source,
    /func loadClinics\(\)\s*\{\s*let requestGeneration = beginClinicLoad\(\)/,
    "MapViewModel must allocate the generation before spawning its Task",
  );
  assert.match(
    source,
    /performClinicLoad\([\s\S]*requestGeneration: requestGeneration/,
  );
  assert.doesNotMatch(
    initializerBody(source, "MapViewModel"),
    /loadClinics\(/,
    "MapViewModel must not duplicate the view's initial load",
  );
});

test("directory clinic loads are generation isolated", async () => {
  const source = await readFile(clinicsViewModelPath, "utf8");
  assertLatestRequestWins(source, "ClinicsViewModel");
  assert.doesNotMatch(
    initializerBody(source, "ClinicsViewModel"),
    /Task\s*\{\s*await loadClinics\(\)/,
    "ClinicsViewModel must not duplicate its host view's initial load",
  );
});
