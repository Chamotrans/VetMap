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
- GitHub validation: Pending the pushed commit for this round.
- Xcode Cloud: Pending the pushed commit for this round.
- Release boundary: No ASC build attachment, review submission, or public release was performed.
- Preserved scope: Registration, submissions, community interaction, moderation, all other collections, and existing user-owned dirty/untracked files were not changed by this round.
