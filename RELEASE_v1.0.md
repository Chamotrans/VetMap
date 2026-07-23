# VetMap iOS 1.0 — Release Candidate Notes

> 目前狀態：準備權利安全的 Xcode Cloud build `1.0 (7)`；Build 6 已成功但不可送審；尚未正式提交 App Review。
> 本文件不以舊本機 archive、舊 commit 數或未部署設定冒充 release proof。

## 首版範圍

- 已審核獸醫診所的地圖、列表、搜尋、篩選、電話、網站及導航
- 電郵／密碼註冊及登入
- Sign in with Apple
- 新增診所、評價及治療報價
- 所有社群投稿先進入雲端待審佇列，批准後才公開
- 評價、報價及診所舉報
- 封鎖評價／報價作者
- 每帳戶一次的評價「有用」標記
- App 內帳戶及相關用戶資料刪除

## 明確不在 1.0 公開範圍

- Premium 訂閱及 IAP：程式碼仍保留作後續版本，但 `FeatureFlags.premiumEnabled` 為 `false`
- 商戶／產品／保險目錄：沒有 release-grade rights packet，`FeatureFlags.catalogEnabled` 為 `false`
- 評價相片：上載流程未達 release 標準，相關 UI 及相機／相簿權限已移除
- Firebase Analytics：release target 已移除；首版不收集搜尋字或產品互動事件
- Widget：不列作 1.0 承諾功能

## 社群安全架構

| 路徑 | 功能 | 普通用戶權限 |
|---|---|---|
| `submissions/{id}` | 診所／評價／報價待審內容 | 只可建立及讀取自己的 pending 投稿 |
| `clinics/{id}` | 已批准診所 | 只讀 |
| `reviews/{id}` | 已批准評價 | 只讀 |
| `quotes/{id}` | 已批准報價 | 只讀 |
| `reports/{id}` | 舉報 | 只可建立自己的 pending 舉報 |
| `users/{uid}/blockedUsers/{blockedUid}` | 私人封鎖名單 | 只限本人 |
| `reviewEngagement/{reviewId}/voters/{uid}` | 每人一次「有用」標記 | 只可建立自己的 vote |

公開 collection 只有管理員可以建立或刪除。管理員批准投稿時，以 batch 同步建立公開文件及更新 submission 狀態。

## 帳戶刪除

刪除流程要求最近登入：

1. 電郵帳戶重新輸入密碼，或 Apple 帳戶重新取得 Apple credential。
2. 重新驗證 Firebase Auth。
3. 呼叫 `asia-east1` callable function `purgeUserData` 清除 Firestore 及 Storage 內的用戶資料。
4. Apple 帳戶撤銷 authorization code。
5. 刪除 Firebase Auth user，再清除本機資料。

## 資料及內容邊界

- Build 7 不包含內置診所、商戶、保險、評價或報價資料；不要再使用「ALL REAL」、「全部已驗證」等無法證明的宣傳字眼。
- production 舊 cloud 文件缺少 moderation 狀態，會在新規則下先被隔離，不會直接冒充已批准內容。
- 第三方自訂字型已從 target 移除並改用系統字型。
- 新社群內容必須經雲端待審流程。
- Content Rights 仍需帳戶持有人確認第三方資料的合法使用權，不能由程式碼或自動化代為作法律聲明。
- 詳細證據及來源邊界見 [CONTENT_RIGHTS.md](CONTENT_RIGHTS.md)。

## 私隱

- 帳戶名稱、電郵、UID 及用戶投稿會與帳戶連結，用於 App 功能。
- 目前位置只在裝置上用於距離計算，不上傳或儲存。
- Crashlytics 收集不綁定帳戶身份的 crash／diagnostic data。
- Cloud Functions 會產生包括 function name 及 caller IP 的服務請求中繼資料。
- 不作跨 App／網站追蹤，不含第三方廣告，不在 1.0 收集產品行為分析。

## 已完成的本機非 build 驗證

- Swift 語法 parse：通過
- Firestore／Storage Rules emulator：9/9 通過
- Firebase Functions ESLint：通過
- Firebase Functions module load：通過
- plist、Xcode project 及共用 scheme XML：通過
- `git diff --check`：通過

## Release proof

正式 release proof 必須全部來自：

1. GitHub `main` 上的已推送 commit。
2. Xcode Cloud 成功的 Test、Archive 及 App Store validation。
3. 該 Cloud build 在 TestFlight 的真機 smoke test。
4. App Store Connect 已掛接同一 build，且所有 metadata／privacy／rating／review 欄位完整。

完整進度以 [PREFLIGHT_CHECKLIST.md](PREFLIGHT_CHECKLIST.md) 為準。
