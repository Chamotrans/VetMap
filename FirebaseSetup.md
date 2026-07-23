# VetMap Firebase Production Setup

> Project ID: `vetmap-app`
> iOS bundle ID: `com.vetmap.app`
> App Store ID: `6777361219`
> Primary Firestore／Functions region: `asia-east1`

Firebase 是 VetMap 1.0 的必要後端。註冊、登入、投稿、審核、舉報、封鎖及帳戶刪除均不應以本機 mock 當作 production fallback。

## 1. iOS app registration

Firebase Console 的 iOS app 必須同時符合：

- Bundle ID：`com.vetmap.app`
- App Store ID：`6777361219`
- 本機 plist 路徑：`VetMap/GoogleService-Info.plist`
- `GoogleService-Info.plist` 不得提交到 Git

Xcode project 已連結：

- `FirebaseCore`
- `FirebaseAuth`
- `FirebaseFirestore`
- `FirebaseStorage`
- `FirebaseFunctions`
- `FirebaseCrashlytics`

`FirebaseAnalytics` 不屬於 1.0 release target。

## 2. Authentication

### Email/Password

Firebase Console → Authentication → Sign-in method → Email/Password：

- Email/Password：Enabled
- Email link：可保持 Disabled

### Sign in with Apple

必須同時完成 Apple Developer 及 Firebase 設定：

1. App ID `com.vetmap.app` 啟用 Sign in with Apple。
2. Apple Developer 建立／確認 Services ID。
3. 建立 Sign in with Apple key，保存 Team ID、Key ID 及 `.p8` private key。
4. Firebase Authentication → Apple provider 啟用。
5. 填入 Services ID、Team ID、Key ID 及 private key，完成 OAuth code flow。
6. 不把 `.p8`、secret 或 reviewer password 寫入 repo。
7. 以真實 Apple 帳戶測試登入、重新驗證、撤銷 token 及刪除帳戶。

只在 Xcode 加 capability 而沒有完成 Firebase Apple provider OAuth 設定並不足夠。

## 3. Firestore data model

| 路徑 | 用途 |
|---|---|
| `users/{uid}` | 私人 profile、role、premium 狀態 |
| `users/{uid}/blockedUsers/{blockedUid}` | 私人封鎖名單 |
| `submissions/{id}` | clinic／review／quote 待審 payload |
| `clinics/{id}` | 只放 `status: approved` 的公開診所 |
| `reviews/{id}` | 只放 `status: approved` 的公開評價 |
| `quotes/{id}` | 只放 `status: approved` 的公開報價 |
| `reports/{id}` | pending／resolved 舉報 |
| `reviewEngagement/{reviewId}` | 「有用」總數 |
| `reviewEngagement/{reviewId}/voters/{uid}` | 每 UID 一票 |

普通用戶只可：

- 建立及讀取自己的 pending submission；
- 建立自己的 pending report；
- 管理自己的 blockedUsers；
- 對每項評價建立一次 helpful vote；
- 讀取 approved 公開內容。

只有 `users/{uid}.role == "admin"` 的帳戶可批核、駁回、公開或下架內容。

## 4. Storage model

| 路徑 | 權限 |
|---|---|
| `submissionUploads/{uid}/{submissionId}/{file}` | 只限作者及管理員；圖片 MIME／10 MB 上限 |
| `public/{contentType}/{contentId}/{file}` | 公開讀；只限管理員建立／刪除 |

VetMap 1.0 的相片投稿 UI 已移除，但規則仍採 deny-by-default，避免日後路徑被誤用。

## 5. Account deletion function

`functions/index.js` 提供 `asia-east1` callable function `purgeUserData`：

- 要求 Firebase Auth；
- 要求 `auth_time` 在最近 5 分鐘；
- 清除 authored submissions、reviews、quotes、clinics、reports；
- 清除 blockedUsers、helpful vote 參照及 user profile；
- 清除 `submissionUploads` 等用戶 Storage prefixes。

2026-07-23 已啟用所需 APIs 並成功部署 Node.js 22 `purgeUserData`；狀態為 ACTIVE。Artifact Registry container image cleanup policy 設為 1 日。

如日後 Console 要求新的付費計劃或額外付費服務，仍必須由帳戶持有人先明確批准，不能自動新增支出。

## 6. Local rules and function verification

這些測試不等於 iOS build；正式 App build 只使用 Xcode Cloud。

```bash
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' \
firebase emulators:exec \
  --project demo-vetmap-rules \
  --only firestore,storage \
  "npm test --prefix firebase-tests"

npm run lint --prefix functions
node -e "require('./functions/index.js')"
```

目前基線：Rules tests 9/9、Functions lint 及 module load 通過。

## 7. Production deployment

由 repo root 執行：

```bash
firebase deploy \
  --project vetmap-app \
  --only firestore:rules,firestore:indexes,storage,functions,hosting
```

部署後逐項驗證：

```bash
firebase functions:list --project vetmap-app
firebase hosting:channel:list --project vetmap-app
node scripts/audit_firestore_public.mjs
```

並直接開啟：

- `https://vetmap-app.web.app`
- `https://vetmap-app.web.app/tos`
- `https://vetmap-app.web.app/support`

production 舊資料目前均沒有 `status: approved`。新規則部署後它們會被隔離；不要未經權利及內容審核就 bulk backfill 為 approved。

## 8. Xcode Cloud secret

Xcode Cloud workflow 必須建立 secret：

```text
GOOGLE_SERVICE_INFO_PLIST_BASE64
```

值是 production `VetMap/GoogleService-Info.plist` 的 base64 內容。`ci_scripts/ci_post_clone.sh` 會：

1. 以權限 `077` 寫入 plist；
2. 用 `plutil` 驗證；
3. 驗證 `BUNDLE_ID == com.vetmap.app`。

secret 必須標記為 Secret，不能在 log、commit 或 review notes 顯示原文。

## 9. Production smoke test

至少用兩個普通帳戶及一個 admin 帳戶驗證：

1. Email signup／login。
2. Apple login。
3. 三類投稿進入 pending。
4. Admin 批准後第二帳戶可見。
5. Helpful、report、block 按預期生效。
6. Admin 下架後普通帳戶不可見。
7. Email account deletion。
8. Apple account deletion 及 authorization revocation。

全部完成後才可在 [PREFLIGHT_CHECKLIST.md](PREFLIGHT_CHECKLIST.md) 勾選 Firebase production 項目。
