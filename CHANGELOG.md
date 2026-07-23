# VetMap Changelog

## v1.0 (Release candidate, July 2026)

### Data
- 10 reviewed Hong Kong clinic directory entries with factual contact/location fields
- 1 clearly labelled VetMap-owned demo clinic, review and quote for App Review
- Legacy unapproved content remains hidden
- New treatment quote submissions use HKD

### Features
- MapKit clinic discovery with annotations
- Clinic search (keyword + region + price + verified filters)
- Clinic detail (call, website, route, reviews, quotes, services, hours)
- Add clinic form with address geocoding
- Review system (star rating, PhotosPicker, helpful voting)
- Quote sharing (13 treatment types, HKD)
- Email/Password + Apple Sign In authentication
- Widget extension (nearby clinics on home screen)
- iPad split view layout
- 3-language localization (zh-Hant-HK, zh-Hans, en)
- Offline mode with connectivity monitoring
- 30+ VoiceOver accessibility labels
- First-launch onboarding walkthrough
- App Store rating prompt
- In-app Safari browser for clinic websites

### Backend
- Firebase project: vetmap-app
- Firestore (asia-east1) with security rules deployed
- Authentication (Email/Password enabled)
- Storage (asia-east1) with security rules deployed
- Firebase SPM v12.5 + Kingfisher SPM v8.0
- 29 Firestore documents seeded (clinics)

### Infrastructure
- GitHub Actions CI/CD (build on push/PR)
- Crashlytics + Analytics integration (#if canImport guarded)
- Network monitoring (NWPathMonitor)
- Pre-commit hook (blocks API key leaks)
- Privacy manifest (PrivacyInfo.xcprivacy)
- Firebase Hosting (privacy policy + TOS)

### Bug Fixes
- Fixed 13 bugs (crash risks, data corruption, English services, blank screens, fake prices)
- Force-unwrap crashes eliminated
- Duplicate clinic IDs resolved (22 clinics shared 3 IDs)
- Thread-safe quotes queue added
- AppIcon consolidated and auto-detection fixed
- LaunchIcon restored

### UI/UX Improvements
- Clinic count in navigation title
- Product count in navigation title
- Data source attribution footer
- Loading shimmer for clinic list
- Tab badges removed (UX feedback)
- Booking CTA on OpenBeauty (sister project)
