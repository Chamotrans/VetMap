# Firebase Setup for VetMap

This guide walks through setting up the Firebase backend for the VetMap iOS app.

---

## 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **Add project** (or **Create a project**)
3. Enter project name: `VetMap`
4. Choose whether to enable Google Analytics (recommended: yes)
5. Accept the terms and click **Create project**
6. Wait for provisioning to complete, then click **Continue**

---

## 2. Register the iOS App

1. In the Firebase Console, open your VetMap project
2. Click the iOS icon (**+ Add app** → **iOS**)
3. Fill in the form:
   - **iOS bundle ID**: `com.vetmap.app` (must match the bundle ID in Xcode)
   - **App nickname**: `VetMap`
   - **App Store ID**: leave blank for now
4. Click **Register app**
5. Download **GoogleService-Info.plist**
6. Move the downloaded file to:
   ```
   VetMap/VetMap/Resources/GoogleService-Info.plist
   ```
   (Replace the placeholder that is already there)
7. In Xcode, verify the file is added to the VetMap target (it should be auto-detected)
8. Skip the "Add Firebase SDK" step in the console wizard — we use Swift Package Manager instead (see section 6)
9. Click **Next** then **Continue to Console**

---

## 3. Enable Authentication

### 3.1 Email/Password Authentication

1. In Firebase Console, go to **Authentication** (left sidebar under "Build")
2. Click **Get started**
3. Go to the **Sign-in method** tab
4. Click **Email/Password**
5. Toggle **Enable** to ON
6. Click **Save**

### 3.2 Apple Sign In

1. Still in the **Sign-in method** tab
2. Click **Apple**
3. Toggle **Enable** to ON
4. Configure:
   - OAuth code flow configuration: leave defaults
   - You will need to set up **Sign in with Apple** in Xcode under
     **Signing & Capabilities** → **+ Capability** → **Sign In With Apple**
5. Click **Save**

### 3.3 (Optional) Add Test Users via Console

1. Go to **Authentication** → **Users** tab
2. Click **Add user**
3. Enter email and password for a test account
4. Click **Add user**

---

## 4. Enable Firestore Database

1. In Firebase Console, go to **Firestore Database** (under "Build")
2. Click **Create database**
3. Choose a location:
   - For Taiwan users: `asia-east1` (Taiwan)
   - For Hong Kong users: `asia-east2` (Hong Kong)
   - For mixed audiences: `asia-east1` is a safe default
4. Choose **Start in test mode** (we will lock it down with rules in section 8)
5. Click **Enable**

---

## 5. Enable Firebase Storage

1. In Firebase Console, go to **Storage** (under "Build")
2. Click **Get started**
3. Choose **Start in test mode** (we will lock it down with rules in section 9)
4. Choose a storage location (same region as Firestore is recommended)
5. Click **Done**

---

## 6. Add Firebase SDK via Swift Package Manager

1. In Xcode, open the VetMap project
2. Go to **File** → **Add Package Dependencies...**
3. Enter the Firebase iOS SDK URL:
   ```
   https://github.com/firebase/firebase-ios-sdk
   ```
4. Click **Add Package**
5. Select the following libraries:
   - `FirebaseAuth`
   - `FirebaseFirestore`
   - `FirebaseStorage`
6. Ensure the target is **VetMap**
7. Click **Add Package**

Once these packages are linked, the `#if canImport(Firebase)` conditional compilation gates will activate and the app will attempt to connect to your Firebase backend.

> **Note:** The app is designed to compile and run **without** Firebase SPM linked. It falls back to local mock data seamlessly.

---

## 7. Create Firestore Collections (Optional)

The app auto-creates documents as users interact, but you can seed initial data:

| Collection | Document ID convention | Purpose |
|------------|----------------------|---------|
| `clinics` | `clinic-{region}-{name}` | Vet clinic listings |
| `reviews` | `review-{region}-{clinic}-{n}` | User reviews |
| `quotes` | `quote-{region}-{clinic}-{n}` | Treatment cost quotes |
| `products` | `product-{id}` | Pet products (e-commerce) |
| `insurances` | `insurance-{id}` | Pet insurance plans |

---

## 8. Set Up Firestore Security Rules

Copy the contents of `FirestoreRules.rules` (in this directory) into:

1. Firebase Console → **Firestore Database** → **Rules** tab
2. Replace the existing rules
3. Click **Publish**

These rules enforce:
- Public read access for clinics, products, and insurances
- Authenticated users can create reviews and quotes
- Users can only edit/delete their own content (field `authorId` must match `request.auth.uid`)
- Direct writes to the `clinics` collection are restricted (clinic creation goes through review first)

---

## 9. Set Up Storage Security Rules

Copy the contents of `StorageRules.rules` (in this directory) into:

1. Firebase Console → **Storage** → **Rules** tab
2. Replace the existing rules
3. Click **Publish**

These rules enforce:
- Public read access for all files
- Authenticated users can upload files up to 10 MB
- Uploads are organized by user ID: `/{userId}/{filename}`
- Users can only delete files they own

---

## 10. Verify the Setup

1. Build and run the app on a physical device (not simulator — Firebase configure is skipped on simulator by design; see `VetMapApp.swift` line 18)
2. Check the Xcode console — you should see NO "Firebase SDK not linked" or "GoogleService-Info.plist not found" messages
3. Try signing up with an email/password in the Profile tab
4. Check Firebase Console → **Authentication** → **Users** to confirm the user was created
5. Add a review or quote — check Firestore to confirm the document was written

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| "Firebase: GoogleService-Info.plist not found" | File missing or not in target | Check file is in Resources folder and added to VetMap target |
| "Firebase SDK not linked" | SPM packages not added | Follow section 6 |
| Auth error: "invalid-email" | Email format issue | Verify email is valid |
| Auth error: "weak-password" | Password too short | Use at least 6 characters |
| Firestore write fails silently | Security rules block it | Check rules in Firebase Console → Firestore → Rules |
| Simulator skips Firebase | By design | Use a physical device, or remove the simulator guard in `VetMapApp.swift` line 18 |
| `FirebaseApp.configure()` called twice | Duplicate configure call | Only `VetMapApp.init()` calls configure — check for accidental duplicate |

---

## Files to Add to .gitignore

```
GoogleService-Info.plist
```

The placeholder plist in the repo is safe to commit (it has no real keys). The real plist downloaded from Firebase Console must NOT be committed.
