# VetMap 1.0 — Content Rights Packet

> Release candidate: pending Hong Kong Xcode Cloud build
> Audited: 2026-07-24
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

- 10 existing Hong Kong clinic records, normalized in place on 2026-07-24;
- one VetMap-owned, clearly non-real App Review demo clinic;
- one VetMap-owned demo review and one demo quote.

The 10 Hong Kong entries retain only factual name, address, phone and map
coordinate fields. Unverified ratings, review totals, price levels, services,
opening hours, emergency claims, tags and images were cleared. They are marked
`verified: false`. The migration preserved the original document IDs and made
no Taiwan record public.

Legacy reviews and quotes remain hidden. New user submissions remain pending
until an administrator approves them. The Terms of Service contains the
contributor licence for user-submitted content.

## Production audit boundary

| Content | Public state | Decision |
|---|---|---|
| Normalized Hong Kong clinic entries | 10 approved | Included, factual fields only |
| VetMap App Review fixtures | 1 clinic, 1 review, 1 quote | Included and labelled non-real |
| Legacy Taiwan clinics | 17 without approved status | Hidden |
| Taiwan `officialClinicCatalog` | 22 documents | Anonymous access denied; app reference removed |
| Legacy reviews | 20 without approved status | Hidden |
| Legacy quotes | 4 without approved status | Hidden |
| Products and insurance | Existing records | Admin-only; feature UI disabled |
| Historical bundled clinic/merchant datasets | Not in Release target | Excluded |

Before migration, a complete raw backup of `clinics`, `reviews` and `quotes`
was saved under `build/backups/` with owner-only file permissions. The
one-time guarded migration is documented in
`scripts/restore_hk_firestore_catalog.mjs`.

## Rights evidence and unresolved attestation

The 10 included clinic records were already present in production Firestore and
carry the historical source marker `reportedBy: epetpet-hk`. The repository
does not contain a commercial-reuse licence or direct permission document for
that source. Limiting publication to factual business identity and contact data
reduces inaccurate-content risk, but does not by itself prove the account
holder's legal right to publish it.

The account holder must therefore confirm and retain the applicable permission,
licence or other legal basis before accepting App Store Connect's Content
Rights attestation. If that confirmation cannot be made, the 10 records must be
hidden again before submission.

The public Terms grant VetMap a non-exclusive licence to store, display,
moderate and operate user-submitted content. This covers future submissions
made under those Terms, but does not retroactively prove rights to the existing
clinic catalog.

## App Store Connect declaration

VetMap contains or accesses third-party content because it displays business
directory facts and can display approved user-generated content. The correct
first answer is therefore **Yes**.

Accepting the separate legal attestation that the account holder has all
necessary rights remains an account-holder decision. Automation must stop
before that attestation unless the account holder expressly confirms it.
