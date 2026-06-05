# VetMap — 寵物醫院地圖

> **Mission:** 「願世間再無誤診毛孩」— help pet owners find reliable vets with real reviews, pricing transparency, and community support across Taiwan and Hong Kong.

## Team Structure

| Role | Agent | Responsibility |
|------|-------|---------------|
| **Tech Lead** | Claude (orchestrator) | Architecture decisions, code review, integration, deployment |
| **iOS Infra** | swift-coder agent | Firebase SDK, Auth, data layer, services |
| **iOS Features** | swift-coder agent | Reviews, Quotes, Community features, Add Clinic |
| **iOS Commerce** | swift-coder agent | Products, Insurance, IAP, Premium subscription |
| **iOS UI/UX** | swift-coder agent | Design system, loading states, animations, localization |
| **QA** | swift-reviewer agent | Tests, edge cases, code review, verification |

## Tech Stack

- **Language:** Swift 6 + SwiftUI
- **Target:** iOS 17+
- **Map:** MapKit (Apple Maps)
- **Location:** CoreLocation
- **Backend:** Firebase (Auth, Firestore, Storage) — planned; currently using local JSON persistence
- **IAP:** StoreKit 2
- **Image caching:** Kingfisher (planned)
- **Testing:** XCTest

## Project Structure

```
VetMap/
├── VetMap.xcodeproj
├── VetMap/
│   ├── VetMapApp.swift              # @main entry point
│   ├── ContentView.swift            # Tab root + AppTheme + ViewModifiers
│   ├── Models/
│   │   ├── VetClinic.swift          # Core clinic model
│   │   ├── Review.swift             # Review + ReviewDraft
│   │   ├── UserProfile.swift        # Firebase Auth user
│   │   ├── PetProduct.swift         # E-commerce product
│   │   ├── Quote.swift              # Treatment cost quote
│   │   ├── Insurance.swift          # Pet insurance plan
│   │   ├── ClinicCoordinate.swift   # Lat/lng struct
│   │   └── ClinicSearchFilter.swift # Search/filter/sort logic
│   ├── Services/
│   │   ├── MockClinicRepository.swift    # Local clinic persistence + seed data
│   │   ├── MockCommunityRepository.swift # Local reviews/quotes + seed data
│   │   ├── LocationService.swift         # CLLocationManager wrapper
│   │   └── GeocodingService.swift        # CLGeocoder address → coordinate
│   ├── ViewModels/
│   │   ├── ClinicsViewModel.swift    # Clinic list + search/filter
│   │   ├── MapViewModel.swift        # Map annotations + camera
│   │   ├── ClinicDetailViewModel.swift # Reviews + quotes per clinic
│   │   └── AddClinicViewModel.swift  # Form + geocoding + validation
│   ├── Views/
│   │   ├── Map/ClinicMapView.swift
│   │   ├── Map/ClinicRowView.swift
│   │   ├── Clinics/ClinicListView.swift
│   │   ├── Clinics/ClinicListRowView.swift
│   │   ├── ClinicDetail/ClinicDetailView.swift
│   │   ├── ClinicDetail/AddReviewView.swift
│   │   ├── Community/AddClinicView.swift
│   │   ├── Shared/ClinicFilterControls.swift
│   │   ├── Shared/ComingSoonView.swift
│   │   └── TabViews/{Home,Clinics,Products,Profile}Tab.swift
│   └── Resources/
│       ├── Assets.xcassets
│       └── GoogleService-Info.plist (placeholder)
├── VetMapTests/
├── VetMapUITests/
├── Sources/VetMap/          # Swift Package (SPM structure)
├── Tests/VetMapTests/
├── Package.swift
├── PLAN.md                  # Full implementation plan (16 tasks, 6 phases)
├── README.md
└── CLAUDE.md                # This file
```

## Architecture Patterns

### MVVM
- **Models:** Pure Swift structs, Codable, Equatable
- **ViewModels:** `@MainActor`, `@ObservableObject`, `@Published`. Own business logic + data transformation.
- **Views:** SwiftUI, receive ViewModels via `@StateObject` or `@ObservedObject`. No business logic in Views.

### Data Flow
- Repositories publish changes via `NotificationCenter` (`.vetClinicRepositoryDidChange`, `.vetCommunityRepositoryDidChange`)
- ViewModels observe notifications and reload data reactively
- Currently local JSON persistence (Application Support/VetMap/*.json)
- Firebase migration planned: repositories will become Facades over Firestore + local cache

### Design System (`ContentView.swift` lines 34-85)
- `AppTheme` enum: `primary=teal`, `accent=indigo`, `warning=orange`
- `AppCardModifier`: card with rounded corners + hairline border
- `AppChipModifier`: tag chips with tint/filled variants
- View extensions: `.appCard()`, `.appChip()`

### Naming Conventions
- Chinese tab labels: 首頁, 診所, 好物, 我的
- ID format: `{type}-{region}-{name}` (e.g., `review-taipei-anxin-1`)
- Seed data: `reportedBy: "seed"`, user IDs: `seed-user-N`

## Current State (MVP - 5 commits)

### Done ✅
- 7 data models with Codable support
- MapKit map with clinic annotations + camera positioning
- Clinic list with keyword search + region/price/verified filters
- Clinic detail view with reviews, quotes, action buttons
- Add clinic form with address geocoding + manual coordinate fallback
- Add review form with local persistence
- Tab navigation (Home/Clinics/Products/Profile)
- Location service with permission handling
- Seed data: 4 clinics (2 Taipei, 2 HK), 5 reviews, 4 quotes

### In Progress / Next ⚡
- Firebase SDK integration (Task 2)
- Firebase Authentication (Task 3)
- Review system enhancement (Task 4)
- Quote sharing UI (Task 5)
- Pet products browse (Task 6)
- Insurance comparison (Task 7)
- IAP + Premium (Task 8)
- Polish + zh-Hant localization (Task 9)
- Tests (Task 10)

## Roadmap (Tech Lead Decision)

### Phase 4 — Quality Gate ⚡ NOW
| Task | Status |
|------|--------|
| Fix MockCommunityRepository dedup bug & 100% test pass | 🔄 |
| Run full test suite on simulator | ⏳ |
| Add tests for all new ViewModels | ⏳ |

### Phase 5 — Real Backend
| Task | Status |
|------|--------|
| Create Firebase project & GoogleService-Info.plist | ⏳ |
| Link Firebase SPM in Xcode | ⏳ |
| Replace all Mock*Repository with Firestore | ⏳ |
| Apple Sign In (ASAuthorizationController) | ⏳ |

### Phase 6 — Production Polish
| Task | Status |
|------|--------|
| Kingfisher image caching | ⏳ |
| App Store Connect record + IAP products | ⏳ |
| TestFlight beta distribution | ⏳ |
| Privacy manifest + App Tracking Transparency | ⏳ |

## Development Commands

```bash
# Build
xcodebuild -project VetMap.xcodeproj \
  -scheme VetMap \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build

# Test
xcodebuild -project VetMap.xcodeproj \
  -scheme VetMap \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO \
  test

# Open in Xcode
open VetMap.xcodeproj
```

## Constraints

- **Localization:** All user-facing text must support 3 languages initially (Hong Kong market requirement):
  - `zh-Hant-HK` — Traditional Chinese (Hong Kong) 🇭🇰
  - `zh-Hans` — Simplified Chinese 🇨🇳
  - `en` — English 🇬🇧🇺🇸
  - Use Xcode String Catalog (`.xcstrings`) format
  - Default/development language: `zh-Hant-HK`
- Support both Taiwan (TWD) and Hong Kong (HKD) regions
- No third-party map SDK — use MapKit only
- Firebase config (`GoogleService-Info.plist`) is a placeholder until real backend is ready
- Keep `MockClinicRepository` and `MockCommunityRepository` as fallback/local cache even after Firebase migration
- **SEED DATA RULE:** All dummy/seed/mock data MUST be explicitly marked. Use one or more of:
  - File-level comment at top: `// MARK: - ⚠️ DUMMY SEED DATA — 僅供開發測試用，上線前需替換為真實資料`
  - Property naming: prefix with `seed` or `dummy` (e.g., `static let seedClinics: [VetClinic]`)
  - Individual data point comments: `// DUMMY` for any fabricated value (phone numbers, addresses, prices, names)
  - Every `Mock*Repository` file must carry the dummy-data warning at the top
  - User-generated local data (reviews, quotes added via the app) is NOT dummy — only the pre-loaded seed data is
