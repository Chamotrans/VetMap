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

### Done ✅ (All 10 original tasks + 6 bonus tasks)
- 7 data models with Codable support
- MapKit map with clinic annotations + camera positioning
- Clinic list with keyword search + region/price/verified filters
- Clinic detail view with reviews, quotes, action buttons
- Add clinic form with address geocoding + manual coordinate fallback
- Full review system with PhotosPicker, star ratings, helpful voting
- Quote sharing system with cost transparency (13 treatment types)
- Pet products browse (2-column grid, category filter, 10 seed products)
- Insurance comparison (6 plans TW/HK, premium sorting, similar plan recommendations)
- Firebase SDK integration with conditional compilation (builds without Firebase SPM)
- Firebase Authentication (Email + Apple Sign In stub, local-only mode fallback)
- IAP + Premium subscription (StoreKit 2, monthly/yearly plans, restore purchases)
- UI polish: LoadingView, ErrorView, EmptyStateView, Haptics
- 3-language localization: zh-Hant-HK, zh-Hans, en (30+ keys in .xcstrings)
- 72 unit tests (up from original ~20), all passing
- Tab navigation (Home/Clinics/Products/Profile)
- Location service with permission handling
- Seed data: 4 clinics (2 Taipei, 2 HK), 5 reviews, 4 quotes, 10 products, 6 insurance plans
- Firebase setup documentation + Firestore/Storage security rules
- Kingfisher image caching utility (#if canImport fallback to AsyncImage)
- App Store Connect setup guide
- All seed data explicitly marked with DUMMY warnings

## Roadmap (Tech Lead Decision)

### Phase 4 — Quality Gate ✅ DONE
| Task | Status |
|------|--------|
| Fix MockCommunityRepository dedup bug & 100% test pass | ✅ 72/72 |
| Run full test suite on simulator | ✅ pass |
| Add tests for all new ViewModels (Auth/Review/Quote/Product/Insurance/Premium) | ✅ +35 tests |

### Phase 5 — Real Backend ✅ DONE
| Task | Status |
|------|--------|
| FirebaseSetup.md + FirestoreRules.rules + StorageRules.rules | ✅ |
| GoogleService-Info.plist ready (placeholder with instructions) | ✅ |
| Conditional compilation verified (builds without Firebase SPM) | ✅ |
| Apple Sign In (ASAuthorizationController stub ready) | ✅ |

### Phase 6 — Production Polish ✅ DONE
| Task | Status |
|------|--------|
| KingfisherImage utility view (#if canImport fallback to AsyncImage) | ✅ |
| KingfisherSetup.md | ✅ |
| AppStoreSetup.md (record, IAP, screenshots, privacy, TestFlight) | ✅ |
| Products.storekit matching IAP product IDs | ✅ |

### Next Steps (when ready to launch)
| Priority | Task |
|----------|------|
| 🔴 | Add Firebase SPM in Xcode + real GoogleService-Info.plist |
| 🔴 | Replace Mock*Repository with Firestore-backed repositories |
| 🔴 | Implement Apple Sign In full flow |
| 🟡 | Add Kingfisher SPM + migrate existing images to KingfisherImage |
| 🟡 | Create App Store Connect record + configure IAP products |
| 🟢 | Privacy manifest (PrivacyInfo.xcprivacy) |
| 🟢 | Screenshots + TestFlight beta |

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
