import {
  validateHKCatalogIntegrity,
} from "./validate_hk_catalog_integrity.mjs";
import {
  validateHKClinicHoursV2Pending,
} from "./validate_hk_clinic_hours_v2_pending.mjs";
import {
  validateHKClinicHoursV3Pending,
} from "./validate_hk_clinic_hours_v3_pending.mjs";

export const AVAILABILITY_STATES = new Set([
  "deployed-v1",
  "post-apply-v2",
  "post-apply-v3",
]);
const V1_MIGRATION_ID = "hk-clinic-hours-v1-2026-07-30";

function usageError() {
  return new Error(
    "Usage: node scripts/audit_firestore_public.mjs [--public-only] "
    + "[--availability-state deployed-v1|post-apply-v2|post-apply-v3]",
  );
}

export function parseAuditOptions(args) {
  let publicOnly = false;
  let availabilityState = "deployed-v1";
  let sawPublicOnly = false;
  let sawAvailabilityState = false;

  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === "--public-only") {
      if (sawPublicOnly) throw usageError();
      sawPublicOnly = true;
      publicOnly = true;
      continue;
    }
    if (argument === "--availability-state") {
      if (sawAvailabilityState) throw usageError();
      const value = args[index + 1];
      if (!value || value.startsWith("--") || !AVAILABILITY_STATES.has(value)) {
        throw usageError();
      }
      sawAvailabilityState = true;
      availabilityState = value;
      index += 1;
      continue;
    }
    throw usageError();
  }

  if (publicOnly && availabilityState !== "deployed-v1") {
    throw new Error(
      `${availabilityState} requires a full authenticated authoritative audit.`,
    );
  }
  return {
    publicOnly,
    auditMode: publicOnly ? "public-only" : "full",
    availabilityState,
  };
}

function normalize(value) {
  if (Array.isArray(value)) return value.map(normalize);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.keys(value).sort().map((key) => [key, normalize(value[key])]),
    );
  }
  return value;
}

function sameJSON(lhs, rhs) {
  return JSON.stringify(normalize(lhs)) === JSON.stringify(normalize(rhs));
}

function expectedAvailability(manifest, clinic, migrationId) {
  return {
    schemaVersion: manifest.schemaVersion,
    migrationId,
    timeZoneIdentifier: manifest.timeZoneIdentifier,
    weeklyHours: clinic.weeklyHours,
    is24Hours: clinic.is24Hours,
    offersNightService: clinic.offersNightService,
    displayLabel: clinic.displayLabel,
    serviceNote: clinic.serviceNote,
    sourceURL: clinic.sourceURL,
    sourceName: clinic.sourceName,
    verifiedAt: new Date(manifest.verifiedAt).toISOString(),
    expiresAt: new Date(manifest.expiresAt).toISOString(),
  };
}

export function buildAvailabilityExpectation({
  catalog,
  v1Hours,
  pending,
  v3Hours,
  report,
  availabilityState,
  now = new Date(),
}) {
  if (!AVAILABILITY_STATES.has(availabilityState)) {
    throw new Error(`Unknown availability state: ${availabilityState}`);
  }
  validateHKCatalogIntegrity({catalog, hours: v1Hours, report});
  if (catalog.count !== 179) {
    throw new Error(`HK clinic catalog must contain exactly 179 entries.`);
  }
  if (availabilityState === "post-apply-v2") {
    validateHKClinicHoursV2Pending({catalog, v1Hours, pending, report});
  }
  if (availabilityState === "post-apply-v3") {
    validateHKClinicHoursV2Pending({catalog, v1Hours, pending, report});
    validateHKClinicHoursV3Pending({
      catalog,
      v1Hours,
      v2Hours: pending,
      pending: v3Hours,
    });
  }
  const selectedExpiry = new Date(
    availabilityState === "post-apply-v3" ? v3Hours.expiresAt
      : availabilityState === "post-apply-v2" ? pending.expiresAt
        : v1Hours.expiresAt,
  );
  if (!Number.isFinite(selectedExpiry.getTime()) || selectedExpiry <= now) {
    throw new Error(`${availabilityState}: selected availability plan is stale.`);
  }

  const entries = [
    ...v1Hours.clinics.map((clinic) => ({
      clinic,
      manifest: v1Hours,
      migrationId: V1_MIGRATION_ID,
    })),
    ...(availabilityState === "post-apply-v2"
      || availabilityState === "post-apply-v3"
      ? pending.clinics.map((clinic) => ({
        clinic,
        manifest: pending,
        migrationId: pending.migrationId,
      }))
      : []),
    ...(availabilityState === "post-apply-v3"
      ? v3Hours.clinics.map((clinic) => ({
        clinic,
        manifest: v3Hours,
        migrationId: v3Hours.migrationId,
      }))
      : []),
  ];
  const availabilityByID = new Map(entries.map((entry) => [
    entry.clinic.clinicID,
    expectedAvailability(entry.manifest, entry.clinic, entry.migrationId),
  ]));
  const catalogNamesByID = new Map(
    catalog.clinics.map(({id, name}) => [id, name]),
  );
  const twentyFourHours = entries.filter(
    ({clinic}) => clinic.is24Hours,
  ).length;
  const expectedCount = availabilityState === "deployed-v1" ? 11
    : availabilityState === "post-apply-v2" ? 15 : 33;
  const expectedTwentyFourHours = availabilityState === "deployed-v1" ? 10
    : availabilityState === "post-apply-v2" ? 11 : 14;
  if (
    availabilityByID.size !== expectedCount
    || twentyFourHours !== expectedTwentyFourHours
  ) {
    throw new Error(
      `${availabilityState}: manifest distribution is not exact `
      + `${expectedCount}/${expectedTwentyFourHours}/`
      + `${expectedCount - expectedTwentyFourHours}.`,
    );
  }
  return {
    availabilityState,
    catalogCount: catalog.count,
    catalogNamesByID,
    catalogIDs: new Set(catalogNamesByID.keys()),
    availabilityByID,
    total: expectedCount,
    twentyFourHours: expectedTwentyFourHours,
    scheduled: expectedCount - expectedTwentyFourHours,
  };
}

function normalizeAvailabilityTimestamps(availability) {
  if (!availability || typeof availability !== "object") return availability;
  const normalized = {...availability};
  for (const field of ["verifiedAt", "expiresAt"]) {
    const date = new Date(normalized[field]);
    if (!Number.isFinite(date.getTime())) return availability;
    normalized[field] = date.toISOString();
  }
  return normalized;
}

export function verifyHKClinicAvailability(documents, expectation, label) {
  const byID = new Map();
  for (const document of documents) {
    if (byID.has(document.id)) {
      throw new Error(`${label}: duplicate HK clinic ID ${document.id}.`);
    }
    byID.set(document.id, document);
  }
  if (
    documents.length !== expectation.catalogCount
    || documents.some(({id}) => !expectation.catalogIDs.has(id))
    || [...expectation.catalogIDs].some((id) => !byID.has(id))
  ) {
    throw new Error(`${label}: HK clinic catalog IDs are incomplete or extra.`);
  }
  for (const document of documents) {
    if (
      document.name !== expectation.catalogNamesByID.get(document.id)
      || document.status !== "approved"
      || document.catalogRegion !== "HK"
      || document.region !== "HK"
    ) {
      throw new Error(`${label}: HK clinic identity drift at ${document.id}.`);
    }
    const expected = expectation.availabilityByID.get(document.id);
    const hasAvailability = Object.hasOwn(document, "availability");
    if (!expected && hasAvailability) {
      throw new Error(
        `${label}: availability exists outside planned IDs at ${document.id}.`,
      );
    }
    if (expected && !hasAvailability) {
      throw new Error(`${label}: availability missing at ${document.id}.`);
    }
    if (
      expected
      && !sameJSON(
        normalizeAvailabilityTimestamps(document.availability),
        expected,
      )
    ) {
      throw new Error(`${label}: availability drift at ${document.id}.`);
    }
  }

  const available = documents.filter(
    ({id}) => expectation.availabilityByID.has(id),
  );
  const twentyFourHours = available.filter(
    ({availability}) => availability.is24Hours,
  ).length;
  const summary = {
    total: available.length,
    twentyFourHours,
    scheduled: available.length - twentyFourHours,
  };
  if (
    summary.total !== expectation.total
    || summary.twentyFourHours !== expectation.twentyFourHours
    || summary.scheduled !== expectation.scheduled
  ) {
    throw new Error(`${label}: availability distribution is not exact.`);
  }
  return summary;
}

export function verifyNoAvailabilityOutsidePlan(documents, expectation, label) {
  for (const document of documents) {
    if (
      Object.hasOwn(document, "availability")
      && !expectation.availabilityByID.has(document.id)
    ) {
      throw new Error(
        `${label}: availability exists outside planned IDs at ${document.id}.`,
      );
    }
  }
}

export function verifyApprovedClinicParity(
  publicDocuments,
  authoritativeDocuments,
  expectation,
) {
  const publicIDs = publicDocuments.map(({id}) => id).sort();
  const authoritativeIDs = authoritativeDocuments.map(({id}) => id).sort();
  if (!sameJSON(publicIDs, authoritativeIDs)) {
    throw new Error(
      "clinics: authenticated approved IDs do not match anonymous approved IDs.",
    );
  }

  const publicByID = new Map(publicDocuments.map((document) => [
    document.id,
    document,
  ]));
  if (expectation) {
    verifyNoAvailabilityOutsidePlan(
      [...publicDocuments, ...authoritativeDocuments],
      expectation,
      "clinics",
    );
  }
  for (const document of authoritativeDocuments) {
    const publicDocument = publicByID.get(document.id);
    const publicHas = Object.hasOwn(publicDocument ?? {}, "availability");
    const authoritativeHas = Object.hasOwn(document, "availability");
    if (
      publicHas !== authoritativeHas
      || (publicHas && !sameJSON(
        normalizeAvailabilityTimestamps(publicDocument.availability),
        normalizeAvailabilityTimestamps(document.availability),
      ))
    ) {
      throw new Error(
        `clinics: public/authenticated availability mismatch at ${document.id}.`,
      );
    }
  }
}
