import {readFile} from "node:fs/promises";
import {fileURLToPath} from "node:url";

const DAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];
const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;
const MAX_WINDOW_MS = 90 * 24 * 60 * 60 * 1000;
const CANONICAL_SOURCES = new Map([
  ["clinic-hk-vetmap-vet-038", ["Concordia Pet Care 官方網站", "https://www.concordiapetcare.com/aboutus"]],
  ["clinic-hk-vetmap-vet-027", ["Cosmo Pet 官方網站", "https://www.cosmopethk.com/"]],
  ["clinic-hk-vetmap-vet-036", ["港島獸醫診所官方網站", "https://www.hkivc.com.hk/home"]],
  ["clinic-hk-vetmap-vet-033", ["灣仔動物醫院官方網站", "https://www.hongkongvet.com/zh-hant/contact/"]],
  ["clinic-hk-vetmap-vet-099", ["沙田動物醫院官方網站", "https://www.hongkongvet.com/zh-hant/contact/"]],
  ["hk-npv-non-profit-vet-services-npv29", ["非牟利獸醫服務協會官方網站", "https://www.npv.org.hk/vet-service/clinic-info/clinic/"]],
  ["clinic-hk-vetmap-vet-067", ["九龍動物醫院官方網站", "https://kowloon-vet-hospital.com/%E8%81%AF%E7%B5%A1%E6%88%91%E5%80%91/?lang=zh-hans"]],
  ["clinic-hk-vetmap-vet-084", ["Peticare 官方網站", "https://www.peticare.com.hk/health"]],
  ["clinic-hk-vetmap-vet-163", ["Peticare 官方網站", "https://www.peticare.com.hk/health"]],
  ["clinic-hk-vetmap-vet-055", ["Peticare 官方網站", "https://www.peticare.com.hk/health"]],
  ["clinic-hk-vetmap-vet-076", ["勝利動物醫院官方網站", "https://victoryanimalhospital.com/contact/"]],
  ...["052", "040", "026", "017", "133", "104", "146"].map((id) => [
    `clinic-hk-vetmap-vet-${id}`,
    ["Pet Space 官方網站", "https://petspace.group/zh_hk/our-clinics/"],
  ]),
]);

function assert(value, message) {
  if (!value) throw new Error(`HK clinic hours v3 pending: ${message}`);
}

function json(value) { return JSON.stringify(value); }

function hasCanonicalSource(clinic) {
  const expected = CANONICAL_SOURCES.get(clinic.clinicID);
  return expected?.[0] === clinic.sourceName && expected?.[1] === clinic.sourceURL;
}

function minutes(time) {
  const [hours, minutes] = time.split(":").map(Number);
  return hours * 60 + minutes;
}

function validateSchedule(clinic) {
  assert(clinic.weeklyHours && typeof clinic.weeklyHours === "object" && !Array.isArray(clinic.weeklyHours), `${clinic.clinicID}: weeklyHours must be an object`);
  if (clinic.is24Hours) {
    assert(Object.keys(clinic.weeklyHours).length === 0, `${clinic.clinicID}: 24-hour schedule must be empty`);
    assert(clinic.offersNightService, `${clinic.clinicID}: 24-hour entry must offer night service`);
    return;
  }
  assert(Object.keys(clinic.weeklyHours).length === DAYS.length && DAYS.every((day) => Array.isArray(clinic.weeklyHours[day])), `${clinic.clinicID}: regular schedule must cover all weekdays`);
  for (const day of DAYS) {
    let previousEnd = -1;
    for (const interval of clinic.weeklyHours[day]) {
      assert(TIME.test(interval?.opensAt) && TIME.test(interval?.closesAt), `${clinic.clinicID}: invalid time interval`);
      const start = minutes(interval.opensAt);
      const end = minutes(interval.closesAt);
      assert(end > start, `${clinic.clinicID}: overnight or zero-length intervals are not supported`);
      assert(start >= previousEnd, `${clinic.clinicID}: overlapping weekday intervals`);
      previousEnd = end;
    }
  }
}

export function validateHKClinicHoursV3Pending({catalog, v1Hours, v2Hours, pending}) {
  assert(pending?.schemaVersion === 1, "schemaVersion must equal 1");
  assert(pending.migrationId === "hk-clinic-hours-v3-2026-09-01", "migrationId is invalid");
  assert(pending.deploymentStatus === "pending", "deploymentStatus must equal pending");
  assert(pending.catalogRegion === "HK" && pending.timeZoneIdentifier === "Asia/Hong_Kong", "Hong Kong region/timezone is required");
  assert(Array.isArray(pending.clinics) && pending.count === pending.clinics.length, "count must match pending clinics length");
  // Only inspected exact-branch sources are admitted. Eighteen verified
  // records materially lift coverage from 15 to 33 without padding guesses.
  assert(pending.count === 18, "v3 must contain exactly 18 source-verified clinics");
  const verifiedAt = new Date(pending.verifiedAt);
  const expiresAt = new Date(pending.expiresAt);
  assert(pending.verifiedAt === "2026-09-01T00:00:00+08:00", "verifiedAt must equal 2026-09-01");
  assert(Number.isFinite(verifiedAt.getTime()) && Number.isFinite(expiresAt.getTime()) && expiresAt > verifiedAt && expiresAt - verifiedAt <= MAX_WINDOW_MS && expiresAt <= new Date("2026-11-30T23:59:59+08:00"), "verification window is stale or overlong");

  const catalogByID = new Map(catalog.clinics.map((clinic) => [clinic.id, clinic]));
  const priorIDs = new Set([...v1Hours.clinics, ...v2Hours.clinics].map(({clinicID}) => clinicID));
  const currentIDs = new Set();
  for (const clinic of pending.clinics) {
    assert(!currentIDs.has(clinic.clinicID), `duplicate v3 clinicID: ${clinic.clinicID}`);
    currentIDs.add(clinic.clinicID);
    const catalogClinic = catalogByID.get(clinic.clinicID);
    assert(catalogClinic, `${clinic.clinicID}: missing catalog clinic`);
    assert(!priorIDs.has(clinic.clinicID), `${clinic.clinicID}: overlaps v1/v2`);
    for (const [field, value] of [["expectedName", catalogClinic.name], ["expectedAddress", catalogClinic.address], ["expectedPhone", catalogClinic.phone]]) {
      assert(clinic[field] === value, `${clinic.clinicID}: ${field} must match catalog`);
    }
    assert(typeof clinic.sourceName === "string" && clinic.sourceName.trim(), `${clinic.clinicID}: sourceName is required`);
    assert(hasCanonicalSource(clinic), `${clinic.clinicID}: source name/URL must match the inspected exact branch source`);
    assert(typeof clinic.serviceNote === "string" && /公眾假期/.test(clinic.serviceNote) && /致電/.test(clinic.serviceNote), `${clinic.clinicID}: call-ahead/public-holiday caution is required`);
    assert(typeof clinic.is24Hours === "boolean" && typeof clinic.offersNightService === "boolean", `${clinic.clinicID}: invalid availability flags`);
    validateSchedule(clinic);
  }
  assert(currentIDs.size === CANONICAL_SOURCES.size && [...CANONICAL_SOURCES.keys()].every((id) => currentIDs.has(id)), "v3 clinic IDs must match the inspected source plan");
  const plannedTotal = v1Hours.count + v2Hours.count + pending.count;
  assert(plannedTotal > v1Hours.count + v2Hours.count, "planned coverage must increase");
  return {deploymentStatus: pending.deploymentStatus, productionApplied: false, pendingCount: pending.count, priorPlannedTotal: v1Hours.count + v2Hours.count, plannedTotal, planned24Hours: [...v1Hours.clinics, ...v2Hours.clinics, ...pending.clinics].filter((clinic) => clinic.is24Hours).length, plannedScheduled: [...v1Hours.clinics, ...v2Hours.clinics, ...pending.clinics].filter((clinic) => !clinic.is24Hours).length};
}

async function main() {
  const read = (path) => readFile(new URL(`../${path}`, import.meta.url), "utf8").then(JSON.parse);
  const result = validateHKClinicHoursV3Pending({catalog: await read("catalog/hk_clinics_v1.json"), v1Hours: await read("catalog/hk_clinic_hours_v1.json"), v2Hours: await read("catalog/hk_clinic_hours_v2.pending.json"), pending: await read("catalog/hk_clinic_hours_v3.pending.json")});
  console.log(json(result));
}
if (process.argv[1] === fileURLToPath(import.meta.url)) main().catch((error) => { console.error(error.message); process.exitCode = 1; });
