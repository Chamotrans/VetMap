# VetMap 8-hour autonomy log

## Round 1 — Availability filter coverage disclosure

- Started: 2026-08-02 (Asia/Taipei)
- Sol plan: Active availability filters can currently return only clinics with current official hours data. Add an explicit call-first disclosure so users do not interpret an omitted clinic as closed.
- Luna implementation:
  - Added `ClinicSearchFilter.Availability.limitationMessage`.
  - Displayed the message in the shared list/map `ClinicFilterControls` for `openNow`, `open24Hours`, and `nightService`; `.all` remains unchanged.
  - Added a focused unit test covering all four availability states.
- Sol acceptance: **ACCEPT** — no blocker and no P0/P1/P2 finding. Exact copy, shared list/map presentation, VoiceOver label, layout, scope, and tests reviewed.
- Local evidence: `swiftc -parse` passed for the three touched Swift files; `git diff --check` passed. No local `xcodebuild` was run.
- GitHub validation: `Backend and Config Validation` run `30716203346` completed successfully for commit `6296020`.
- Xcode Cloud: Build run 15 (`10b02aef-ca0c-454a-9203-dc04ed9b3385`) completed `SUCCEEDED`; `Archive - iOS` completed `SUCCEEDED`; processed build 15 (`4f5cf9dc-d677-475a-8750-85305b57fa41`) is `VALID`.
- Release boundary: Build 15 was not attached to App Store version 1.0 and no review submission or public release was performed.
- Production/backend note: No Firebase, registration, submissions, community, moderation, or release-state logic changed. A fresh local Firebase audit was not claimed because `gcloud` requires interactive reauthentication.
- Preserved scope: Existing user-owned dirty and untracked files were not staged, reverted, or modified by this round.

## Round 2 — Isolate malformed clinic documents

- Started: 2026-08-02 (Asia/Taipei)
- Fresh live evidence:
  - Anonymous approved reads returned clinics 180, reviews 1, and quotes 1.
  - The production audit's current Hong Kong catalog query returned products 124 and insurances 3, with shared expiry `2026-10-26T20:55:03.238Z`.
  - These are public-surface checks only; a full authoritative inventory/stray/metadata audit was not claimed because `gcloud` still requires interactive reauthentication.
  - Xcode Cloud Build 15 remained `SUCCEEDED`; ASC iOS 1.0 remained `READY_FOR_REVIEW` with Build 12 attached; the connected physical device `是條小狗` still had VetMap 1.0 (14).
- Sol plan: Prevent one malformed approved clinic document from making the full Firestore-backed list and map unavailable, without masking a total schema failure or introducing a bundled fallback.
- Luna implementation:
  - Added a generic, testable document decode helper that preserves valid document order and reports each individual failure.
  - Empty input returns empty; mixed input keeps valid results; non-empty all-invalid input reports every failure and then throws the first decode error.
  - Updated only `fetchClinics()` to use the helper while retaining its approved-status Firestore query and error behavior.
  - Logged only the failed Firestore document ID plus the existing recorded error; no document payload is logged.
  - Added focused tests for mixed, empty, and all-invalid inputs.
- Sol acceptance: **ACCEPT** — no P0/P1/P2 finding. Query authority, failure semantics, logging scope, test coverage, and unrelated behavior reviewed.
- Local evidence: Both touched Swift files passed `swiftc -parse`; `git diff --check` passed. No local `xcodebuild` was run.
- GitHub validation: `Backend and Config Validation` run `30716770691` completed successfully for commit `59d32d0`.
- Xcode Cloud: Build run 16 (`11e4cc73-6d5c-4ae7-be05-5400523d4f5c`) completed `SUCCEEDED`; its only action, `Archive - iOS`, completed `SUCCEEDED`; processed build 16 (`c4b9b1d2-eb49-4d0b-8b30-0483675a96b4`) is `VALID`. This proves compile/archive success; the workflow did not contain a test action, so XCTest execution is not claimed.
- Release boundary: No ASC build attachment, review submission, or public release was performed.
- Preserved scope: Registration, submissions, community interaction, moderation, all other collections, and existing user-owned dirty/untracked files were not changed by this round.

## Round 3 — Distinguish known closed from unknown hours

- Started: 2026-08-02 (Asia/Taipei)
- Fresh live evidence:
  - Public Firestore reads remained clinics 180, products 124, insurances 3, reviews 1, and quotes 1; the current commercial catalog expiry remained `2026-10-26T20:55:03.238Z`.
  - Xcode Cloud Build 16 and GitHub validation remained successful; ASC iOS 1.0 remained `READY_FOR_REVIEW` with Build 12 attached.
  - The connected physical device `是條小狗` still had VetMap 1.0 (14).
- Sol plan: Make a clinic with a current official schedule visibly distinct when it is known to be closed, while leaving missing, future, expired, or invalid schedule data as unknown.
- Luna implementation:
  - Updated `availabilityLabel(at:)` so a current ordinary closed state returns `休息中`.
  - Preserved `設夜診` for a current closed clinic with night service, plus all existing open and unavailable behavior.
  - Extended focused tests for scheduled open/closed transitions, closed night service, no availability, and expired availability.
- Sol acceptance: **ACCEPT** — no P0/P1/P2 finding. Current/unavailable boundaries, Hong Kong test times, shared badge styling and VoiceOver, scope, and regressions reviewed.
- Local evidence: Both touched Swift files passed `swiftc -parse`; `git diff --check` passed. No local `xcodebuild` was run.
- GitHub validation: `Backend and Config Validation` run `30717329278` completed successfully for commit `d90c623`.
- Xcode Cloud: Build run 17 (`b0dec185-c49c-400c-95cb-31eeb39f9ab8`) completed `SUCCEEDED`; its only action, `Archive - iOS`, completed `SUCCEEDED`; processed build 17 (`ce1ecfa9-305f-4435-a608-1cd932ed21bf`) is `VALID`. This proves compile/archive success; the workflow did not contain a test action, so XCTest execution is not claimed.
- Release boundary: No ASC build attachment, review submission, or public release was performed.
- Preserved scope: No filter, sorting, timer, Firestore, registration, submissions, community, moderation, or user-owned dirty/untracked file was changed by this round.

## Round 4 — Offline Hong Kong catalog integrity gate

- Started: 2026-08-02 (Asia/Taipei)
- Fresh live evidence:
  - Public Firestore reads remained clinics 180, products 124, insurances 3, reviews 1, and quotes 1; the current commercial catalog expiry remained `2026-10-26T20:55:03.238Z`.
  - Xcode Cloud Build 17 and GitHub validation remained successful; ASC iOS 1.0 remained `READY_FOR_REVIEW` with Build 12 attached.
  - The connected physical device `是條小狗` still had VetMap 1.0 (14).
- Sol plan: Add a read-only, offline CI gate that prevents the checked-in Hong Kong restore catalog from silently shrinking or drifting while still allowing synchronized expansion.
- Luna implementation:
  - Added a Node 22 built-ins-only validator for clinic count floors, unique clinic and lineage IDs, required identity/source fields, Hong Kong coordinates, exact report reconciliation, and exact missing-coordinate IDs.
  - Added availability-overlay validation for count floors, authorized clinic identity, Boolean flags, HTTPS sources, verification window ordering, weekday/time formats, full regular schedules, and non-empty 24-hour labels.
  - Added mutation tests for synchronized shrinkage, duplicate IDs/lineage, stale report coverage, missing/replaced coordinate details, orphan hours, unsafe hours metadata, invalid coordinates, and a valid synchronized 180th clinic expansion.
  - Integrated tests and real-manifest validation into the primary GitHub workflow before Firebase emulator checks.
- First Sol review: **RETURNED** — two P2 false-negative classes were found in report reconciliation and hours metadata validation.
- Luna correction: Made source coverage and missing-coordinate reconciliation exact; added hours Boolean/name/label checks and regression fixtures.
- Final Sol acceptance: **ACCEPT** — both P2 findings resolved with no new P0/P1/P2 finding.
- Local evidence: `node --check` passed for both scripts; Node tests passed 10/10; the real catalog passed with 179 clinics, 161 coordinates, 18 awaiting coordinates, 205 lineage IDs, and 11 hours overlays; `git diff --check` passed.
- GitHub validation: `Backend and Config Validation` run `30718060706` completed successfully for commit `069264a`, including the new `Validate Hong Kong clinic catalog integrity` step, Functions validation, Firebase emulator rules tests, and patch hygiene.
- Xcode Cloud: The normal main-branch trigger produced Build run 18 (`6e8a215f-d2e8-4bd4-b744-755d2b58c19c`), whose `Archive - iOS` action completed `SUCCEEDED`; processed build 18 (`cddd7d5f-390d-45d9-b05b-7059de5c4ca6`) is `VALID`. This is additional archive proof for a CI-only source change, not a release claim.
- Production boundary: The validator is offline and read-only. It does not replace the unavailable full authoritative Firestore inventory/stray/metadata audit.
- Release boundary: No ASC build attachment, review submission, or public release was performed.
- Preserved scope: No catalog data, migration, production, Swift, Firestore query, registration, submissions, community, moderation, or user-owned dirty/untracked file was changed by this round.

## Round 5 — Reconcile map selection on availability clock changes

- Started: 2026-08-02 (Asia/Taipei)
- Fresh live evidence:
  - The offline catalog validator and all 10 mutation tests still passed; public Firestore reads remained clinics 180, products 124, insurances 3, reviews 1, and quotes 1.
  - Xcode Cloud Build 18 and GitHub validation remained successful; ASC iOS 1.0 remained `READY_FOR_REVIEW` with Build 12 attached.
  - The physical device `是條小狗` was paired but not connected and still reported VetMap 1.0 (14), so no new runtime proof was claimed.
- Sol plan: When the availability clock removes the selected clinic from an active filter, reconcile the stale selection without moving the map camera.
- Luna implementation:
  - Added a pure selection reconciler covering empty, retained, missing, and invalid current selections.
  - Reused the reconciler in the existing filtered-selection synchronization path.
  - Updated each 60-second availability tick to set the new time first and then reconcile with camera focus disabled.
  - Preserved manual-filter camera focus and the existing post-load previous-selection behavior.
  - Added focused tests for the four pure cases and a Hong Kong 19:59 to 20:00 transition from a scheduled clinic to a still-open 24-hour clinic, plus the no-results case.
- Sol acceptance: **ACCEPT** — no P0/P1/P2 finding. Selection rules, timer ordering, camera guard, load/filter behavior, Hong Kong timestamps, and scope reviewed.
- Local evidence: Both touched Swift files passed `swiftc -parse`; `git diff --check` passed. No local `xcodebuild` was run.
- GitHub validation: `Backend and Config Validation` run `30718627686` completed successfully for commit `ef1eee3`, including the Hong Kong catalog gate, Functions validation, Firebase emulator rules tests, and patch hygiene.
- Xcode Cloud: Build run 19 (`f5fccf71-0e81-4601-be0e-cf3baa89e381`) completed `SUCCEEDED`; its only action, `Archive - iOS`, completed `SUCCEEDED`; processed build 19 (`20c9750a-f320-4599-a58f-49f0081d914e`) is `VALID`. This proves compile/archive success; the workflow did not contain a test action, so XCTest execution is not claimed.
- Release boundary: No ASC build attachment, review submission, or public release was performed.
- Preserved scope: No availability calculation, filter, sort, UI, Firestore, location, registration, submissions, community, moderation, or user-owned dirty/untracked file was changed by this round.

## Round 6 — Remove unsupported public clinic price presentation

- Started: 2026-08-02 (Asia/Taipei)
- Fresh live evidence:
  - Public Firestore still exposed 180 approved clinics, but 179 had `priceLevel = 0`; the only `priceLevel = 1` record was the non-real App Review demo. All 179 catalog-restored clinics intentionally carry no price classification.
  - Public catalog counts remained clinics 180, products 124, insurances 3, reviews 1, and quotes 1; the offline catalog gate remained 10/10 green.
  - Xcode Cloud Build 19 and GitHub validation remained successful; ASC iOS 1.0 remained `READY_FOR_REVIEW` with Build 12 attached.
  - The physical device `是條小狗` remained paired rather than connected and reported VetMap 1.0 (14), so no new runtime proof was claimed.
- Sol plan: Remove the unsupported clinic price filter and `$` badges from public browsing so the demo record cannot be mistaken for representative Hong Kong price coverage.
- Luna implementation:
  - Removed the price menu from the shared clinic filter controls.
  - Removed price badges from list detail, slim list, grid, map carousel, and clinic detail header presentations.
  - Kept map tag layout conditional so removing the price badge does not leave an empty row.
  - Preserved the model, filter schema/logic, backend, restore/audit, and community clinic-submission price field for compatibility.
- Sol acceptance: **ACCEPT** — no P0/P1/P2 finding. Public-view coverage, layout, accessibility, availability/search/navigation behavior, schema compatibility, and dirty-file scope reviewed.
- Local evidence: All five touched Swift files passed `swiftc -parse`; scoped `rg` found no public browsing price UI; `git diff --check` passed. No local `xcodebuild` was run.
- GitHub validation: `Backend and Config Validation` run `30719149139` completed successfully for commit `2276cd0`, including the Hong Kong catalog gate, Functions validation, Firebase emulator rules tests, and patch hygiene.
- Xcode Cloud: Build run 20 (`1bff0581-b33f-4574-bbd5-1cc4ceb1116d`) completed `SUCCEEDED`; its only action, `Archive - iOS`, completed `SUCCEEDED`; processed build 20 (`2750941a-737a-4c16-b032-9cdccbe884a6`) is `VALID`. This proves compile/archive success; the workflow did not contain a test action, so XCTest execution is not claimed.
- Release boundary: No ASC build attachment, review submission, or public release was performed.
- Preserved scope: No catalog, product pricing, IAP, quote, availability, Firestore, registration, submissions, community, moderation, or user-owned dirty/untracked file was changed by this round.

## Round 7 — Explain clinics awaiting reliable map coordinates

- Started: 2026-08-02 (Asia/Taipei)
- Fresh live evidence:
  - The checked-in Hong Kong catalog remained 179 clinics: 161 with reliable map coordinates and 18 awaiting coordinates; all 179 remain available in the directory.
  - Public catalog counts remained clinics 180, products 124, insurances 3, reviews 1, and quotes 1; the offline catalog gate remained 10/10 green.
  - Xcode Cloud Build 20 and GitHub validation remained successful; ASC iOS 1.0 remained `READY_FOR_REVIEW` with Build 12 attached.
  - The physical device `是條小狗` remained paired rather than connected and reported VetMap 1.0 (14), so no new runtime proof was claimed.
- Sol plan: Explain the dynamic difference between directory results and reliable map markers without hiding clinics or inventing coordinates.
- Luna implementation:
  - Added a pure defensive pending-location counter that clamps malformed negative differences to zero.
  - Derived the pending count dynamically from the currently filtered directory and mappable clinic sets, so it follows search, availability, and region filters.
  - Added a conditional, multiline, VoiceOver-labelled map notice directing users to the directory for clinics whose locations await confirmation.
  - Preserved reliable-coordinate-only markers, the complete filtered directory carousel, camera and selection behavior, filters, navigation, and backend behavior.
  - Added focused tests for the current 179/161 split, zero difference, and defensive clamping.
- Sol acceptance: **ACCEPT** — no P0/P1/P2 finding. Dynamic filtering, zero/no-result behavior, copy, accessibility, marker/carousel sources, navigation, backend scope, and tests reviewed.
- Local evidence: All three touched Swift files passed `swiftc -parse`; targeted source checks and scoped `git diff --check` passed. No local `xcodebuild` was run.
- GitHub validation: `Backend and Config Validation` run `30719655599` completed successfully for commit `c0b0bc2`, including the Hong Kong catalog gate, Functions validation, Firebase emulator rules tests, and patch hygiene.
- Xcode Cloud: Build run 21 (`dfad5c5a-7a77-4dbe-9560-f8a2781a911e`) completed `SUCCEEDED`; its only action, `Archive - iOS` (`738c7e49-1045-456c-8408-97e3011448ad`), completed `SUCCEEDED`; processed build 21 (`9a1ec901-4875-4a0f-8307-63191dac99a1`) is `VALID`. This proves compile/archive success; the workflow did not contain a test action, so XCTest execution is not claimed.
- Release boundary: No ASC build attachment, review submission, or public release was performed.
- Preserved scope: No coordinates, catalog data, Firestore, registration, submissions, community, moderation, or user-owned dirty/untracked file was changed by this round.

## Round 8 — Preserve a truthful public Firestore audit without admin credentials

- Started: 2026-08-02 (Asia/Taipei)
- Fresh live evidence:
  - The offline catalog validator and all 10 mutation tests remained green at 179 clinics, 161 coordinates, 18 list-only clinics, 205 authorized lineage records, and 11 availability overlays.
  - Anonymous reads showed clinics 180, reviews 1, quotes 1, products 124, and insurances 3; the commercial catalog shared expiry remained `2026-10-26T20:55:03.238Z`.
  - GitHub validation and Xcode Cloud Build 21 remained successful; ASC iOS 1.0 remained `READY_FOR_REVIEW` with Build 12 attached.
  - The physical device `是條小狗` remained paired rather than connected and reported VetMap 1.0 (14), so no new runtime proof was claimed.
  - The full production audit remained unavailable because local gcloud credentials require interactive reauthentication; the previous script exited before performing even its anonymous checks when no bearer token was present.
- Sol plan: Add an explicit public-only audit mode that proves the complete anonymous user-visible surface without weakening or silently downgrading the full authoritative inventory audit.
- Luna implementation:
  - Added strict CLI handling for either full mode with no argument or exactly `--public-only`; unknown, repeated, and extra arguments fail.
  - Kept full mode token-required and preserved its bearer inventory plus exact anonymous-versus-authoritative ID comparison.
  - Made public-only mode skip only the bearer inventory comparison while retaining clinic, availability, commercial catalog, metadata, expiry, price-safety, and anonymous-denial checks.
  - Added machine-readable mode and authority fields plus an explicit warning that public-only cannot detect hidden-query, different-expiry, or stray documents.
  - Documented separate full and public-only commands and their evidence boundaries.
- Sol acceptance: **ACCEPT** — no P0/P1/P2 finding. CLI strictness, full-mode preservation, public-only coverage, read-only behavior, warning clarity, documentation, and dirty-file scope reviewed.
- Local evidence: `node --check` passed; tokenless full mode, unknown arguments, and extra arguments failed as required; tokenless live public-only audit passed with clinics 180 (179 catalog plus demo), 161/18 map coverage, 205 lineage records, 11 availability entries including 10 24-hour entries, reviews 1, quotes 1, products 124, insurances 3, and all anonymous denial checks. Catalog tests remained 10/10 and the real validator remained `179/161/18/205/11`; scoped `git diff --check` passed.
- Authority boundary: Full live inventory comparison was not rerun because gcloud still requires interactive reauthentication. Public-only evidence is not an authoritative no-stray-document claim.
- GitHub validation: `Backend and Config Validation` run `30720288430` completed successfully for commit `7a51338`, including the Hong Kong catalog gate, Functions validation, Firebase emulator rules tests, and patch hygiene.
- Xcode Cloud: Build run 22 (`e53fb5d0-e4d9-496d-baf5-86529e96262a`) completed `SUCCEEDED`; its only action, `Archive - iOS` (`e7d82574-e235-4704-8d59-bbef7e2d67e0`), completed `SUCCEEDED`; processed build 22 (`89521c4f-ca5c-4560-b121-158396fff5d7`) is `VALID`. This proves compile/archive success; the workflow did not contain a test action, so XCTest execution is not claimed.
- Release boundary: No ASC build attachment, review submission, or public release was performed.
- Preserved scope: No catalog data, Firestore write/rules/backend, registration, submissions, community, moderation, device app, or user-owned dirty/untracked file was changed by this round.

## Round 9 — Correct the clinic directory provenance disclosure

- Started: 2026-08-02 (Asia/Taipei)
- Fresh live evidence:
  - The public-only production audit remained green at clinics 180 (179 authorized catalog plus one demo), 161 mappable and 18 list-only clinics, 205 authorized lineage records, 11 availability entries including 10 24-hour entries, reviews 1, quotes 1, products 124, and insurances 3.
  - The 179 catalog clinics identify the source as the authorized VetMap Hong Kong clinic database and the rights basis as owner-confirmed in-house creation or licensed use.
  - The main clinic list nevertheless described the directory as entirely community-submitted, while the profile disclosure correctly described it as created by or licensed to VetMap.
  - GitHub validation and Xcode Cloud Build 22 remained successful; ASC iOS 1.0 remained `READY_FOR_REVIEW` with Build 12 attached.
  - The physical device `是條小狗` remained paired rather than connected; its app inventory still reported VetMap 1.0 (14), so no new runtime proof was claimed.
- Sol plan: Correct the primary clinic browsing provenance disclosure so the authorized directory and reviewed community submissions are both represented truthfully.
- Luna implementation:
  - Changed the clinic-list header to identify the Hong Kong veterinary clinic directory.
  - Explained that current official opening information is shown when available while community submissions are published after review.
  - Replaced the inaccurate all-community footer with the established created-or-licensed VetMap directory disclosure and added multiline centered layout.
  - Added exact English and Simplified Chinese translations for all three new source strings and removed the three obsolete misleading localization keys.
  - Preserved add-clinic controls, login continuation, submissions, moderation, reviews, quotes, and reporting flows.
- Sol acceptance: **ACCEPT** — no P0/P1/P2 finding. Rights provenance, community preservation, copy, small-screen layout, localization, feature-flow scope, and backend boundaries reviewed.
- Local evidence: The Swift view passed `swiftc -parse`; the string catalog passed `jq empty`; all three English and Simplified Chinese translations and states matched exactly; the source language remained `zh-Hant`; obsolete keys were absent; scoped `git diff --check` passed. No local `xcodebuild` was run.
- GitHub validation: `Backend and Config Validation` run `30720829247` completed successfully for commit `238f3ba`, including the Hong Kong catalog gate, Functions validation, Firebase emulator rules tests, and patch hygiene.
- Xcode Cloud: Build run 23 (`0bf123b8-29d4-4ff2-92a6-008909f82a7d`) completed `SUCCEEDED`; its only action, `Archive - iOS` (`51e29655-5a29-4ab4-acb0-cb87db96c8b5`), completed `SUCCEEDED`; processed build 23 (`17a142c5-bca5-419c-afb6-4386739f8a64`) is `VALID`. This proves compile/archive and string-catalog resource success; the workflow did not contain a test action, so XCTest execution is not claimed.
- Release boundary: No ASC build attachment, review submission, or public release was performed.
- Preserved scope: No clinic records, availability, Firestore, registration, submissions, community behavior, moderation, ASC state, device app, or user-owned dirty/untracked file was changed by this round.

## Round 10 — Prepare four additional official availability records

- Started: 2026-08-02 (Asia/Taipei)
- Fresh live evidence:
  - Production remained at 11 availability overlays, including 10 24-hour entries; the public-only production audit, offline catalog gate, GitHub validation, and Xcode Cloud Build 23 remained green.
  - ASC iOS 1.0 remained `READY_FOR_REVIEW` with Build 12 attached, while the paired physical device `是條小狗` still reported VetMap 1.0 (14).
  - Official primary pages directly documented Pets Central Mong Kok as a 24-hour veterinary service, Pets Central Tseung Kwan O as open daily 08:30–20:30, Southside Vets weekday/weekend hours, and Trinity Vets weekday/Sunday hours with a 13:00–14:00 lunch closure.
- Sol plan: Create an explicitly pending v2 availability delta for those four clinics, with a source-only validation gate and no production deployment.
- Luna implementation:
  - Added a pending manifest with exact clinic identities, official HTTPS sources, canonical schedules, call-first notes, a 2026-10-31 expiry, and `deploymentStatus: pending`.
  - Planned coverage becomes 15 overlays: 11 24-hour and 4 scheduled, while the deployed v1 manifest remains unchanged at 11/10.
  - Added a validator that combines deployed v1 and pending v2 through the existing structural integrity validator, then pins exact IDs, catalog names, URLs, schedules, service notes, counts, and pending status.
  - Added mutation tests for IDs, v1 overlap, names, official URLs, weekday/time drift, Trinity lunch intervals, Pets Central 24-hour status, deployment status, and contradictory service notes.
  - Added only the pending validator and tests to the primary GitHub workflow; no restore, token, deploy, or write command was added.
- First Sol review: **RETURNED** — one P2 false-negative allowed canonical call-first and public-holiday service notes to be contradicted while CI stayed green.
- Luna correction: Added all four exact service notes to canonical comparison and regression tests for contradictory Pets Central and scheduled-clinic notes.
- Final Sol acceptance: **ACCEPT** — the P2 was resolved with no new P0/P1/P2 finding.
- Local evidence: New pending tests passed 7/7; the pending validator returned `deploymentStatus: pending`, `productionApplied: false`, pending 4, planned total 15, planned 24-hour 11, and planned scheduled 4. Existing catalog tests remained 10/10 with deployed baseline `179/161/18/205/11`; all three Node files passed syntax checks and scoped patch hygiene passed. No local `xcodebuild` was run.
- Production boundary: This round did not alter the deployed v1 manifest, restore tooling, public audit expectations, or Firestore. Production availability remains 11 overlays, including 10 24-hour entries.
- GitHub validation: `Backend and Config Validation` run `30721739657` completed successfully for commit `b14a736`, including the deployed catalog gate, the new pending hours v2 validator and seven mutation tests, Functions validation, Firebase emulator rules tests, and patch hygiene.
- Xcode Cloud: Build run 24 (`ddfb0424-374f-4a4d-a6d1-7cec3b553818`) completed `SUCCEEDED`; its only action, `Archive - iOS` (`6e98fc5c-8f7a-45db-af2d-547ec4714aa9`), completed `SUCCEEDED`; processed build 24 (`66d6fd8a-b1e1-4713-92a2-f09f35219d74`) is `VALID`. This proves compile/archive success; the workflow did not contain a test action, so XCTest execution is not claimed.
- Release boundary: No ASC build attachment, review submission, or public release was performed.
- Preserved scope: No production data, registration, submissions, community behavior, moderation, ASC state, device app, or user-owned dirty/untracked file was changed by this round.

## Round 11 — Add a production-safe clinic-hours v2 migration runner

- Started: 2026-08-02 (Asia/Taipei)
- Fresh evidence before implementation:
  - The public-only Firestore audit remained at clinics 180 (179 authorized catalog plus one demo), 161 mappable and 18 list-only clinics, 205 authorized lineage records, 11 deployed availability entries including 10 24-hour entries, reviews 1, quotes 1, products 124, and insurances 3.
  - The checked-in v2 plan remained explicitly pending: four additional records, planned total 15, planned 24-hour 11, planned scheduled 4, and `productionApplied: false`.
  - GitHub validation and Xcode Cloud Build 24 remained successful; ASC iOS 1.0 remained `READY_FOR_REVIEW` with Build 12 attached. The paired physical device `是條小狗` remained available with VetMap 1.0 (14), but no new runtime proof was claimed.
- Sol plan: Add a fail-closed, idempotent migration runner whose default mode performs only an authoritative dry-run and backup, while keeping any future production write behind an explicit `--apply` flag and atomic optimistic-concurrency checks.
- Luna implementation:
  - Added strict CLI parsing, mandatory pending-manifest validation before network access, paginated authoritative Firestore decoding, canonical normalized comparisons, and exact preflight checks for the deployed v1 `11/10/1` overlay plus the four approved Hong Kong v2 targets.
  - Rejected v1 drift, renamed or non-approved targets, region drift, unexpected availability outside the planned 15 IDs, and any partially applied or non-canonical v2 state.
  - Added a raw four-target backup with mode `0600`, SHA-256 reporting, and no token or document payload in stdout.
  - Prepared a future apply path using one atomic four-write `documents:commit`; each write updates only `availability` and carries the target document's `updateTime` precondition. Commit failures and post-read mismatches fail closed.
  - Required an authoritative post-read proving exact canonical coverage and `15/11/4` before reporting `productionApplied: true`; an already-canonical state is an idempotent zero-write path.
  - Added the mocked runner suite to the primary GitHub workflow without credentials, production network access, or persistent backup artifacts.
- First Sol review: **RETURNED** — one P2 found that a successful fresh apply would report post-write success beside pre-write `current*` counts, and one P3 found that tests did not exercise the real backup writer's file mode, content boundary, or digest.
- Luna correction: Successful apply output now uses the verified post-read `15/11/4` counts; a temporary-file test now verifies the exact four-document raw backup wrapper, `updateTime` preservation, `0600` mode, and independently recomputed SHA-256.
- Final Sol acceptance: **ACCEPT** — both findings resolved with no remaining P0–P3 actionable finding.
- Local evidence: Runner tests passed 20/20; combined runner, pending-plan, and catalog-integrity tests passed 37/37; both Node files passed syntax checks; both validator CLIs passed; and `git diff --check` passed. No local `xcodebuild` was run.
- Live-run boundary: No authoritative live dry-run was claimed because the local Google credentials still require interactive reauthentication. No `--apply`, Firestore write, or production backup was performed; deployed availability remains 11/10/1 and the v2 manifest remains pending.
- Release boundary: Commit-specific GitHub and Xcode Cloud validation is pending. No ASC build attachment, review submission, public release, or device app change was performed.
- Preserved scope: Registration, submissions, community interaction, moderation, Firebase rules, all production records, and all user-owned dirty/untracked files were preserved.
