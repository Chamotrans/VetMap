import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import test from "node:test";

const paths = {
  map: new URL("../VetMap/Views/Map/ClinicMapView.swift", import.meta.url),
  row: new URL("../VetMap/Views/Map/ClinicRowView.swift", import.meta.url),
  viewModel: new URL("../VetMap/ViewModels/MapViewModel.swift", import.meta.url),
};

function declarationBody(source, signature) {
  const signatureIndex = source.indexOf(signature);
  assert.notEqual(signatureIndex, -1, `missing declaration: ${signature}`);
  const openingBrace = source.indexOf("{", signatureIndex);
  assert.notEqual(openingBrace, -1, `missing body: ${signature}`);

  let depth = 0;
  for (let index = openingBrace; index < source.length; index += 1) {
    if (source[index] === "{") depth += 1;
    if (source[index] === "}") depth -= 1;
    if (depth === 0) return source.slice(openingBrace + 1, index);
  }
  assert.fail(`unterminated body: ${signature}`);
}

test("carousel keeps stable IDs for every filtered directory clinic", async () => {
  const source = await readFile(paths.map, "utf8");
  const carousel = declarationBody(
    source,
    "private var clinicCarousel: some View",
  );

  assert.match(source, /ForEach\(viewModel\.mappableClinics\)/u);
  assert.match(carousel, /ForEach\(viewModel\.filteredClinics\)/u);
  assert.doesNotMatch(carousel, /ForEach\(viewModel\.mappableClinics\)/u);
  assert.match(carousel, /\.id\(clinic\.id\)/u);
  assert.match(carousel, /viewModel\.filteredClinics\.isEmpty/u);
  assert.match(
    carousel,
    /let carouselInset = max\(\(proxy\.size\.width - cardWidth\) \/ 2, 16\)/u,
  );
  assert.match(carousel, /\.padding\(\.horizontal, carouselInset\)/u);
  assert.doesNotMatch(carousel, /\.scrollPosition\s*\(/u);
  assert.doesNotMatch(carousel, /\.onScroll[A-Za-z]*\s*\(/u);
  assert.doesNotMatch(carousel, /selectedClinicID\s*=(?!=)/u);
});

test("selection changes only scroll a valid card to the center", async () => {
  const source = await readFile(paths.map, "utf8");
  const carousel = declarationBody(
    source,
    "private var clinicCarousel: some View",
  );
  const selectionChange = declarationBody(
    carousel,
    ".onChange(of: viewModel.selectedClinicID)",
  );
  const initialScroll = declarationBody(carousel, ".onAppear");
  const scrollHelper = declarationBody(
    source,
    "private func scrollToSelectedClinic(",
  );

  assert.match(carousel, /ScrollViewReader \{ scrollProxy in/u);
  assert.match(
    initialScroll,
    /scrollToSelectedClinic\(\s*viewModel\.selectedClinicID,\s*using: scrollProxy\s*\)/u,
  );
  assert.match(
    selectionChange,
    /scrollToSelectedClinic\(clinicID, using: scrollProxy\)/u,
  );
  assert.match(scrollHelper, /guard\s+let clinicID,/u);
  assert.match(
    scrollHelper,
    /viewModel\.filteredClinics\.contains\(where: \{ \$0\.id == clinicID \}\)/u,
  );
  assert.match(
    scrollHelper,
    /proxy\.scrollTo\(clinicID, anchor: \.center\)/u,
  );
  assert.doesNotMatch(
    `${selectionChange}\n${scrollHelper}`,
    /cameraPosition|viewModel\.focus\(|selectedClinicID\s*=(?!=)/u,
  );
});

test("card activation still focuses the corresponding map pin", async () => {
  const source = await readFile(paths.map, "utf8");
  const carousel = declarationBody(
    source,
    "private var clinicCarousel: some View",
  );
  const cardTap = declarationBody(carousel, ".onTapGesture");
  const accessibilityAction = declarationBody(
    carousel,
    ".accessibilityAction",
  );
  const focusHelper = declarationBody(source, "private func focusOnClinic(");

  assert.match(
    source,
    /Map\(position: \$viewModel\.cameraPosition, selection: \$viewModel\.selectedClinicID\)/u,
  );
  assert.match(source, /\.tag\(clinic\.id\)/u);
  assert.match(cardTap, /focusOnClinic\(clinic\)/u);
  assert.match(accessibilityAction, /focusOnClinic\(clinic\)/u);
  assert.match(focusHelper, /viewModel\.focus\(on: clinic\)/u);
  assert.match(carousel, /\.accessibilityAddTraits\(\.isButton\)/u);
});

test("list-only clinics remain safely selectable without a fake pin", async () => {
  const source = await readFile(paths.viewModel, "utf8");
  const focus = declarationBody(source, "func focus(on clinic: VetClinic)");
  const selectionIndex = focus.indexOf("selectedClinicID = clinic.id");
  const coordinateGuardIndex = focus.indexOf(
    "guard let coordinate = clinic.mapCoordinate else { return }",
  );

  assert.notEqual(selectionIndex, -1);
  assert.notEqual(coordinateGuardIndex, -1);
  assert.ok(
    selectionIndex < coordinateGuardIndex,
    "list-only cards must select before coordinate-dependent camera focus",
  );
  assert.doesNotMatch(focus, /clinic\.mapCoordinate!/u);
});

test("clinic cards expose selected state and useful VoiceOver context", async () => {
  const [mapSource, rowSource] = await Promise.all([
    readFile(paths.map, "utf8"),
    readFile(paths.row, "utf8"),
  ]);
  const accessibilityLabel = declarationBody(
    rowSource,
    "private var accessibilityLabel: String",
  );

  assert.match(mapSource, /availabilityDate: viewModel\.availabilityNow/u);
  assert.match(rowSource, /\.accessibilityElement\(children: \.contain\)/u);
  assert.match(rowSource, /\.accessibilityLabel\(accessibilityLabel\)/u);
  assert.match(
    rowSource,
    /\.accessibilityAddTraits\(isSelected \? \[\.isSelected\] : \[\]\)/u,
  );
  assert.match(
    accessibilityLabel,
    /clinic\.availabilityLabel\(at: availabilityDate\)/u,
  );
  assert.match(accessibilityLabel, /"營業狀態未提供"/u);
  assert.match(
    accessibilityLabel,
    /clinic\.distanceText\(from: currentLocation\)/u,
  );
  assert.match(accessibilityLabel, /clinic\.name/u);
  assert.match(rowSource, /if isSelected, let onOpenDetails/u);
});
