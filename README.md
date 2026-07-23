# VetMap — 寵物醫院地圖

> **願世間再無誤診毛孩** — 香港獸醫診所地圖與審核制毛孩社群。

## Stack

| Layer | Tech |
|-------|------|
| **App** | SwiftUI + Swift 6, iOS 17+ |
| **Map** | MapKit |
| **Backend** | Firebase (Auth + Firestore + Storage) |
| **Image** | Kingfisher v8 (`#if canImport` → AsyncImage fallback) |
| **IAP** | StoreKit 2 |
| **Crash** | Firebase Crashlytics + Analytics (`#if canImport` guarded) |
| **CI** | Xcode Cloud |

## Features

- **Map-first** discovery with MapKit annotations
- **Clinic search** — keyword, region, price, verified filters
- **Clinic detail** — call, website, Apple Maps route, reviews, quotes
- **Reviews** — star ratings, PhotosPicker, helpful voting
- **Quotes** — treatment cost transparency in HKD
- **Add clinic** — address geocoding + manual coordinate fallback
- **Auth** — Email/Password + Apple Sign In (+ Keychain persistence)
- **Moderation** — pending-first submissions, report and block controls
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
# Open the project for editing.
# This Mac runs a beta macOS; build, test and archive through Xcode Cloud only.
open VetMap.xcodeproj
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

## App Store Pitch

> "VetMap helps Hong Kong pet guardians discover veterinary clinics and share moderated reviews and treatment-cost references."

**Keywords for App Store reviewers:**
- 3-language support (zh-Hant-HK, zh-Hans, en)
- Hong Kong clinic names, addresses, phone numbers and map locations
- Community reviews with helpful voting
- Treatment cost transparency
- Widget + iPad + accessibility
- Firebase backend with Firestore
