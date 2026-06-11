# VetMap v1.0 — Release Notes

> **BUILD SUCCEEDED • 93 commits • 0 errors • 0 warnings • Archive ready**

## Data

| Type | Count | Source |
|------|-------|--------|
| Clinics | 222 (HK 29 + TW 17 + petcircle 176) | ePetPet API + petcircle curation |
| Reviews | 15 | Curated real HK/TW user reviews |
| Quotes | 16 | Real treatment cost data |
| Products | 127 (用品 51 + 美容 51 + 善終 25) | petcircle-hk.vercel.app |
| Insurance | 6 (3 TW + 3 HK) | Real market plans |
| **Total** | **386 documents** | **ALL REAL** |

## Features

- MapKit clinic discovery (222 HK + TW clinics)
- Clinic search, filter (keyword + region + price + verified)
- Clinic detail (call, website, route, reviews, quotes, services, hours)
- Review system (star rating, PhotosPicker, helpful voting)
- Quote sharing (13 treatment types, TWD/HKD dual currency)
- Pet products (127 products, 3 categories, search + filter)
- Pet insurance comparison (6 real plans, premium sorting)
- Email/Password + Apple Sign In authentication
- StoreKit 2 Premium (monthly/yearly, 7-day free trial)
- Widget extension (nearby clinics on home screen)
- iPad NavigationSplitView sidebar
- 3-language localization (zh-Hant-HK, zh-Hans, en) via .xcstrings
- Offline mode with NWPathMonitor
- Onboarding walkthrough (Warm Clinical aesthetic)
- 30+ VoiceOver accessibility labels
- In-app Safari browser for clinic websites
- Loading shimmers, error states, empty states
- Confetti celebration animation
- Review streaks / contributor badges

## UI/UX Design

- **Design system**: AppTheme (teal primary, indigo accent, orange warning)
- **Warm Clinical aesthetic**: Organic texture backgrounds, amber/gold tones
- **Clinic monogram avatars**: Custom initial-based avatars replacing generic icons
- **Custom fonts**: Rounded Mplus 1c for headings
- **Micro-interactions**: Press-scale cards, animated star ratings, symbol effects
- **Premium page**: Gradient hero, glass morphism cards, feature stagger animation

## Backend

- Firebase project: `vetmap-app`
- Firestore: asia-east1, security rules deployed
- Auth: Email/Password enabled
- Storage: asia-east1, security rules deployed
- Firebase SPM v12.5 + Kingfisher v8.0
- Firebase Hosting: privacy policy + TOS

## Quality

- 0 force-unwrap crash risks
- Thread-safe data access (quotes queue)
- Pre-commit hook (blocks API key leaks)
- Privacy manifest (PrivacyInfo.xcprivacy)
- CI/CD: GitHub Actions auto-build on push/PR
- Crashlytics + Analytics (#if canImport guarded)
- App Store rating prompt

## App Store Submission

- App ID: 6777361219
- Bundle ID: com.vetmap.app
- IAP: com.vetmap.premium.monthly + com.vetmap.premium.yearly
- Privacy Policy: https://vetmap-app.web.app
- TOS: https://vetmap-app.web.app/tos
- Support: https://github.com/Chamotrans/VetMap/issues

## Deploy

```bash
# Archive: build/VetMap-v1.0.xcarchive (83MB)
# Xcode → Product → Archive → Distribute App → Upload
```

## IDEAS Completion

58/100 ✅ Done | 42 📋 Roadmap
See: IDEAS_100.md

## Links

- Privacy: https://vetmap-app.web.app
- TOS: https://vetmap-app.web.app/tos
- Firebase: https://console.firebase.google.com/project/vetmap-app
- GitHub: https://github.com/Chamotrans/VetMap
