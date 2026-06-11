# 🚀 VetMap Pre-Flight Checklist

> App Store Connect ID: 6777361219 • Bundle: com.vetmap.app
> Updated: 2026-06-10

## App Store Connect
- [x] App record created (ID: 6777361219)
- [x] App name: VetMap - 寵物醫院地圖
- [x] Category: Medical / Lifestyle
- [x] Privacy policy URL: https://vetmap-app.web.app
- [x] TOS URL: https://vetmap-app.web.app/tos
- [ ] Screenshots uploaded (6.7" + 6.5" displays) ← **NEEDS ACTION**
- [x] App description ready (zh-Hant-HK, zh-Hans, en) — see AppStoreMetadata.md
- [x] Keywords optimized (100 chars)
- [ ] Age rating questionnaire ← **NEEDS ACTION (App Store Connect)**
- [x] Copyright: © 2026 VetMap

## IAP
- [x] Monthly subscription: com.vetmap.premium.monthly
- [x] Yearly subscription: com.vetmap.premium.yearly
- [ ] IAP pricing configured in App Store Connect ← **NEEDS ACTION**
- [x] Products.storekit synced

## Firebase
- [x] Project: vetmap-app
- [x] Firestore: asia-east1, rules deployed
- [x] Auth: Email/Password enabled
- [x] Storage: asia-east1, rules deployed
- [x] Hosting: privacy policy + TOS deployed
- [ ] API key restricted to iOS app (bundle: com.vetmap.app) ← **RECOMMENDED**

## Code Quality
- [x] BUILD SUCCEEDED (0 errors, 0 warnings)
- [x] 93 commits on main
- [x] Archive ready (build/VetMap-v1.0.xcarchive, 83MB)
- [ ] TestFlight build uploaded ← **NEEDS ACTION**
- [x] Crashlytics configured
- [x] Analytics configured

## Privacy & Legal
- [x] PrivacyInfo.xcprivacy bundle included
- [x] Privacy labels defined (email, name, location, user content, user ID, purchase history, photos)
- [x] ITSAppUsesNonExemptEncryption = false
- [x] Location usage description (zh-Hant)
- [x] Photo library usage description
- [x] Camera usage description
- [x] Privacy policy page deployed
- [x] Terms of service page deployed
- [x] LICENSE (MIT)
- [x] Support URL (GitHub Issues)

## Localization
- [x] zh-Hant-HK (Traditional Chinese HK)
- [x] zh-Hans (Simplified Chinese)
- [x] en (English)
- [x] String Catalog (.xcstrings format)

## Security
- [x] Pre-commit hook (blocks API key leaks)
- [x] GoogleService-Info.plist gitignored
- [x] Old leaked key revoked + rotated
- [x] SECURITY.md published

## Final Verification
- [ ] Real device test — login, search, add review
- [ ] Dark mode appearance
- [ ] iPad layout (sidebar split view)
- [ ] Network error handling (airplane mode test)
- [ ] App Store Review Guidelines compliance check
- [ ] No private API usage
- [ ] App icon verified on device
