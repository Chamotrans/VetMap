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
- GitHub validation: `Backend and Config Validation` run `30722671583` completed successfully for commit `cdb0e53`, including the new pending v2 restore-runner suite, catalog gates, Functions validation, Firebase emulator rules tests, and patch hygiene.
- Xcode Cloud: GitHub's Apple Xcode Cloud check confirmed commit-specific build run `789b9c0d-abd1-4efe-b0d2-0d4e172f0dab` and its only action, `Archive - iOS` (`318c6fa6-6105-465c-ab6f-ca92ab53e55a`), completed successfully. Processed-build validity was not independently available from the expired ASC session, and no local `xcodebuild` was substituted.
- Device evidence: The physical iPhone `是條小狗` was booted, paired, and visible over the local network; its installed VetMap remained version 1.0, build 14. No installation or runtime smoke test was performed this round.
- Release boundary: No ASC build attachment, review submission, public release, or device app change was performed.
- Preserved scope: Registration, submissions, community interaction, moderation, Firebase rules, all production records, and all user-owned dirty/untracked files were preserved.

## Round 12 — Add a deploy-aware availability audit transition

- Started: 2026-08-02 (Asia/Taipei)
- Fresh live evidence:
  - The public-only audit passed with 180 approved clinics: 179 authorized Hong Kong catalog entries plus one demo, 161 mappable and 18 list-only clinics, 205 authorized lineage records, and deployed availability still exactly `11/10/1`.
  - Reviews 1, quotes 1, products 124, insurances 3, and all anonymous denial checks remained green. The v2 plan remained pending at four additions and planned `15/11/4`, with `productionApplied: false`.
  - GitHub run `30722671583` was successful for Round 11; the corresponding Xcode Cloud archive check was still in progress. The physical iPhone `是條小狗` remained paired over the local network with VetMap 1.0 (14).
- Sol plan: Add an explicit audit-state transition so today's production remains fail-closed at deployed v1, while a future v2 apply can be independently proven only by a full authenticated audit showing exact public and authoritative parity at `15/11/4`.
- Luna implementation:
  - Added a strict, order-independent `--availability-state deployed-v1|post-apply-v2` selector; default remains `deployed-v1`, while `post-apply-v2` is forbidden with `--public-only`.
  - Validated the selected catalog and availability manifests before the first network call and built exact per-clinic expectations with the correct v1 and v2 migration IDs, normalized timestamps, schedules, service notes, sources, expiry, and every availability field.
  - Preserved today's exact `11/10/1` production expectation; the future selector requires exact merged `15/11/4` and does not perform a migration or change manifest state.
  - Extended full mode to compare authenticated approved clinic IDs with anonymous approved IDs, retain the 179-HK-plus-demo boundary, and verify exact public and authoritative availability contents.
  - Emitted `availabilityStateVerified: true` only after all existing catalog, products, insurances, and anonymous-denial gates complete; machine output includes the selected state and public/authenticated availability summaries.
  - Added pure and mocked regression coverage and integrated it into the primary GitHub workflow without credentials, network access, or production mutation.
- First Sol review: **RETURNED** — one P2 found that the full audit filtered authoritative clinics to `approved` before checking stray availability, allowing a non-approved document outside the plan to escape detection.
- Luna correction: The full unfiltered authoritative clinic inventory is now checked for availability outside the selected plan before the approved subset is used for public parity. A regression test proves rejected stray availability fails while rejected documents without availability do not pollute approved parity.
- Final Sol acceptance: **ACCEPT** — the P2 was resolved with no remaining P0–P3 actionable finding.
- Local evidence: The audit-state suite passed 17/17; combined audit, runner, pending-plan, and catalog-integrity tests passed 54/54; all three Node files passed syntax checks; both validator CLIs and `git diff --check` passed. The default public-only live audit completed successfully at `11/10/1` with `availabilityStateVerified: true`. No local `xcodebuild` was run.
- Authority boundary: Full authenticated audit was not run because local Google credentials still require interactive reauthentication. The post-apply-v2 production command was deliberately not run because production is correctly still v1.
- GitHub validation: `Backend and Config Validation` run `30723286330` completed successfully for commit `8a49221`, including the new audit-state suite, runner and manifest gates, Functions validation, Firebase emulator rules tests, and patch hygiene.
- Xcode Cloud boundary: GitHub's Apple Xcode Cloud check confirmed build run `412bf7cd-2352-4f5d-a3b7-e5787def976b` and its only action, `Archive - iOS` (`90948b41-46b8-49cd-82f9-6360af090ae6`), were in progress. Completion and processed-build validity are not yet claimed.
- Production and release boundary: No runner `--apply`, Firestore write, backup, Firebase deploy, manifest-status change, ASC build attachment, review submission, public release, or device-app change was performed.
- Preserved scope: Registration, submissions, community interaction, moderation, and all user-owned dirty/untracked files were preserved.

## Round 13 — Fail closed on semantically unsafe clinic availability

- Started: 2026-08-02 (Asia/Taipei)
- Fresh live evidence:
  - The default public-only audit remained verified at deployed v1 `11/10/1`; the v2 plan remained pending at four additions and planned `15/11/4`.
  - GitHub run `30723286330` remained successful. Its Xcode Cloud build run `412bf7cd-2352-4f5d-a3b7-e5787def976b` and only `Archive - iOS` action (`90948b41-46b8-49cd-82f9-6360af090ae6`) were still in progress and were not treated as success.
  - The physical iPhone `是條小狗` was booted, paired, and tunnel-connected over the local network; its installed VetMap remained version 1.0, build 14. No new runtime proof was claimed.
- Sol plan: Add one production app-side semantic gate so a type-correct but unsafe availability payload cannot display `營業中`, `24 小時`, or `夜診`, while the clinic remains available in the complete unfiltered directory.
- Luna implementation:
  - Expanded the shared `ClinicAvailability.isCurrent(at:)` contract so every existing operating-status, badge, detail, sorting, and filter path fails closed through one predicate.
  - Required schema version 1, a safe `hk-clinic-hours-…` migration identifier, exact `Asia/Hong_Kong`, a current ordered verification window no longer than 100 days, an HTTPS source host, and visibly meaningful source name and service note.
  - Required coherent 24-hour records: night service enabled, a visible label, and no recurring schedule. Scheduled records require exactly seven weekday keys, canonical ASCII `HH:mm`, unequal endpoints, and no overlap across same-day, overnight, or week-wrap intervals.
  - Added formal XCTest coverage and normalized scheduled test fixtures, but did not claim XCTest execution because the current Xcode Cloud workflow contains only an Archive action.
  - Added a standalone semantic harness that compiles the actual production `ClinicCoordinate`, `VetClinic`, and `ClinicSearchFilter` sources; it exercises supported schedules, temporal boundaries, metadata mutations, Unicode attacks, cyclic overlaps, the three active filters, and `.all` directory preservation.
  - Integrated that harness into the existing Xcode Cloud post-clone script after Firebase configuration validation, so a non-zero semantic check blocks the Archive action without changing the ASC workflow.
- First Sol review: **RETURNED** — one P1 found a five-byte adversarial Unicode time string could trap through mixed UTF-8/Character indexing; two P2 findings found invisible format-only metadata could pass and the standalone harness did not compile or exercise the production filters.
- Luna correction:
  - Replaced Character indexing with exact five-byte ASCII parsing and added emoji, full-width digit, and format-control mutations.
  - Required visible alphanumeric metadata and a safe ASCII migration suffix, rejecting word-joiner and BOM-only values.
  - Compiled `ClinicSearchFilter.swift` into the harness and proved each invalid payload is excluded from `openNow`, `open24Hours`, and `nightService`, while `.all` retains the clinic. Exact 100 days passes; 100 days plus one second fails.
- Final Sol source acceptance: **SOURCE ACCEPT** — all P1/P2 findings resolved with no new P0–P3 actionable finding. Final external acceptance remains conditional on Xcode Cloud executing the post-clone harness and completing Archive successfully.
- Local evidence: The production-source harness returned `{"count":39,"passed":true}`; `sh -n`, Node regression tests 54/54, both validator CLIs, and `git diff --check` passed. This was a standalone host Swift compile/run, not a local iOS build; no local `xcodebuild` was run.
- Test boundary: Formal `VetMapTests` XCTest cases were added but not executed by the current Archive-only Cloud workflow, so no XCTest pass is claimed.
- GitHub validation: `Backend and Config Validation` run `30724132718` completed successfully for commit `53146c4`, including catalog/audit/runner gates, Functions validation, Firebase emulator rules tests, and patch hygiene.
- Xcode Cloud boundary: GitHub's Apple Xcode Cloud check confirmed build run `4ffe2fee-65d5-4b10-ad30-e413923188c3` and its only action, `Archive - iOS` (`0979fd9f-2237-4277-bd4d-158b3ff0f5ef`), were in progress. The post-clone harness and Archive completion were not yet externally accepted; processed-build validity and XCTest execution are not claimed.
- Production and release boundary: No availability data, runner `--apply`, Firestore write, Firebase deploy, ASC workflow/edit/build attachment/review submission, public release, or device-app change was performed.
- Preserved scope: Registration, submissions, community interaction, moderation, manifests, and all user-owned dirty/untracked files were preserved.

## Round 14 — Prove real manifests are compatible with production Swift semantics

- Started: 2026-08-02 (Asia/Taipei)
- Fresh live evidence:
  - The public-only production audit remained verified at deployed v1 `11/10/1`; the v2 manifest remained pending at four additions and planned `15/11/4`.
  - GitHub run `30724132718` remained successful. Xcode Cloud runs for commits `8a49221` and `53146c4` both remained `in_progress` without annotations or failures; the older stalled run predates the Round 13 semantic harness, so no source causality was inferred.
  - The physical iPhone `是條小狗` was booted, paired, and tunnel-connected, with VetMap 1.0 (14) still installed. No runtime smoke or installation was performed.
- Sol plan: Add a cross-layer gate that reads the actual deployed v1 and pending v2 manifests, projects every entry exactly as the migration runner would, and proves those records remain accepted by the production Swift availability and filter semantics.
- Luna implementation:
  - Added a standalone Swift harness that decodes the actual `hk_clinic_hours_v1.json` and `hk_clinic_hours_v2.pending.json` files supplied by CLI path; no embedded availability fixtures are used.
  - Projected schema, timezone, dates, weekly hours, flags, labels, caveats, and sources field-for-field. v1 uses `hk-clinic-hours-v1-2026-07-30`; v2 uses its pinned top-level migration ID.
  - Used the later manifest verification time as a deterministic common reference and required it to precede both expiries.
  - Proved unique, non-overlapping IDs and exact distributions: v1 `11/10/1`, pending v2 `4/1/3`, merged `15/11/4`.
  - Proved every projected entry is current under production Swift semantics; every 24-hour entry preserves its exact caveat label, while scheduled entries remain excluded from the 24-hour and night-service filters.
  - Proved merged production filter counts at the common Hong Kong midnight: all 15, 24-hour 11, night service 11, and open now 11.
  - Added the compatibility binary after the Round 13 semantic binary in the Xcode Cloud post-clone gate. Either non-zero exit blocks Archive; success explicitly reports `manifestCompatibility: true` beside `productionApplied: false`.
- First Sol review: **RETURNED** — one P2 found that scheduled runtime probing selected only the first interval, so Trinity's afternoon opening and lunch closure could regress while the harness stayed green.
- Luna correction: Every one of the 35 actual scheduled intervals is now probed at its midpoint for open status and an open label. All seven non-zero same-day gaps are probed as closed with no open label, locking Trinity's daily 13:00–14:00 lunch closure; overnight intervals are excluded from incorrect same-day gap inference.
- Final Sol source acceptance: **SOURCE ACCEPT** — the P2 was resolved with no new P0–P3 actionable finding. External Xcode Cloud execution remains pending.
- Local evidence:
  - Round 13 production semantic harness: `{"count":39,"passed":true}`.
  - Actual-manifest compatibility: v1 `11/10/1`, v2 `4/1/3`, merged `15/11/4`, filters `15/11/11/11`, scheduled probes `35/7`, `manifestCompatibility: true`, and `productionApplied: false`.
  - `sh -n`, Node tests 54/54, both validator CLIs, and `git diff --check` passed. These were standalone host Swift checks, not a local iOS build; no local `xcodebuild` or XCTest execution was claimed.
- Production and release boundary: No manifest or availability data, runner `--apply`, Firestore write, Firebase deploy, ASC workflow/build attachment/review submission, public release, or device-app change was performed.
- GitHub validation: `Backend and Config Validation` run `30724669063` completed successfully for commit `a64d4c5`, including catalog/audit/runner gates, Functions validation, Firebase emulator rules tests, and patch hygiene.
- Xcode Cloud boundary: GitHub's Apple Xcode Cloud check confirmed build run `ca5e34a9-2e81-4458-aa57-bbae2f1a992b` and its only action, `Archive - iOS` (`0850f430-5c6d-4d78-ad9c-f711341c08a4`), were in progress. The post-clone dual-harness output, Archive completion, processed-build validity, and XCTest execution are not yet claimed.
- Preserved scope: Registration, submissions, community interaction, moderation, and all user-owned dirty/untracked files were preserved.

## Round 15 — Add a structured clinic-availability feedback loop

- Started: 2026-08-02 (Asia/Taipei)
- Fresh live evidence:
  - The public-only production audit remained verified at deployed v1 `11/10/1`; the v2 manifest remained pending with four additions and planned `15/11/4`, with `productionApplied: false`.
  - Xcode Cloud Archive checks for Round 12 (`8a49221`) and Round 13 (`53146c4`) completed successfully, proving the deploy-aware audit and production Swift semantic post-clone gate compiled and archived. Round 14 (`a64d4c5`) remained `in_progress` and was not treated as success.
  - The physical iPhone `是條小狗` remained booted, paired, local-network and tunnel connected, with VetMap 1.0 installed. No runtime action or production report was performed.
- Sol plan: Add a dedicated `回報營業資料` path for current verified availability, reusing the existing clinic-report moderation flow without adding a collection, schema, or Firestore-rule change.
- Luna implementation:
  - Added a current-data-only reason matrix: three base availability reasons, plus `並非24小時` for 24-hour records and `夜診／急症服務有變` for night-service records.
  - Added a fixed report payload containing the selected reason, migration ID, source name, and verified date; it removes controls, newlines, field delimiters, URLs, bare domains, and phone-like source names, excludes source URLs, and caps the payload at 500 characters.
  - Added the availability feedback dialog to the verified opening-hours card and reused `ClinicDetailViewModel.reportClinic(reason:)`; no new Firebase path was introduced.
  - Enforced the existing backend invariant of one active report per user and clinic by sharing submission and completion state between the general clinic-report and availability-feedback entries. A successful report disables both entries; failed reports retain retry and surface the existing `storageError`.
  - Added production-model XCTest coverage and a standalone production-source feedback harness to the Xcode Cloud post-clone gate. The new model was added only to the VetMap app target; tests access it through `@testable import VetMap`.
- First Sol review: **RETURNED** — one P1 found both report entries could race or sequentially write the same deterministic report document, whose second client update is denied by rules; one P2 found bare domains, punctuated phone numbers, and the full-width field delimiter could bypass source-name sanitization.
- Luna correction: Both report entries now share one guarded submit path and one completed state; the sanitizer rejects bare domains and phone-like values across punctuation and strips both ASCII and full-width field delimiters. Regression coverage includes `clinic.example.com`, slash/dot/parenthesized/`+852` phone forms, and delimiter injection.
- Final Sol source acceptance: **ACCEPT** — both findings were resolved with no remaining actionable finding. Full SwiftUI compilation remains conditional on Xcode Cloud Archive completion.
- Local evidence:
  - Availability feedback production harness: `{"clinicAvailabilityFeedback":true,"passed":22}`.
  - Availability semantic harness: `{"count":39,"passed":true}`.
  - Actual-manifest compatibility remained v1 `11/10/1`, v2 `4/1/3`, merged `15/11/4`, filters `15/11/11/11`, scheduled probes `35/7`, `manifestCompatibility: true`, and `productionApplied: false`.
  - Node regression tests passed 54/54; catalog integrity remained `179/161/18/205/11`; the pending validator remained four additions and planned `15/11/4`; `sh -n`, project `plutil`, and `git diff --check` passed.
  - These were standalone host Swift checks, not a local iOS build. No local `xcodebuild` or XCTest execution was claimed.
- GitHub validation: `Backend and Config Validation` run `30725508945` completed successfully for the Round 15 source and regression gates.
- Xcode Cloud validation: Build run `8dedffd1-e5a8-4da0-882a-8af66f51f4dc` and its `Archive - iOS` action (`dff8ef1c-1449-4ba0-84d8-a6fb88ac0021`) completed successfully, externally proving the Round 15 production feedback model and post-clone harness compiled before Archive. This does not claim XCTest execution, processed-build validity, ASC attachment, review submission, public release, or device installation.
- Production and release boundary: No report was submitted, no availability data or manifest was changed, no runner `--apply`, Firestore write, Firebase deploy, ASC workflow/build attachment/review submission, public release, or device-app change was performed.
- Preserved scope: Registration, submissions, community interaction, general clinic reporting, moderation, and all user-owned dirty/untracked files were preserved.

## Round 16 — Fail-closed admin triage for availability feedback

- Started: 2026-08-02 (Asia/Taipei)
- Fresh external evidence:
  - Round 15 GitHub run `30725508945` completed successfully.
  - Round 15 Xcode Cloud build run `8dedffd1-e5a8-4da0-882a-8af66f51f4dc` and `Archive - iOS` action `dff8ef1c-1449-4ba0-84d8-a6fb88ac0021` completed successfully.
- Sol plan: Add a strict Foundation-only parser and classifier for clinic availability reports, then give admins a non-destructive verification workflow without changing the existing moderation schema or general clinic, review, and quote handling.
- Luna implementation:
  - Added a strict three-way classifier: valid fixed-format clinic availability reports become structured tickets, any clinic report using the reserved availability prefix but failing validation becomes malformed, and all other clinic/review/quote reports remain general.
  - Required the exact five-field order, one of the five allowed reasons, a production-safe `hk-clinic-hours-…` migration ID, safe source name, exact real `yyyy-MM-dd` date, canonical reconstruction, and a maximum of 500 characters.
  - Added a pure handling policy: structured and malformed availability reports never permit content takedown; pending cases expose only the existing `resolveReport(..., takeDown: false)` path and closed availability cases display `已關閉`.
  - Structured admin cards show an availability badge, parsed fields, and `尚未重新核實`; malformed cards show a warning and the preserved raw reason. General report cards and their takedown/dismiss decisions retain the existing flow.
  - Added a structured `ShareLink` verification ticket using only canonical clinic ID/name and parsed fields, with the explicit instruction `需重新核實，不可直接套用回報內容`. It excludes report ID, reporter UID, clinic phone, and source URL.
  - Added XCTest and standalone production-model coverage for round-tripping all five reasons, malformed variants, privacy exclusions, takedown policy, non-clinic classification, and the exact exported ticket.
- First Sol review: **RETURNED** — one P1 found that leading whitespace or invisible controls could move a reserved availability report into the general destructive flow; one P2 found compatibility-width URLs, ideographic domain punctuation, and vertical-bar confusables could bypass source redaction and strict parsing.
- Luna correction:
  - Added a classification-only security probe that removes leading whitespace, control, and format scalars, applies compatibility normalization, and maps vertical-bar confusables before checking the exact reserved prefix `營業資料回報｜`. The raw unmodified payload must still pass the canonical parser; probe-normalized input is never upgraded to structured.
  - Kept clinic strings without the reserved delimiter, including `營業資料回報唔準`, in the general flow. The same dirty reserved-prefix payloads remain general for review and quote reports.
  - Added a source security probe with compatibility/width normalization and explicit Unicode dot, slash, colon, and vertical-bar mappings. Fullwidth URLs, `診所。香港`, `∣`, and `│` now redact to `官方來源` during generation and fail as malformed if received in a purported structured report.
  - Expanded XCTest and standalone cases for ASCII space, newline, NBSP, BOM, word joiner, delimiter confusables, non-clinic isolation, compatibility-width URLs, ideographic dots, and safe canonical Chinese source names.
- Second Sol review: **RETURNED** — one remaining P2 found that the bare-domain check still recognized only ASCII labels, allowing Unicode-label domains such as `診所.香港` and `例子.com` through.
- Luna final correction:
  - Replaced the ASCII-only domain regex with a Unicode label parser over the normalized source probe. Each adjacent domain label must be non-empty, 63 scalars or fewer, use only Unicode letters/numbers with interior ASCII hyphens, and begin and end alphanumerically.
  - Required a reasonable terminal label: 2–63 ASCII letters, valid `xn--` form, or a conservative explicit Unicode TLD set including `.香港`. This catches `診所.香港`, normalized `診所。香港`, and `例子.com` without treating an ordinary source sentence such as `香港診所。官方網站資料` as a domain.
  - Added generation-redaction, raw-parser-malformed, and ordinary-Chinese safe round-trip regressions to XCTest and the standalone harness.
- Local evidence:
  - Availability feedback production harness: `{"clinicAvailabilityFeedback":true,"passed":154}`.
  - Round 13 semantic harness remained `{"count":39,"passed":true}`. Round 14 actual-manifest compatibility remained v1 `11/10/1`, v2 `4/1/3`, merged `15/11/4`, filters `15/11/11/11`, scheduled probes `35/7`, `manifestCompatibility: true`, and `productionApplied: false`.
  - Node regression tests passed 54/54; catalog integrity remained `179/161/18/205/11`; the v2 plan remained pending at four additions and planned `15/11/4`.
  - The Foundation model, Admin Swift source, and XCTest source passed standalone Swift parsing; `sh -n`, project `plutil`, and `git diff --check` passed.
  - These checks are not a local iOS build. No local `xcodebuild` or XCTest execution is claimed.
- Final Sol source acceptance: **ACCEPT** — the leading-prefix, Unicode confusable, and IDN findings were resolved with no remaining actionable finding. Full SwiftUI compilation remains conditional on Xcode Cloud Archive completion.
- GitHub validation: `Backend and Config Validation` run `30726644881` completed successfully for the Round 16 parser, admin workflow, and regression gates.
- Xcode Cloud boundary: Build run `d692046e-2991-42e1-9241-db58f0569e20` and its `Archive - iOS` action (`1e3e830e-1fab-487e-87b5-df2b3a0199f8`) were pending. No Archive success, processed-build validity, ASC attachment, review submission, public release, or device installation is claimed.
- Later Xcode Cloud validation: The same Round 16 build and Archive action completed successfully at `01:27:27`. This proves the archive gate ran successfully but does not establish processed-build validity, ASC attachment, review submission, public release, or device installation.
- Production and release boundary: No report was resolved, no content was removed, no Firestore or availability data was written, no network request or deploy occurred, and no ASC, public-release, or device action was performed.
- Preserved scope: General clinic, review, and quote moderation, registration, submissions, community interaction, and all user-owned dirty/untracked files were preserved.

## Round 17 — Show the next verified scheduled opening

- Started: 2026-08-02 (Asia/Taipei)
- Fresh external evidence:
  - Round 16 GitHub run `30726644881` completed successfully.
  - Round 16 Xcode Cloud build run `d692046e-2991-42e1-9241-db58f0569e20` and `Archive - iOS` action `1e3e830e-1fab-487e-87b5-df2b3a0199f8` remained pending and were not treated as success.
- Sol plan: Add a single production-model `nextOpening(at:)` query for verified Hong Kong schedules and use it only to enrich closed, non-night-service labels, without changing open status, filters, or sorting.
- Luna implementation:
  - Added `ClinicAvailability.nextOpening(at:)` for current, valid, non-24-hour Hong Kong schedules. It evaluates interval starts from today through day seven, requires every candidate to be strictly later than the reference and strictly earlier than `expiresAt`, and returns the earliest candidate.
  - Empty schedules, 24-hour records, invalid payloads, expired payloads, and schedules whose next start is at or after expiry return nil. Split days, overnight intervals, week wrapping, and an opening exactly equal to the reference are covered explicitly.
  - Preserved `營業中`, 24-hour, and `設夜診` labels. Only closed clinics without night service gain a verified forecast in the exact form `休息中 · 預計今日 HH:mm 再開`, `預計明日`, or `預計星期X`; no candidate retains `休息中`.
  - Left operating-status, filter, and sort logic unchanged.
  - Added synthetic XCTest coverage and expanded the production semantic harness. Expanded the actual-manifest harness to probe every one of the 35 scheduled intervals before and inside, plus all seven split gaps, against production `nextOpening(at:)` while retaining exact merged `15/11/4` and filter counts.
- Local evidence:
  - Production semantic harness: `{"count":52,"nextOpeningProbes":13,"passed":true}`.
  - Actual-manifest compatibility retained v1 `11/10/1`, v2 `4/1/3`, merged `15/11/4`, filters `15/11/11/11`, interval/gap probes `35/7`, and added next-opening before/inside/gap probes `35/35/7`.
  - Round 16 feedback harness remained `{"clinicAvailabilityFeedback":true,"passed":154}`. Node regressions passed 54/54; catalog integrity remained `179/161/18/205/11`; the pending validator remained four additions and planned `15/11/4`.
  - Production model, XCTest, and both Swift harness sources passed standalone parsing; `sh -n`, project `plutil`, and `git diff --check` passed. These are not a local iOS build; no XCTest execution or local `xcodebuild` is claimed.
- First Sol review: **RETURNED** — one P2 found the forecast wording placed `預計` after the date/time, contrary to the required natural Hong Kong Chinese phrase.
- Luna correction: Changed the only new closed-label form to exact `休息中 · 預計\(formattedNextOpening(...)) 再開` and pinned standalone/XCTest expectations for `預計今日 14:00`, `預計明日 08:00`, and `預計星期三 10:00`.
- Final Sol source acceptance: **ACCEPT** — the copy finding was resolved, all time-boundary and actual-manifest probes remained green, and no further actionable finding remained. Full iOS compilation remains conditional on Xcode Cloud Archive completion.
- GitHub validation: `Backend and Config Validation` run `30727102606` completed successfully for the Round 17 next-opening model and regression gates.
- Xcode Cloud validation: Build run `a3aab9dc-fed9-4a04-8cd6-676e5aa8339f` and its `Archive - iOS` action (`49b59fdb-149c-489c-b08f-6eefed71083f`) completed successfully, from `01:28:39Z` to `01:34:39Z`. This proves the archive gate ran successfully but does not establish processed-build validity, ASC attachment, review submission, public release, or device installation.
- Production and release boundary: No availability or manifest data, Firestore record, Firebase deployment, ASC workflow, public release, or device app was changed. No network request or production action was performed.
- Preserved scope: Availability filters and sorting, registration, submissions, community interaction, moderation, and all user-owned dirty/untracked files were preserved.

## Round 18 — Warn before submitting a strongly duplicated clinic

- Started: 2026-08-02 (Asia/Taipei)
- Fresh external evidence:
  - Round 16 Xcode Cloud build run `d692046e-2991-42e1-9241-db58f0569e20` and `Archive - iOS` action `1e3e830e-1fab-487e-87b5-df2b3a0199f8` completed successfully at `01:27:27`.
  - Round 17 GitHub `Backend and Config Validation` run `30727102606` completed successfully. Xcode Cloud build `a3aab9dc-fed9-4a04-8cd6-676e5aa8339f` and Archive action `49b59fdb-149c-489c-b08f-6eefed71083f` also completed successfully from `01:28:39Z` to `01:34:39Z`.
- Sol plan: Add a conservative client-side duplicate warning before a clinic moderation submission, using only already-loaded public clinics and keeping the existing submission callback and backend contract unchanged.
- Luna implementation:
  - Added a Foundation-only matcher that compatibility-normalizes Unicode width, case, and punctuation in clinic names and addresses, and canonicalizes local, `+852`, `00852`, spaced, slashed, fullwidth, and production multi-number Hong Kong phone fields.
  - A match is strong only for the four explicit direct branches: same phone plus same normalized name; same phone within 200 metres; same normalized name plus same normalized address; or same normalized name within 100 metres. Name alone, phone alone outside range, indirect chains, and insufficient fields fail open.
  - Passed the full loaded public clinic array from both iPhone and iPad list flows into the add-clinic form; search filters do not narrow duplicate candidates.
  - On the first strong match, the original draft is retained and a `可能已收錄` dialog names the existing clinic. `返回核對` leaves the form untouched; `確認是不同診所並提交` uses the unchanged async submission callback. The dialog directs corrections to the existing clinic-detail report flow.
  - Added a pure one-shot gate: a confirmed fingerprint does not prompt again, an in-flight or successful draft cannot submit twice, and a failed attempt may retry without losing confirmation.
  - Added XCTest plus a standalone production-model harness for normalization, distance boundaries, every strong/non-strong branch, direct-chain isolation, insufficient data, and confirmation/in-flight/success retry state. Added the harness to Xcode Cloud post-clone after the existing three fail-closed Swift gates.
  - Added `ClinicDuplicateMatcher.swift` only to the VetMap app target; tests access it through `@testable import VetMap`.
- Local evidence:
  - Duplicate matcher production harness: `{"clinicDuplicateMatcher":true,"passed":34}`.
  - Existing availability regressions remained green: semantic `{"count":52,"nextOpeningProbes":13,"passed":true}`; actual-manifest merged `15/11/4` with next-opening probes `35/35/7`; feedback `{"clinicAvailabilityFeedback":true,"passed":154}`.
  - Node regressions passed 54/54. Catalog integrity remained `179/161/18/205/11`; the pending validator remained four additions and planned `15/11/4`.
  - The production matcher, `ClinicsViewModel`, both SwiftUI entry points, XCTest source, and harness passed standalone Swift parsing. Xcode project membership, post-clone shell syntax, project `plutil`, and `git diff --check` passed.
  - These are not a local iOS build; no XCTest execution or local `xcodebuild` is claimed.
- First Sol review: **RETURNED** — two P2 findings identified production phone fields containing two complete numbers and hidden/moderation-removed clinics leaking into or disappearing from the duplicate candidate source.
- Luna correction:
  - Replaced the single normalized phone with a canonical phone set. Complete slash-separated numbers are compared by non-empty set intersection, while a four-plus-four value such as `2123/4567` remains one eight-digit number. The submission fingerprint sorts the set, so equivalent phone order cannot cause a second prompt or submission.
  - Added production examples `2698 2185 / 2687 0226`, `2653 3632 / 6168 6175`, and `28828123/62158608`, and proved that either constituent number matches.
  - Added `ClinicsViewModel.duplicateCandidateClinics`, derived from the full raw clinic collection rather than search, availability, or mappability results, and excluded the exact live `ModerationStore.shared.removedClinicIDs` set before both iPhone and iPad forms receive candidates.
  - Added XCTest and standalone exclusion proof covering display-hidden candidates, missing-coordinate candidates, and moderation-removed IDs; the matcher harness increased to 34 passing assertions.
- Final Sol source acceptance: **ACCEPT** — both multi-phone and moderation-removed candidate findings were resolved with no remaining actionable finding. Full iOS compilation remains conditional on Xcode Cloud Archive completion.
- GitHub validation: `Backend and Config Validation` run `30727987588` completed successfully for the Round 18 duplicate-warning model and regression gates.
- Xcode Cloud validation: Build run `32c4f533-d14c-48c0-a3ec-4f45fdbc80de` and its `Archive - iOS` action (`e63b5c0d-7878-4c10-8a3a-effe9d655efc`) completed successfully from `01:58:19Z` to `02:05:10Z`. This proves the duplicate-warning source and post-clone gate compiled before Archive, but does not establish XCTest execution, processed-build validity, ASC attachment, review submission, public release, or device installation.
- Production and release boundary: No clinic submission, Firestore write, Firebase deployment, network request, ASC workflow, public release, or device action was performed.
- Preserved scope: The moderation submission contract, registration, clinic detail reporting, community interaction, filters, sorting, and all user-owned dirty/untracked files were preserved.

## Round 19 — Publish only a safe clinic projection after approval

- Started: 2026-08-02 (Asia/Taipei)
- Fresh external evidence:
  - Round 18 GitHub `Backend and Config Validation` run `30727987588` completed successfully.
  - Round 18 Xcode Cloud build `32c4f533-d14c-48c0-a3ec-4f45fdbc80de` and Archive action `e63b5c0d-7878-4c10-8a3a-effe9d655efc` are recorded for a later live status refresh; no result is inferred from their existence.
- Sol plan: Treat clinic approval as permission to list a narrowly projected identity/contact record, not verification of user-supplied hours, services, reputation, price, media, or tags. Enforce the same boundary in pure source, Firestore rules, admin copy, and fail-closed local gates.
- Luna implementation:
  - Added a Foundation-only `ClinicPublicationPolicy.safeProjection`. It retains clinic ID, name, address, reliable Hong Kong coordinate, phone, website, timestamps, and the canonical submission author; forces `catalogRegion` to `HK` and `verified` to false; and clears `openingHours`, verified availability, services, rating/count, price level, images, and tags.
  - Missing, non-finite, or non-Hong-Kong coordinates return nil. Both queued clinic approval and the legacy direct clinic publication helper use the same projection; invalid queue data throws before a Firestore batch is created.
  - Preserved the approval-owned `ugc-<submission-id>` public ID, submission author, canonical submission timestamps, public-document conflict check, and atomic public-create plus pending-status update.
  - Expanded the pending clinic admin card with phone and website, labels service values as submission claims, and states that claims are not directly published.
  - Added a Firestore `safeClinicPublication` create contract requiring the sanitized values and author/reporter parity. No rules were deployed.
  - Added XCTest and a production-model harness for every retained/forced/cleared field and missing, non-finite, and out-of-Hong-Kong coordinates. Added the harness as a fail-closed Xcode Cloud post-clone gate and added the model only to the VetMap app target.
  - Expanded emulator tests with a successful sanitized clinic approval batch, crafted rejects for verification, region, hours, availability, services, reputation, price, images, tags, submitter, and coordinate fields, plus proof that a rejected atomic batch leaves its submission pending.
- Local evidence:
  - Publication policy production harness: `{"clinicPublicationPolicy":true,"passed":25}`.
  - Local Firestore/Storage emulator suite passed 12/12 using the cached Firebase emulator and OpenJDK 21; the new safe-projection case passed, including crafted rejects and pending-state atomicity.
  - Existing production harnesses remained green: availability semantic `52/13`, actual-manifest merged `15/11/4` with next-opening probes `35/35/7`, feedback `154`, and duplicate matcher `34`.
  - Node regressions passed 54/54; catalog integrity remained `179/161/18/205/11`; the pending plan remained four additions and planned `15/11/4`. Functions lint and module load passed.
  - The production policy, Firebase service, admin view, XCTest source, and harness passed standalone Swift parsing. Rules-test JavaScript syntax, post-clone shell syntax, project `plutil`, app-only target membership, publication-path source assertions, and `git diff --check` passed.
  - These checks are not a local iOS build. No local `xcodebuild` or XCTest execution is claimed.
- Final Sol source acceptance: **ACCEPT** — policy, queued and legacy integration, atomicity, Admin disclosure, and source-only rules were accepted with no P0/P1/P2 actionable finding. Full iOS compilation remains conditional on Xcode Cloud Archive completion.
- GitHub validation: `Backend and Config Validation` run `30728756512` completed successfully for the Round 19 safe-publication policy, rules, and regression gates.
- Xcode Cloud validation: Build run `8748ecb6-102f-4a35-a36f-f47e3501e619` and its `Archive - iOS` action (`4bd63819-4ab0-4435-ae41-ddee10e2fed7`) completed successfully from `02:23:31Z` to `02:29:30Z`. This proves the safe-publication source and post-clone gates compiled before Archive, but does not establish XCTest execution, processed-build validity, ASC attachment, review submission, public release, or device installation.
- Production and release boundary: No real submission was approved, no Firestore or Storage production write occurred, no Firebase rules or Functions were deployed, and no ASC, public-release, or device action was performed. Network use was limited to loopback Firebase emulators.
- Preserved scope: Registration, clinic submission availability, community interaction, review/quote publication, user-owned dirty/untracked files, and unrelated release tooling were preserved.

## Round 20 — Recheck strong duplicates before clinic approval

- Started: 2026-08-02 (Asia/Taipei)
- Fresh external evidence:
  - Round 19 GitHub `Backend and Config Validation` run `30728756512` completed successfully.
  - Xcode Cloud build `267320de-061e-4be2-b293-5aa144d28367`, Archive action `a0ace45a-9bea-4af0-9b1e-e72b928b640a`, completed successfully from `2026-08-02T03:16:31Z` to `2026-08-02T03:22:18Z` for source `8d820e5`.
- Sol plan: Before a pending clinic can use the existing approval write, read the current approved directory and moderation removals, apply the same conservative strong-match rules, and require an exact, freshly revalidated candidate-set override.
- First Sol source review: **RETURNED** with three P2 findings: the override bound only one selected candidate rather than the complete strong-match set; clinic preflight errors were not visible inside the pending-clinic screen; and the confirmation lacked admin-readable match reasons plus full details for every candidate.
- Second Sol source review: **RETURNED** with one remaining P2: an ID-only set fingerprint would not detect changed matcher evidence or match semantics when a candidate retained the same document ID.
- Third Sol source review: **RETURNED** with one concurrency P2: clinic approval inferred its result from the shared `errorMessage`, so an unrelated concurrent operation could misclassify a successful or failed write and the UI could claim no write after a committed approval whose queue refresh failed.
- Luna implementation:
  - Added a pure `ClinicDuplicateApprovalPolicy` decision. It receives raw approved clinics, fresh removed clinic IDs, and an optional length-prefixed fingerprint of the complete sorted strong-match challenge. Each candidate contributes its ID, canonical phone set, normalized name/address, finite in-range coordinate bit representation, and match-reason semantics including exact nearby-distance bits. No strong match approves; any strong matches require override; only the exact current challenge fingerprint approves.
  - Removed clinics are excluded before matching. Search, availability, and mappability filters are never consulted, so an approved directory entry without a map coordinate can still be a direct name/address duplicate.
  - A stale or wrong override cannot authorize changed candidates: every override attempt reruns the policy against newly read data and prompts again when any candidate ID is added, removed, or replaced. The exact regression where `a-candidate` remains and a lexically later `z-candidate` appears is covered. Indirect name-only/phone-only chains remain non-matches.
  - Added `ModerationStore.approveClinicSubmission`. Every first attempt and override independently calls the existing `FirebaseService.fetchClinics()` and `fetchContentStates()` seams. Either read failure is recorded and fails closed before the existing approval method can run.
  - Refactored the generic `approveSubmission` write seam to return a per-operation typed result instead of requiring clinic approval to inspect shared state. The typed state machine keeps four outcomes distinct: preflight failed/no write, commit failed/no write, commit succeeded plus refresh succeeded, and commit succeeded plus refresh failed. Review and quote callers continue to ignore the returned value and retain their existing UI/error behavior.
  - A successful clinic commit is recorded locally before the in-flight guard is released. If the following queue refresh fails, the stale row disables both approve and reject so the committed submission cannot be approved again; a later successful reload reconciles that state against the fresh pending IDs.
  - Added per-submission clinic approval in-flight state. The pending clinic row disables both approve and reject actions during preflight/write; `defer` clears that state after read failure so the actions become retryable. The same screen now says the item was not approved, no data changed, and retry is available.
  - The pending-clinic UI now derives its result banner only from the typed result for that operation. It says `未批准，資料未有改動，可重新嘗試` only for typed preflight/write failures, and says `已批准，但清單刷新失敗，請重新載入` after a committed write with a failed refresh. Shared `errorMessage` is shown only as a neutral generic operation error.
  - The `可能已收錄` confirmation lists every current strong-match candidate's name, address, phone, and an admin-readable match reason. Nearby reasons include the approximate distance, and the copy warns that candidate-set changes require another confirmation.
  - Expanded XCTest and the production duplicate harness for no match, first match, exact/wrong/stale challenge fingerprints, retained `a` plus newly added `z`, same-ID normalized content change with unchanged reason, same-ID reason/distance change, removed candidate, indirect chain, and exact reason labels while preserving all prior cases.
- Local evidence:
  - Duplicate matcher/approval production harness: `{"clinicDuplicateMatcher":true,"passed":55}` (existing 34 plus full-evidence challenge approval and exact admin-label cases).
  - Clinic approval typed-operation production harness: `{"clinicApprovalOperation":true,"passed":4}` covering all four preflight/write/refresh outcomes; the same production helper has XCTest coverage and is wired into the Xcode Cloud post-clone fail-closed gates.
  - Existing production harnesses remained green: availability semantic `52/13`, actual-manifest merged `15/11/4` with next-opening probes `35/35/7`, feedback `154`, and publication policy `25`.
  - Node regressions passed 54/54; catalog integrity remained `179/161/18/205/11`; the pending plan remained four additions and planned `15/11/4`. Functions lint/module load and the loopback Firebase emulator suite 12/12 passed.
  - The matcher/policy, ModerationStore, Admin view, XCTest source, and harness passed standalone Swift parsing. Post-clone shell syntax, project `plutil`, integration-source assertions, and `git diff --check` passed.
  - These checks are not a local iOS build. No local `xcodebuild` or XCTest execution is claimed.
- Final Sol source acceptance: **ACCEPT** — the full challenge fingerprint, visible preflight handling, informed override copy, per-operation typed outcomes, and committed-write lockout resolved every P2 with no remaining P0/P1/P2 finding. Xcode Cloud subsequently confirmed the Archive action completed successfully.
- Production and release boundary: No real moderation item was approved or rejected, no production read/write or network request was made, no Firebase deployment occurred, and no ASC, public-release, or device action was performed.
- Preserved scope: Review and quote approval behavior, registration, submissions, community interaction, publication projection/rules, all user-owned dirty/untracked files, and unrelated release tooling were preserved.

## Round 21 — Live-state reconciliation after Round 20 acceptance

- Reconciled: 2026-08-02 (Asia/Taipei)
- Source evidence:
  - Reconciled source revision: `8d820e5`.
  - GitHub `Backend and Config Validation` run `30730331974` completed successfully.
  - Xcode Cloud build `267320de-061e-4be2-b293-5aa144d28367`, Archive action `a0ace45a-9bea-4af0-9b1e-e72b928b640a`, completed successfully from `2026-08-02T03:16:31Z` to `2026-08-02T03:22:18Z`.
- Production public audit evidence:
  - The live public availability overlay was verified at `11/10/1`: 11 availability records, including ten 24-hour entries and one scheduled entry.
  - Availability v2 remains a pending four-clinic plan. The planned merged state is `15/11/4`, and `productionApplied` is explicitly `false`.
- Device evidence:
  - Physical device `是條小狗` was booted, paired, and reachable on the local network at the time of reconciliation, but its developer tunnel was disconnected.
  - No fresh install, launch, screenshot, or functional device proof was performed or inferred.
- App Store Connect boundary:
  - The live ASC session was not refreshed because it had expired. Any last-known build/version/review information is historical only and must not be treated as current.
  - No processed-build validity, version attachment, review-submission state, storefront availability, or public-release claim is made.
- Action boundary:
  - This reconciliation made no production write, ASC mutation, local Xcode build, Firebase deployment, device install/launch, or other device action.
  - User-owned dirty and untracked files were preserved without staging, reverting, deleting, or modifying them.
- Review state: Log-only reconciliation complete; source, GitHub, Xcode Cloud, production audit, device connectivity, and ASC evidence remain separately stated.

## Release follow-up — Chat moderation least privilege and Apple upload quota

- Started: 2026-08-03 (Asia/Taipei)
- Apple evidence: Developer Relations reported `ITMS-90382: Upload limit reached` for Version 1.0 Build 39 and instructed waiting one day. This confirms Build 39 did not enter ASC processing; it is not a signing or compilation diagnosis.
- Plan: Keep the Xcode Cloud workflow disabled during the quota window, complete a source-only privacy hardening item, then run the next candidate only after the upload window resets.
- Implementation:
  - Message reporting now writes the report, one conversation moderation marker, and one message-specific marker in a single Firestore batch.
  - Admin conversation access requires a reported-conversation marker. Admin message read and soft-delete require the marker for that exact message; a marker for one message does not unlock other messages in the conversation.
  - Account deletion recursively removes the linked `chatModeration` document and nested markers together with the conversation and linked reports.
  - Production deployment is deliberately deferred until a compatible new Cloud candidate is installed; deploying first would make Build 39's older report writer fail and would violate the requirement to keep reporting available.
- Local verification:
  - Firestore／Storage emulator: 17/17 passed, including report-only and marker-only rejection, atomic report success, pre-report admin denial, exact reported-message access, and denial for a second unreported message in the same conversation.
  - Firebase Functions ESLint/module load, JavaScript syntax, Swift frontend parse, project plist, and `git diff --check` passed.
  - No local `xcodebuild`, archive, Apple upload, Firebase production deployment, ASC mutation, review submission, public release, or device action was performed.
- Git evidence:
  - Exact source and documentation commit `00fa4a2` (`fix: scope admin access to reported chat messages`) was pushed to `origin/main`.
  - GitHub `Backend and Config Validation` run `30763791472` completed successfully, including all 17 Firestore／Storage rules cases, Functions validation, catalog gates, and patch hygiene.
  - Xcode Cloud remained disabled; no Cloud build or Apple upload was triggered during the quota window.
- Next: After Apple's one-day window, run Xcode Cloud to terminal state, install the compatible candidate, deploy the least-privilege rules, and complete the report/admin device smoke test.

### Live ASC UI reconciliation — 2026-08-03 03:49 CST

- App Privacy: Live UI showed the disclosure as Published. It listed seven collected-data types, including Other User Content linked to identity and used for App Functionality, so private chat is covered by the published disclosure.
- Rating: The current UI showed `16+` in 173 countries or regions and `15+` in South Korea. The pre-OS 26／legacy global rating remained `17+`, matching the API value `SEVENTEEN_PLUS`; these are presentation generations of the same completed questionnaire, not conflicting declarations.
- Content Rights: Live UI still showed `否，此 App 不包含、顯示或存取第三方內容`. No mutation was made because the account holder has not yet given the complete rights attestation covering the clinic database, Hong Kong service directory, official insurance links, and user-submitted content under the app terms.
- Review state: iOS 1.0 remained `準備審查` with Build 12 attached. The Review Submission draft was created 2026-07-14 06:07, contained one item, and still offered `提交項目草稿 (1)`; it was not submitted.
- Xcode Cloud: Workflow `Default` (`DBB6C988-A379-476E-9E99-3235B11BAD2E`) remained disabled and showed last modified 2026-08-03 02:42 CST. Its archive uses the `VetMap` scheme with App Store Connect distribution preparation. The latest run remained 41 and no Run 42 existed; no Cloud build or upload was triggered.
- Upload-window evidence: The connected Gmail account contained no matching Build 39 Apple delivery notice, so the exact email receipt time could not be established. Using Run 39's 2026-08-03 01:55 CST start as a conservative reference, the next attempt is deferred until after 2026-08-04 03:00 CST.
- Action boundary: This was a read-only ASC／mail reconciliation plus repository documentation. No App Review submission, Content Rights edit, build attachment, workflow activation, Cloud run, Apple upload, Firebase deployment, production write, public release, or device action was performed.

### Account-deletion behavior gate — 2026-08-03 04:00 CST

- Completion-audit finding: The account-deletion UI, callable, recent-authentication check, and production baseline existed, but CI only linted and loaded the Functions module. It did not execute the destructive data graph, so complete purge behavior was not yet proven.
- Implementation: Extracted the existing callable body into an injected helper without changing collection names, ownership fields, region, storage prefixes, response schema, or client contract. The callable still obtains the Admin Firestore and Storage instances and invokes the same purge operation after recent-auth validation.
- Emulator evidence: New Functions tests passed 2/2 against the loopback Firestore emulator. They covered missing, malformed, stale, future, and exact five-minute auth times; seeded owned submissions, quotes, clinics, reports, reviews, a conversation with nested messages, linked chat reports, nested `chatModeration` markers, incoming block references, Helpful votes, and the user subtree; verified unrelated data remained; verified all four Storage prefixes; and verified an immediate retry returned zero remaining documents.
- Regression evidence: Existing Firestore／Storage rules tests remained 17/17. Functions ESLint, module load, JavaScript syntax, and `git diff --check` passed. The primary GitHub workflow now runs the Functions behavior suite before the rules suite in the same credential-free demo emulator process.
- Git evidence: Commit `703aa12` (`test: verify account purge behavior`) was pushed to `origin/main`. GitHub `Backend and Config Validation` run `30764734390` completed successfully in 40 seconds, including Functions purge 2/2, rules 17/17, catalog and pending-hours gates, Functions validation, and patch hygiene.
- Cloud boundary: Xcode Cloud remained disabled and no Run 42 or Apple upload was created.
- Deployment boundary: The currently active production callable was not changed. The compatible Functions source, like the least-privilege rules, remains pending until a compatible new app candidate is installed. No production read/write, Firebase deploy, local `xcodebuild`, Cloud workflow activation, Apple upload, ASC mutation, App Review submission, public release, or device action occurred.
- Preserved scope: Registration, clinic/review/quote submission, reporting, blocking, Helpful votes, chat and all community interactions remain open. User-owned dirty and untracked files were not staged, reverted, deleted, or edited.

### GitHub Actions Node 24 maintenance — 2026-08-03 04:09 CST

- Finding: Successful run `30764818975` carried a GitHub annotation that `actions/checkout@v4`, `actions/setup-node@v4`, and `actions/setup-java@v4` targeted deprecated Node 20 and were being forced onto Node 24.
- Official action evidence: The current major tags `actions/checkout@v7`, `actions/setup-node@v7`, and `actions/setup-java@v5` each declare `runs.using: node24`; their latest official releases were respectively 7.0.1, 7.0.0, and 5.7.0 at the time of verification.
- Implementation: Updated only the three action major pins. The app Functions runtime remains Node 22, Java remains Temurin 21, dependency caches and every validation command remain unchanged.
- Verification: Workflow YAML parsed successfully, Functions ESLint/module load and `git diff --check` passed. Commit `bc84750` (`ci: move validation actions to Node 24`) was pushed to `origin/main`.
- GitHub evidence: `Backend and Config Validation` run `30764946922` completed successfully in 34 seconds. The live job used checkout v7, setup-node v7, and setup-java v5; catalog gates, Functions purge 2/2, rules 17/17, and patch hygiene passed; the annotations section was empty, proving the Node 20 warning was removed.
- Boundary: Xcode Cloud remained disabled; no Run 42, Apple upload, production deployment, ASC mutation, App Review submission, public release, or device action occurred. All user-owned dirty and untracked files remained untouched.
