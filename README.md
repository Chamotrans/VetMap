# VetMap

VetMap is a SwiftUI iOS app for finding and contributing community-reported veterinary clinic information across Taiwan and Hong Kong.

The current MVP focuses on a usable clinic discovery flow: map browsing, clinic list/search/filter, clinic detail actions, and local community submissions.

## Features

- Map-first clinic discovery with MapKit
- Clinic list with search, segmented filters, verification-first sorting
- Clinic detail pages with call, website, and Apple Maps route actions
- Add-clinic flow with local persistence
- Region-based or manual coordinate entry for new clinics
- Shared local repository updates so map and list stay in sync
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
- Clinic submissions currently persist locally in Application Support.
- Geocoding is not connected yet; the MVP uses region presets or manual coordinates.

## Roadmap

- Address geocoding for automatic coordinate lookup
- Firebase-backed clinic/review sync
- Review submission and moderation
- Real product and insurance data flows
- UI test coverage for the main add-clinic journey
