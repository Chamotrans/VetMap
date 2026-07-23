# VetMap 1.0 — Content Rights Packet

> Release candidate: `1.0 (8)`
> Audited: 2026-07-24
> Scope: App Store release bundle and production public content

## Release decision

Build 8 does not ship the previously bundled unlicensed clinic, merchant,
insurance, review, quote, or custom-font datasets. It adds a versioned
production Firestore snapshot of Taiwan's Ministry of Agriculture
`獸醫師(佐)開業執照` open dataset under OGDL-Taiwan 1.0. The snapshot contains
2,074 licence records dated 2026-01-12, split across 21 catalog shards.
Registration, clinic/review/quote submissions, moderation, reporting,
blocking, and helpful voting remain available.

Public clinics, reviews, and quotes are read only from approved Firestore
collections. New submissions remain pending until an administrator approves
them. The Terms of Service contains the contributor licence for user-submitted
content.

The production review path may include one VetMap-owned demonstration clinic,
review, and quote. Each item is prominently labelled as non-real App Review
demo content, uses no third-party business identity or medical claim, and is
published from a dedicated fixture UID. Its sole purpose is to make the
Helpful, Report, Block, and moderation paths reachable during review.

The repository may still contain historical research files under
`data_sources/`; they are not Xcode target resources and are not a rights basis
for publication. They must not be reintroduced without a documented licence or
direct permission.

## Excluded sources

| Source/content | Build 8 decision | Reason |
|---|---|---|
| Historical Hong Kong clinic seeds | Excluded | No documented commercial reuse permission |
| ePetPet / PetCircle-derived records | Excluded | Source links and attribution are not a commercial licence |
| Taiwan Ministry of Agriculture licence registry | Included from production Firestore | OGDL-Taiwan 1.0 permits commercial reuse with attribution |
| Merchant/service directory | Excluded and catalog UI hidden | No release-grade rights packet |
| Insurance plan names, pricing, and coverage | Excluded and catalog UI hidden | No permission; regulated and time-sensitive claims |
| Seed reviews and quotes | Excluded | No verifiable contributor licence or provenance |
| Rounded Mplus 1c font files | Removed from target | No bundled licence notice; unused custom font replaced by system font |

## Official-source research

### Hong Kong

The AFCD voluntary Vet Clinics List is incomplete, has no machine-readable
feed or coordinates, and its copyright notice permits reproduction for
non-commercial use only. Commercial reproduction requires prior written
authorization. The Veterinary Surgeons Board register lists individual
veterinary surgeons and limits use to verification; it is not a clinic-map
dataset.

- AFCD list:
  <https://www.pets.gov.hk/english/animal_health_and_welfare/vet_clinics_list.html>
- AFCD copyright notice:
  <https://www.pets.gov.hk/english/copyright_notice/copyright.html>
- VSB register:
  <https://www.vsbhk.org.hk/english/vsro/vsro.html>

No Hong Kong official dataset is approved for Build 8 ingestion.

### Taiwan

The Ministry of Agriculture `獸醫師(佐)開業執照` dataset is released under
OGDL-Taiwan 1.0 and permits commercial reuse with mandatory attribution. It
contains licence status, institution name, phone, and address, but no
coordinates, opening hours, services, website, or emergency status.

- Dataset: <https://data.gov.tw/dataset/8705>
- Licence: <https://data.gov.tw/license>

Build 8 includes the 2026-01-12 snapshot in the dedicated public-read,
admin-write `officialClinicCatalog` collection. VetMap:

1. Preserves the licence number, licence type/status, source URL, snapshot
   date, raw address, and agency attribution.
2. Displays the dataset and OGDL licence links in the official directory.
3. Does not store or invent coordinates. The source contains no coordinates;
   the Apple Maps action performs an address search only when the user opens it.
4. Does not display the responsible veterinarian field.
5. Does not claim “open now”, ratings, services, independent verification, or
   VetMap endorsement for official records.

Production public audit on 2026-07-24 verified 2,074 unique records, 21 shards,
the expected OGDL manifest, and no responsible-veterinarian field in the
published records.

## App Store Connect declaration

The app contains third-party content because it can display approved
user-generated content. The correct first answer is therefore **Yes**.

Checking the separate legal attestation that the account holder has all
necessary rights remains an account-holder decision. Automation must stop
before that attestation unless the account holder expressly confirms it.
