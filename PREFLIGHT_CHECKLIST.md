# VetMap iOS 1.0 — 送審前必要完成

> App Store Connect ID: `6777361219`
> Bundle ID: `com.vetmap.app`
> Release candidate: `1.0 (7)`
> 最後核對：2026-07-23

本表只記錄可驗證的目前狀態。正式按下 App Store Connect「提交以供審核」不在自動執行範圍內。

## 已完成：程式及安全基線

- [x] 保留電郵註冊、Apple 登入、診所／評價／報價投稿及社群互動
- [x] Firebase Auth 使用單一共享登入狀態，投稿及舉報綁定真實 UID
- [x] 所有診所、評價及報價投稿先寫入 `submissions` 待審佇列
- [x] 公開內容只容許管理員由待審佇列批准建立
- [x] 評價、報價及診所均可舉報；評價及報價作者可被封鎖
- [x] 「有用」標記改為每個 Firebase UID 對每項評價一次
- [x] App 內提供帳戶刪除、重新驗證、Apple token 撤銷及伺服器資料清除
- [x] Firestore／Storage 規則 emulator 測試：9/9 通過
- [x] Firebase Functions lint 及載入檢查通過
- [x] 全部 Swift 檔案 `swiftc -parse` 通過
- [x] App、Widget、Privacy manifest、Xcode scheme 及 project 檔案語法檢查通過
- [x] 共用 `VetMap` scheme 已提交準備供 Xcode Cloud 使用
- [x] Xcode Cloud `ci_post_clone.sh` 已準備以 secret 注入 Firebase plist
- [x] Release target 已移除 Firebase Analytics；首版不收集產品行為分析資料
- [x] 相片投稿未完成的介面及相機／相簿權限聲明已移除
- [x] Premium／IAP 首版 feature flag 關閉，不列入 1.0 送審功能
- [x] 商戶／產品／保險 catalog 關閉；未有 rights packet 的 seed data 不進 Release build
- [x] 未有 bundled licence notice 的第三方字型已從 target 移除並改用系統字型

## Firebase production

- [x] 部署 `FirestoreRules.rules`
- [x] 部署 `StorageRules.rules`
- [x] 部署 `firestore.indexes.json`，包括刪戶所需 collection-group indexes
- [x] 部署 `functions/` 的 `purgeUserData`；Node.js 22、`asia-east1`、ACTIVE
- [x] 部署 `public/` 的私隱政策、使用條款及支援頁，三個 production URL 均回應 HTTP 200
- [x] 未登入直接呼叫 `purgeUserData` 會回應 `UNAUTHENTICATED`
- [x] production 公開 approved 查詢為 clinics 1、reviews 1、quotes 1；三項均為 VetMap 自有、清楚標示非真實的 App Review 示範內容
- [x] 驗證 Firebase Authentication 的 Email/Password provider 已啟用
- [x] 驗證 Firebase Authentication 的 Apple provider OAuth code flow 已正確設定
- [x] 建立獨立管理員帳戶，並在 `users/{uid}` 設定 `role: admin`
- [x] 建立不需 2FA 的普通、刪除測試及 fixture App Review 電郵／密碼帳戶
- [x] 以專用 fixture UID 建立 rights-cleared 示範診所、評價及報價，令 Helpful／Report／Block 路徑可達

注意：production 公開 approved 查詢目前各有 1 項 VetMap 示範內容，名稱及內文均明確表示並非真實商戶、評價或醫療報價。舊資料不會被擅自標成已審核；Build 7 不再保留未授權內置目錄，但完整投稿及審核功能保留。

## 待完成：Xcode Cloud / TestFlight

- [x] 已把安全／合規修正分批提交並推送至 GitHub `main`
- [x] 在 Xcode Cloud 建立 `main` workflow
- [x] Workflow 使用共用 `VetMap` scheme
- [x] 設定 secret `GOOGLE_SERVICE_INFO_PLIST_BASE64`
- [x] Xcode Cloud build `1.0 (6)` 成功並分發至 App Store Connect
- [ ] 提交並推送 Build 7 權利安全修正
- [ ] Xcode Cloud build `1.0 (7)` 成功且無 App Store validation error
- [ ] 在 TestFlight 真機完成登入、投稿、批核、公開、舉報、封鎖及帳戶刪除 smoke test
- [ ] 將 build 7 掛接至 App Store Connect iOS 1.0

本機舊 archive 及 Build 5 不能作為今次 release proof；本機是 macOS Beta，正式 build 只以 Xcode Cloud 結果為準。

## 待完成：App Store Connect

- [x] App record、iOS 1.0 版本、描述、keywords 及現有 screenshots 已建立
- [x] App 定價為免費，175 個地區可用
- [x] Support URL：`https://vetmap-app.web.app/support`
- [x] Privacy Policy URL：`https://vetmap-app.web.app`
- [x] Copyright：`2026 Chamotrans`
- [x] 「需要登入」保留勾選，填入 App Review 電郵及密碼
- [x] 填寫 App Review Notes，說明待審投稿、舉報、封鎖、帳戶刪除及測試路徑
- [x] 完成並 Publish App Privacy 問卷
- [x] 完成年齡分級問卷；結果 16+
- [x] 完成 regulated medical device 聲明：No
- [ ] 以 Build 7 真實畫面取代所有舊 screenshots
- [ ] 把 App Store 描述／subtitle 改為 [AppStoreMetadata.md](AppStoreMetadata.md) 的 community-first 版本
- [ ] 完成 Content Rights。App 會顯示經批准的用戶內容，必須如實選擇 Yes；提交者須確認擁有或獲授權使用相關內容
- [ ] 將 build 7 加入 iOS 1.0 review draft
- [ ] 最後逐頁核對沒有紅色缺漏或矛盾
- [ ] 停在「提交以供審核」按鈕前，交由帳戶持有人作最後確認

## App Privacy 答案基線

目前位置只在裝置上用於距離計算，不會上傳或儲存，因此不列作「收集」。

| 資料類型 | 綁定身份 | 追蹤 | 用途 |
|---|---:|---:|---|
| 名稱 | 是 | 否 | App 功能 |
| 電郵地址 | 是 | 否 | App 功能 |
| User ID | 是 | 否 | App 功能 |
| 其他用戶內容 | 是 | 否 | App 功能 |
| Crash Data | 否 | 否 | App 功能 |
| Other Diagnostic Data | 否 | 否 | App 功能／Analytics（SDK 運作與穩定性） |
| Other Data Types（雲端功能請求中繼資料，包括 IP） | 否 | 否 | App 功能 |

不要為首版勾選精確位置、相片、購買紀錄、廣告資料或產品互動。

## 真機驗收流程

1. 用 App Review 帳戶登入。
2. 分別提交一項新診所、一項評價及一項報價，確認畫面顯示待審而不是假成功。
3. 用管理員帳戶批准三項投稿。
4. 用第二個普通帳戶確認批准內容可見。
5. 對評價及報價執行舉報與封鎖，確認內容即時從該用戶畫面消失。
6. 管理員處理舉報及下架，確認所有普通帳戶不再看見。
7. 測試每個帳戶對同一評價只能標記一次「有用」。
8. 測試電郵帳戶刪除；另以 Apple 登入帳戶測試重新驗證、token 撤銷及刪除。
