# VetMap

VetMap is a SwiftUI iOS app for finding and contributing community-reported veterinary clinic information across Taiwan and Hong Kong.

The current MVP focuses on a usable clinic discovery flow: map browsing, clinic list/search/filter, clinic detail actions, and local community submissions.

## Features

- Map-first clinic discovery with MapKit
- Clinic list with keyword search, region/verification/price filters, and verification-first sorting
- Clinic detail pages with call, website, Apple Maps route actions, community reviews, and quote references
- Add-clinic flow with address geocoding, manual coordinate fallback, and local persistence
- Add-review flow with local persistence for early community submissions
- Shared local repository updates so map, list, and detail screens stay in sync
- SwiftUI visual system with consistent cards, chips, safe-area handling, and iOS-style material overlays

## Tech Stack

- SwiftUI
- MapKit
- CoreLocation
- StoreKit configuration placeholder
- XCTest
- iOS 17+

## Project Structure

```text
VetMap/
├── VetMap.xcodeproj
├── VetMap/
│   ├── Models/
│   ├── Services/
│   ├── ViewModels/
│   ├── Views/
│   ├── Resources/
│   ├── ContentView.swift
│   └── VetMapApp.swift
├── VetMapTests/
├── VetMapUITests/
└── PLAN.md
```

## Getting Started

Open the project in Xcode:

```bash
open VetMap.xcodeproj
```

Build from the command line:

```bash
xcodebuild -project VetMap.xcodeproj \
  -scheme VetMap \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run tests:

```bash
xcodebuild -project VetMap.xcodeproj \
  -scheme VetMap \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

## Notes

- `VetMap/Resources/GoogleService-Info.plist` is a placeholder. Replace it with a real Firebase config only when Firebase integration is ready.
- Clinic and review submissions currently persist locally in Application Support.
- Address lookup uses CoreLocation geocoding, with region presets and manual coordinates as fallback paths.

## Roadmap

- Firebase-backed clinic/review sync
- Review moderation, reporting, and trust signals
- Quote submission beyond seed data
- Real product and insurance data flows
- UI test coverage for the main add-clinic journey
