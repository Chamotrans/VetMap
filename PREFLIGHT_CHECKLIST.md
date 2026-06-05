# 🚀 VetMap Pre-Flight Checklist

## App Store Connect
- [ ] App record created (bundle: com.vetmap.app)
- [ ] App name: VetMap - 寵物醫院地圖
- [ ] Category: Medical / Lifestyle
- [ ] Privacy policy URL configured
- [ ] Screenshots uploaded (6.7" + 6.5" displays)
- [ ] App description (zh-Hant-HK, zh-Hans, en)
- [ ] Keywords optimized
- [ ] Rating: 17+

## IAP
- [ ] Monthly subscription: com.vetmap.premium.monthly
- [ ] Yearly subscription: com.vetmap.premium.yearly
- [ ] IAP pricing configured
- [ ] Products.storekit synced

## Firebase
- [x] Project: vetmap-app
- [x] Firestore: asia-east1, 29 docs seeded
- [x] Auth: Email/Password enabled
- [x] Storage: asia-east1, rules deployed
- [x] Security rules: Firestore + Storage deployed
- [ ] API key restricted to iOS app (bundle: com.vetmap.app)

## Code Quality
- [x] BUILD SUCCEEDED (0 errors, 0 warnings)
- [x] 72 unit tests
- [ ] TestFlight build uploaded
- [ ] Crashlytics configured
- [ ] Analytics configured (optional)

## Privacy & Legal
- [x] PrivacyInfo.xcprivacy
- [x] Location usage description (zh-Hant)
- [x] Photo library usage description
- [x] Camera usage description
- [ ] Terms of service URL
- [ ] Support contact email/URL

## Localization
- [x] zh-Hant-HK (Traditional Chinese HK)
- [x] zh-Hans (Simplified Chinese)
- [x] en (English)

## Security
- [x] Pre-commit hook (blocks API key leaks)
- [x] GoogleService-Info.plist gitignored
- [x] Old leaked key revoked + rotated

## Final Verification
- [ ] Real device test — login, search, add review
- [ ] Dark mode appearance
- [ ] iPad layout (if supported)
- [ ] Network error handling (airplane mode test)
- [ ] App Store Review Guidelines compliance check
