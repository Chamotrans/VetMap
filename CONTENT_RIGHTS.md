# VetMap 1.0 — Content Rights Packet

> Release candidate: pending next Hong Kong Xcode Cloud build
> Audited: 2026-07-29
> Scope: App Store release bundle and production public content

## Release decision

VetMap 1.0 is a Hong Kong veterinary clinic map and moderated community.
Registration, clinic/review/quote submissions, moderation, reporting, blocking,
helpful voting and in-app account deletion remain enabled.

The wrong Taiwan directory added by Build 9 has been removed from the app
source. Anonymous Firestore access to `officialClinicCatalog` is denied. Its
documents remain in Firestore only as a non-public backup and are not referenced
by the Hong Kong release.

Production public content currently contains:

- 179 Hong Kong clinic directory entries from the VetMap-authorized database;
- one VetMap-owned, clearly non-real App Review demo clinic;
- one VetMap-owned demo review and one demo quote;
- 124 Hong Kong pet-service directory entries (50 supplies, 50 grooming,
  24 aftercare); and
- three links to official Hong Kong pet-insurance provider pages.

The 179 Hong Kong clinic entries retain only factual name, address and phone
fields. 161 have a reliable Hong Kong coordinate from either the authorized
source or the HKSAR Digital Policy Office Address Lookup Service. The remaining
18 are intentionally list-only: they are searchable and retain their address
and phone, but do not receive a fabricated map pin, distance or route.
Unverified ratings, review totals, price levels, services, opening hours,
emergency claims, tags and images are cleared. They are marked
`verified: false`. The migration made no Taiwan record public.

Legacy reviews and quotes remain hidden. New user submissions remain pending
until an administrator approves them. The Terms of Service contains the
contributor licence for user-submitted content.

## Production audit boundary

| Content | Public state | Decision |
|---|---|---|
| Authorized Hong Kong clinic entries | 179 approved | Included; 161 mappable, 18 list-only |
| VetMap App Review fixtures | 1 clinic, 1 review, 1 quote | Included and labelled non-real |
| Legacy Taiwan clinics | 17 without approved status | Hidden |
| Taiwan `officialClinicCatalog` | 22 documents | Anonymous access denied; app reference removed |
| Legacy reviews | 20 without approved status | Hidden |
| Legacy quotes | 4 without approved status | Hidden |
| Hong Kong pet-service directory | 124 approved | Included; no invented prices, ratings or hours |
| Hong Kong insurance directory | 3 approved | Official provider links only; no copied coverage or price claims |
| Legacy products and insurance | Existing records | Hidden from anonymous clients |
| Historical bundled clinic/merchant datasets | Not in Release target | Excluded |

Before each production migration, a complete raw backup of the affected
collections was saved under `build/backups/` with owner-only file permissions.
The guarded clinic migration is documented in
`scripts/restore_hk_clinic_catalog_v2.mjs`.

## Clinic database attestation and provenance

On 2026-07-29 the account holder stated:

> 原有 VetMap 診所 database 由我方建立或已獲授權使用

The generated manifest covers every input record: 176/176 main catalog rows
and 29/29 supplemental rows, represented by 205 unique lineage identifiers.
Two exact same-name/same-address duplicate pairs are published as one directory
entry each; both source identifiers and both phone numbers are retained.
Explicit moved/superseded seed records retain lineage to the current entry.

Part of the coordinate layer uses the HKSAR Digital Policy Office Address
Lookup Service under DATA.GOV.HK terms. The App's About screen identifies the
source, acknowledges Government and relevant-organisation ownership, links to
the dataset and terms, and states that Government does not endorse VetMap.

The public Terms grant VetMap a non-exclusive licence to store, display,
moderate and operate user-submitted content. This covers future submissions
made under those Terms.

The clinic-database confirmation above does not by itself approve the broader
live App Store Connect legal declaration for every other category. Before
automation changes Content Rights, the account holder must still expressly
confirm the complete declaration covering the clinic database, Hong Kong
service catalog, official insurance links and user-submitted content.

## App Store Connect declaration

VetMap contains or accesses third-party content because it displays business
directory facts and can display approved user-generated content. The correct
first answer is therefore **Yes**.

Accepting the separate legal attestation that the account holder has all
necessary rights remains an account-holder decision. Automation must stop
before that attestation unless the account holder expressly confirms it.
