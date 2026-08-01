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
- GitHub validation: Pending the pushed commit for this round.
- Xcode Cloud: No Swift change requires a new app proof, but the normal main-branch trigger will be observed if it runs.
- Production boundary: The validator is offline and read-only. It does not replace the unavailable full authoritative Firestore inventory/stray/metadata audit.
- Release boundary: No ASC build attachment, review submission, or public release was performed.
- Preserved scope: No catalog data, migration, production, Swift, Firestore query, registration, submissions, community, moderation, or user-owned dirty/untracked file was changed by this round.
