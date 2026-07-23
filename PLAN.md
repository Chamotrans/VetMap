# 寵物醫院地圖 (VetMap) Implementation Plan

> **For Hermes:** Use Codex CLI and direct tooling to implement this plan task-by-task.

**Goal:** Build a community-driven vet clinic map iOS app for pet owners in Hong Kong.

**Core Philosophy:** "願世間再無誤診毛孩" — help pet owners find reliable vets with real reviews, pricing transparency, and community support.

**Tech Stack:**
- SwiftUI + Swift 6, iOS 17+
- MapKit (Apple Maps)
- Firebase (Auth, Firestore, Storage, Crashlytics)
- StoreKit 2 (IAP)
- Kingfisher (image caching)

---

## Phase 1: Project Scaffold & Foundation

### Task 1: Create Xcode Project

**Objective:** Initialize a SwiftUI iOS project with proper structure.

**Files:**
- Create: `~/Documents/VetMap/VetMap.xcodeproj`
- Create: `~/Documents/VetMap/VetMap/`

**Step 1: Initialize via Xcode or command-line**

We'll use Codex to create the project. The project structure should be:

```
VetMap/
├── VetMap.xcodeproj
├── VetMap/
│   ├── VetMapApp.swift
│   ├── ContentView.swift
│   ├── App/
│   │   ├── AppDelegate.swift
│   │   └── SceneDelegate.swift (if needed)
│   ├── Models/
│   ├── Views/
│   │   ├── Map/
│   │   ├── ClinicDetail/
│   │   ├── Review/
│   │   ├── Profile/
│   │   └── Community/
│   ├── ViewModels/
│   ├── Services/
│   │   ├── FirebaseService.swift
│   │   ├── LocationService.swift
│   │   └── IAPService.swift
│   ├── Utilities/
│   └── Resources/
│       ├── Assets.xcassets
│       └── GoogleService-Info.plist (placeholder)
├── VetMapTests/
└── VetMapUITests/
```

**Step 2: Verify build**

```bash
cd ~/Documents/VetMap && xcodebuild -project VetMap.xcodeproj -scheme VetMap -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
cd ~/Documents/VetMap && git init && git add -A && git commit -m "chore: initial project scaffold"
```

---

### Task 2: Create Core Models

**Objective:** Define all Swift data models for the app.

**Files:**
- Create: `VetMap/Models/VetClinic.swift`
- Create: `VetMap/Models/Review.swift`
- Create: `VetMap/Models/UserProfile.swift`
- Create: `VetMap/Models/PetProduct.swift`
- Create: `VetMap/Models/Quote.swift`
- Create: `VetMap/Models/Insurance.swift`

**Models to define:**

```swift
// VetClinic.swift
struct VetClinic: Identifiable, Codable {
    let id: String
    var name: String
    var address: String
    var coordinate: GeoPoint  // Firebase GeoPoint
    var latitude: Double
    var longitude: Double
    var phone: String
    var website: String?
    var openingHours: [String: String]  // ["Mon": "09:00-18:00", ...]
    var services: [String]  // ["一般診療", "外科", "牙科", ...]
    var avgRating: Double
    var reviewCount: Int
    var priceLevel: Int  // 1-3 ($, $$, $$$)
    var images: [String]  // URLs
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    var reportedBy: String  // user ID
    var verified: Bool
}

// Review.swift
struct Review: Identifiable, Codable {
    let id: String
    var clinicId: String
    var userId: String
    var userName: String
    var rating: Int  // 1-5
    var title: String
    var content: String
    var treatmentType: String?  // e.g. "疫苗接種", "外科手術"
    var cost: Double?
    var images: [String]?
    var createdAt: Date
    var updatedAt: Date
    var helpfulCount: Int
}

// UserProfile.swift (Firebase Auth UID as doc ID)
struct UserProfile: Identifiable, Codable {
    let id: String  // Auth UID
    var displayName: String
    var email: String
    var photoURL: String?
    var isPremium: Bool
    var premiumExpiry: Date?
    var favoriteClinics: [String]
    var savedProducts: [String]
    var createdAt: Date
}

// PetProduct.swift
struct PetProduct: Identifiable, Codable {
    let id: String
    var name: String
    var description: String
    var category: String  // "食品", "玩具", "保健", "藥品"
    var price: Double
    var currency: String
    var clinicId: String?  // if sold at clinic
    var affiliateURL: String?
    var imageURL: String?
    var tags: [String]
    var createdAt: Date
}

// Quote.swift
struct Quote: Identifiable, Codable {
    let id: String
    var clinicId: String
    var userId: String
    var treatmentType: String
    var estimatedCost: Double
    var actualCost: Double?
    var currency: String
    var notes: String
    var createdAt: Date
}

// Insurance.swift
struct Insurance: Identifiable, Codable {
    let id: String
    var providerName: String
    var planName: String
    var description: String
    var monthlyPremium: Double
    var annualPremium: Double
    var coverage: [String]
    var exclusions: [String]
    var website: String
    var contactPhone: String
}
```

**Verify:** Create a unit test that instantiates each model and checks Codable round-trip.

**Commit:** `git commit -m "feat: add core data models"`

---

### Task 3: Firebase Integration

**Objective:** Set up Firebase SDK, config, and service layer.

**Files:**
- Create: `VetMap/GoogleService-Info.plist` (placeholder, you fill in real one)
- Create: `VetMap/Services/FirebaseService.swift`
- Modify: `VetMap/VetMapApp.swift` (init Firebase)

**Step 1:** Add Firebase to project via Swift Package Manager (SPM).
- URL: `https://github.com/firebase/firebase-ios-sdk`
- Packages: FirebaseAuth, FirebaseFirestore, FirebaseStorage, FirebaseCrashlytics

**Step 2:** Create FirebaseService singleton:

```swift
import Firebase
import FirebaseFirestore

class FirebaseService {
    static let shared = FirebaseService()
    let db = Firestore.firestore()
    let auth = Auth.auth()
    let storage = Storage.storage()
    
    private init() {}
    
    // MARK: - Clinics
    func fetchClinics(completion: @escaping ([VetClinic]) -> Void) { ... }
    func addClinic(_ clinic: VetClinic) async throws { ... }
    func searchClinics(query: String) async throws -> [VetClinic] { ... }
    
    // MARK: - Reviews
    func fetchReviews(for clinicId: String) async throws -> [Review] { ... }
    func addReview(_ review: Review) async throws { ... }
    
    // MARK: - Products
    func fetchProducts(category: String?) async throws -> [PetProduct] { ... }
    
    // MARK: - Quotes
    func addQuote(_ quote: Quote) async throws { ... }
    func fetchQuotes(for clinicId: String) async throws -> [Quote] { ... }
}
```

**Step 3:** Init Firebase in app entry point.

**Step 4:** Set up Firestore indexes needed for queries.

**Verify:** Build succeeds with Firebase SDK linked.

**Commit:** `git commit -m "feat: integrate Firebase SDK and service layer"`

---

### Task 4: Location Service

**Objective:** Request location permission and provide current location.

**Files:**
- Modify: `VetMap/Info.plist` (add NSLocationWhenInUseUsageDescription)
- Create: `VetMap/Services/LocationService.swift`

**Commit:** `git commit -m "feat: add location service"`

---

## Phase 2: Core Features - Map & Clinic List

### Task 5: Map View with Clinic Annotations

**Objective:** Full-screen MapKit map with clinic pins.

**Files:**
- Create: `VetMap/Views/Map/ClinicMapView.swift`
- Create: `VetMap/ViewModels/MapViewModel.swift`
- Modify: `VetMap/ContentView.swift` (tab root)

**Commit:** `git commit -m "feat: add clinic map view with annotations"`

### Task 6: Clinic List View

**Objective:** Scrollable list of nearby clinics with rating, distance, price.

**Files:**
- Create: `VetMap/Views/Map/ClinicListView.swift`
- Create: `VetMap/Views/Map/ClinicRowView.swift`

**Commit:** `git commit -m "feat: add clinic list and row views"`

### Task 7: Clinic Detail View

**Objective:** Full detail page with info, photos, hours, reviews, map.

**Files:**
- Create: `VetMap/Views/ClinicDetail/ClinicDetailView.swift`
- Create: `VetMap/Views/ClinicDetail/ClinicInfoSection.swift`
- Create: `VetMap/Views/ClinicDetail/OpeningHoursView.swift`
- Create: `VetMap/Views/ClinicDetail/PhotoGalleryView.swift`

**Commit:** `git commit -m "feat: add clinic detail view"`

### Task 8: Review System

**Objective:** Add/view reviews, ratings, photo uploads.

**Files:**
- Create: `VetMap/Views/Review/ReviewListView.swift`
- Create: `VetMap/Views/Review/ReviewRowView.swift`
- Create: `VetMap/Views/Review/AddReviewView.swift`
- Create: `VetMap/ViewModels/ReviewViewModel.swift`

**Commit:** `git commit -m "feat: add review system"`

---

## Phase 3: Community & Social

### Task 9: Add Clinic Form

**Objective:** Allow users to submit new clinics.

**Files:**
- Create: `VetMap/Views/Community/AddClinicView.swift`
- Create: `VetMap/ViewModels/AddClinicViewModel.swift`

**Commit:** `git commit -m "feat: add clinic submission form"`

### Task 10: Quote System

**Objective:** Users share treatment cost estimates.

**Files:**
- Create: `VetMap/Views/Community/QuoteListView.swift`
- Create: `VetMap/Views/Community/AddQuoteView.swift`
- Create: `VetMap/ViewModels/QuoteViewModel.swift`

**Commit:** `git commit -m "feat: add quote/price sharing system"`

---

## Phase 4: User System & IAP

### Task 11: Authentication

**Objective:** Firebase Auth with email + Apple Sign In.

**Files:**
- Create: `VetMap/Views/Profile/LoginView.swift`
- Create: `VetMap/Views/Profile/SignUpView.swift`
- Create: `VetMap/ViewModels/AuthViewModel.swift`

**Commit:** `git commit -m "feat: add authentication"`

### Task 12: Profile & Premium

**Objective:** User profile, favorites, premium subscription.

**Files:**
- Create: `VetMap/Views/Profile/ProfileView.swift`
- Create: `VetMap/Views/Profile/FavoritesView.swift`
- Create: `VetMap/Views/Profile/PremiumView.swift`
- Create: `VetMap/Services/IAPService.swift`
- Create: `VetMap/Resources/Products.storekit`

**IAP Plans:**
- Monthly: NT$80 / HK$20 (approx US$2.5)
- Yearly: NT$1000 / HK$250 (approx US$30)

**Premium Features:**
- Full clinic database access
- Monthly exclusive features
- Community group access
- Ad-free experience

**Commit:** `git commit -m "feat: add IAP and premium subscription"`

---

## Phase 5: Products & Insurance

### Task 13: Pet Products Section

**Objective:** Browse pet products, affiliate links.

**Files:**
- Create: `VetMap/Views/Products/ProductListView.swift`
- Create: `VetMap/Views/Products/ProductDetailView.swift`
- Create: `VetMap/ViewModels/ProductViewModel.swift`

**Commit:** `git commit -m "feat: add pet products section"`

### Task 14: Insurance Info

**Objective:** Browse and compare pet insurance plans.

**Files:**
- Create: `VetMap/Views/Insurance/InsuranceListView.swift`
- Create: `VetMap/Views/Insurance/InsuranceDetailView.swift`

**Commit:** `git commit -m "feat: add pet insurance section"`

---

## Phase 6: Tab Navigation & Polish

### Task 15: Main Tab Bar Setup

**Objective:** Wire up all four tabs.

**Tabs:**
1. 首頁 (Home) — Map + nearby clinics
2. 獸醫診所 (Clinics) — List + search + filter
3. 毛孩好物 (Products) — Pet products + insurance
4. 我的 (Profile) — Profile + favorites + premium + settings

**Files:**
- Modify: `VetMap/ContentView.swift`
- Create: `VetMap/Views/TabViews/HomeTab.swift`
- Create: `VetMap/Views/TabViews/ClinicsTab.swift`
- Create: `VetMap/Views/TabViews/ProductsTab.swift`
- Create: `VetMap/Views/TabViews/ProfileTab.swift`

**Commit:** `git commit -m "feat: wire up main tab navigation"`

### Task 16: Polish & UX

**Objective:** Loading states, error handling, localization (zh-Hant).

**Files:**
- Create: `VetMap/Utilities/LoadingView.swift`
- Create: `VetMap/Utilities/ErrorView.swift`
- Create: `VetMap/Utilities/EmptyStateView.swift`
- Create: `VetMap/Resources/Localizable.xcstrings`

**Commit:** `git commit -m "feat: add loading states and zh-Hant localization"`

---

## Execution Instructions

For each task, use Codex CLI in PTY mode:
```bash
codex exec --full-auto 'Task description with all context'
```

Monitor progress with:
```bash
process(action="poll", session_id="<id>")
```

When stuck or needs input, I (Hermes) step in to unblock.
