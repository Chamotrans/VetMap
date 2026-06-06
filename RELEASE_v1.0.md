# VetMap v1.0 — Release Notes

> **BUILD SUCCEEDED • 56 commits • 0 errors • 0 warnings • Archive ready**

## Data

| Type | Count | Source |
|------|-------|--------|
| Clinics | 46 (HK 29 + TW 17) | ePetPet API + curation |
| Reviews | 15 | Curated real HK/TW user reviews |
| Quotes | 16 | Real treatment cost data |
| Products | 170 | petcircle-hk.vercel.app (904 fetched) |
| Insurance | 6 | Real TW + HK market plans |
| **Total** | **253 documents** | **ALL REAL** |

## Features

- MapKit clinic discovery (HK + TW)
- Clinic search, filter, detail, reviews, quotes
- Pet products (170 stores across 3 categories)
- Pet insurance comparison (6 plans)
- Email + Apple Sign In + Keychain persistence
- StoreKit 2 Premium (monthly/yearly)
- Widget extension (nearby clinics)
- iPad sidebar split view
- 3-language localization (zh-Hant-HK, zh-Hans, en)
- Offline mode with NWPathMonitor
- 30+ VoiceOver accessibility labels
- Crashlytics + Analytics integration
- Privacy policy + TOS (Firebase Hosting)

## Backend

- Firebase project: `vetmap-app`
- Firestore: asia-east1, 29 clinics + rules deployed
- Auth: Email/Password enabled
- Storage: asia-east1, rules deployed
- Firebase SPM v12.5 + Kingfisher v8.0

## Quality

- 0 force-unwrap crash risks
- Thread-safe data access
- Pre-commit hook (blocks API key leaks)
- Privacy manifest (PrivacyInfo.xcprivacy)
- CI/CD: GitHub Actions auto-build

## Deploy

```bash
# Archive: build/VetMap-v1.0.xcarchive (83MB)
# Xcode → Organizer → Distribute App → Upload
```

## Links

- Privacy: https://vetmap-app.web.app
- TOS: https://vetmap-app.web.app/tos
- Firebase: https://console.firebase.google.com/project/vetmap-app
- GitHub: https://github.com/Chamotrans/VetMap
