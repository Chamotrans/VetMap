import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8");

test("urgent CTA has an explicit, permission-safe activation path", async () => {
  const [map, model, location] = await Promise.all([
    read("VetMap/Views/Map/ClinicMapView.swift"),
    read("VetMap/ViewModels/MapViewModel.swift"),
    read("VetMap/Services/LocationService.swift"),
  ]);

  assert.match(map, /"急需睇獸醫"/);
  assert.match(map, /viewModel\.activateUrgentMode\(\)\s+focusOnUserLocation\(\)/);
  assert.match(model, /private\(set\) var isUrgentMode = false/);
  assert.match(model, /func activateUrgentMode\(\)/);
  assert.match(model, /filter = ClinicSearchFilter\(\)\s+isUrgentMode = true/);
  assert.match(model, /if isUrgentMode \{\s*reconciledID = visibleClinics\.first\?\.id/);
  assert.match(model, /guard reconciledID != selectedClinicID else \{\s*return/);
  assert.match(model, /func clearFilters\(\)\s*\{\s*isUrgentMode = false/);
  assert.match(model, /if filter != oldValue\s*\{\s*isUrgentMode = false/);
  assert.match(map, /viewModel\.isUrgentMode \? "急需模式已啟用"/);
  assert.match(location, /func requestLocationFromButton\(\)/);
  assert.equal((map.match(/requestLocationFromButton\(\)/g) ?? []).length, 1);
});

test("urgent ordering uses trustworthy availability first, then contextual distance", async () => {
  const model = await read("VetMap/ViewModels/MapViewModel.swift");

  assert.match(model, /func urgentClinicOrdering\(/);
  assert.match(model, /lhs\.availabilitySortRank\(at: date\)/);
  assert.match(model, /rhs\.availabilitySortRank\(at: date\)/);
  assert.match(model, /if lhsRank != rhsRank\s*\{\s*return lhsRank < rhsRank/);
  assert.match(model, /if let location \{/);
  assert.match(model, /let lhsDistance = lhs\.mapCoordinate\.map/);
  assert.match(model, /let rhsDistance = rhs\.mapCoordinate\.map/);
  assert.match(model, /distance\(from: location\)/);
  assert.match(model, /case \(\.some, \.none\):\s*return true/);
  assert.match(model, /case \(\.none, \.some\):\s*return false/);
  assert.match(model, /case \(\.none, \.none\):\s*break/);
  assert.match(model, /lhs\.name\.localizedStandardCompare\(rhs\.name\)/);
  assert.match(model, /lhs\.id\.localizedStandardCompare\(rhs\.id\)/);
  assert.match(model, /return urgentClinicOrdering\(\s*directoryClinics,/);
  assert.doesNotMatch(model, /isUrgentMode \{\s*return filter\.results/);
});

test("urgent selected cards expose safe contact, routing, and details affordances", async () => {
  const [map, row] = await Promise.all([
    read("VetMap/Views/Map/ClinicMapView.swift"),
    read("VetMap/Views/Map/ClinicRowView.swift"),
  ]);

  assert.match(row, /var isUrgentMode = false/);
  assert.match(row, /var onCall: \(\(\) -> Void\)\? = nil/);
  assert.match(row, /var onNavigate: \(\(\) -> Void\)\? = nil/);
  assert.match(row, /if callablePhone != nil, let onCall/);
  assert.match(row, /if clinic\.mapCoordinate != nil, let onNavigate/);
  assert.match(row, /"致電"/);
  assert.match(row, /"導航"/);
  assert.match(row, /"詳情"/);
  assert.match(map, /guard let phone = callablePhone\(for: clinic\), let url = URL\(string: "tel:/);
  assert.match(map, /guard let coordinate = clinic\.mapCoordinate else \{ return \}/);
  assert.match(map, /item\.openInMaps/);
});

test("1.1 branding, tab naming, and community entry points remain intact", async () => {
  const [project, content, modelTests, addClinic, detail, chat, workflow] = await Promise.all([
    read("VetMap.xcodeproj/project.pbxproj"),
    read("VetMap/ContentView.swift"),
    read("VetMapTests/VetMapTests.swift"),
    read("VetMap/Views/Community/AddClinicView.swift"),
    read("VetMap/Views/ClinicDetail/ClinicDetailView.swift"),
    read("VetMap/Views/Chat/ChatListView.swift"),
    read(".github/workflows/ci.yml"),
  ]);

  const versions = project.match(/MARKETING_VERSION = ([^;]+);/g) ?? [];
  assert.ok(versions.length > 0);
  assert.ok(versions.every((version) => version === "MARKETING_VERSION = 1.1;"));
  assert.match(content, /static let primary = Color\(red: 0\.64, green: 0\.31, blue: 0\.02\)/);
  assert.match(content, /static let accent = Color\(red: 0\.29, green: 0\.43, blue: 0\.48\)/);
  assert.match(content, /Label\("服務", systemImage: "storefront\.fill"\)/);
  assert.match(project, /PBXNativeTarget "VetMapTests"/);
  assert.match(project, /VetMapTests\.swift in Sources/);
  assert.match(modelTests, /testUrgentActivationSelectsFirstRankedClinicInsteadOfOldSelection/);
  assert.match(modelTests, /testUrgentLocationRerankingSelectsFirstClinicOnlyWhenItChanges/);
  assert.match(addClinic, /TextField\("電話"/);
  assert.match(detail, /showClinicReport/);
  assert.match(chat, /struct ChatListView/);
  assert.match(workflow, /validate_urgent_clinic_mode\.test\.mjs/);
});
