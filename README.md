# VetMap — 寵物醫院地圖

> **願世間再無誤診毛孩** — Community-driven vet clinic discovery for Taiwan & Hong Kong.

## Stack

| Layer | Tech |
|-------|------|
| **App** | SwiftUI + Swift 6, iOS 17+ |
| **Map** | MapKit |
| **Backend** | Firebase (Auth + Firestore + Storage) |
| **Image** | Kingfisher v8 (`#if canImport` → AsyncImage fallback) |
| **IAP** | StoreKit 2 |
| **Crash** | Firebase Crashlytics + Analytics (`#if canImport` guarded) |
| **CI** | GitHub Actions |

## Features

- **Map-first** discovery with MapKit annotations
- **Clinic search** — keyword, region, price, verified filters
- **Clinic detail** — call, website, Apple Maps route, reviews, quotes
- **Reviews** — star ratings, PhotosPicker, helpful voting
- **Quotes** — treatment cost transparency, 13 types, TWD/HKD
- **Add clinic** — address geocoding + manual coordinate fallback
- **Products** — 2-/3-column grid, 4 categories, 10 seed products
- **Insurance** — 6 TW/HK plans, premium comparison
- **Auth** — Email/Password + Apple Sign In (+ Keychain persistence)
- **Premium** — StoreKit 2 monthly/yearly subscriptions
- **Widget** — Nearby clinics home screen widget (iOS 17+)
- **iPad** — NavigationSplitView sidebar, 3-column product grid
- **Offline** — NWPathMonitor, offline banner, retry
- **A11y** — 30+ VoiceOver labels (zh-Hant-HK)
- **i18n** — zh-Hant-HK / zh-Hans / en (30+ keys)

## Project

```
21 commits • BUILD SUCCEEDED • 0 errors, 0 warnings
63+ Swift files • 72 tests • Firebase: vetmap-app
```

## Quick Start

```bash
# Build
xcodebuild -project VetMap.xcodeproj -scheme VetMap \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

# Test
xcodebuild -project VetMap.xcodeproj -scheme VetMap \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO test

# Archive for TestFlight
bash scripts/archive.sh
```

## Docs

| File | |
|------|----|
| `CLAUDE.md` | Architecture, patterns, constraints |
| `PLAN.md` | Original 16-task implementation plan |
| `FirebaseSetup.md` | Firebase project setup guide |
| `AppStoreSetup.md` | App Store Connect submission guide |
| `AppStoreMetadata.md` | Descriptions, keywords, screenshots plan |
| `PREFLIGHT_CHECKLIST.md` | 35-item launch checklist |
| `SECURITY.md` | Security policy + pre-commit hook |
