# VetMap iOS 1.0 — 送審前必要完成

> App Store Connect ID: `6777361219`
> Bundle ID: `com.vetmap.app`
> Release candidate: source candidate `1.0 (13)`；ASC 暫掛 build `1.0 (12)`
> 最後核對：2026-08-03

本表只記錄可驗證的目前狀態。正式按下 App Store Connect「提交以供審核」不在自動執行範圍內。

## 已完成：程式及安全基線

- [x] 保留電郵註冊、Apple 登入、診所／評價／報價投稿及社群互動
- [x] Firebase Auth 使用單一共享登入狀態，投稿及舉報綁定真實 UID
- [x] 所有診所、評價及報價投稿先寫入 `submissions` 待審佇列
- [x] 公開內容只容許管理員由待審佇列批准建立
- [x] 評價、報價及診所均可舉報；評價及報價作者可被封鎖
- [x] 一對一聊天室只限參與者讀取；支援刪除自己訊息、舉報訊息及封鎖對方
- [x] Firestore rules 同時檢查雙方封鎖清單；任一方封鎖後不可再寫入新訊息
- [x] 聊天室首個訊息及 conversation preview 以 atomic batch 建立／更新，sender、participant 及 preview 內容受 rules 一致性檢查
- [x] 「有用」標記改為每個 Firebase UID 對每項評價一次
- [x] App 內提供帳戶刪除、重新驗證、Apple token 撤銷及伺服器資料清除
- [x] Firestore／Storage 規則 emulator 測試：15/15 通過（包括聊天室 participant query regression）
- [x] Firebase Functions lint 及載入檢查通過
- [x] 全部 Swift 檔案 `swiftc -parse` 通過
- [x] App、Widget、Privacy manifest、Xcode scheme 及 project 檔案語法檢查通過
- [x] 共用 `VetMap` scheme 已提交準備供 Xcode Cloud 使用
- [x] Xcode Cloud `ci_post_clone.sh` 已準備以 secret 注入 Firebase plist
- [x] Release target 已移除 Firebase Analytics；首版不收集產品行為分析資料
- [x] 相片投稿未完成的介面及相機／相簿權限聲明已移除
- [x] Premium／IAP 首版 feature flag 關閉，不列入 1.0 送審功能
- [x] 香港服務／保險 catalog 已恢復；只公開 approved、HK、未過期資料，舊台灣項目仍被 rules 隔離
- [x] 未有 bundled licence notice 的第三方字型已從 target 移除並改用系統字型
- [x] 新診所投稿只接受 geocode 或手動確認的香港座標，不再使用地區中心假座標
- [x] 未知價錢不會被歸入平價篩選；未有可靠 aggregate 前，列表／地圖不顯示舊星級或評價數
- [x] 診所詳情以實際公開評價即時計算數量及平均分；空電話／營業時間不顯示
- [x] `verified` 不再當作獨立核實聲稱；投稿批准只代表通過刊登審核

## Firebase production

- [x] 部署 `FirestoreRules.rules`
- [x] 部署 `StorageRules.rules`
- [x] 部署 `firestore.indexes.json`，包括刪戶所需 collection-group indexes
- [x] 部署 `functions/` 的 `purgeUserData`；Node.js 22、`asia-east1`、ACTIVE
- [x] 部署 `public/` 的私隱政策、使用條款及支援頁，三個 production URL 均回應 HTTP 200
- [x] 未登入直接呼叫 `purgeUserData` 會回應 `UNAUTHENTICATED`
- [x] production 公開 approved 查詢為 clinics 180、reviews 1、quotes 1；clinics 包括 179 間授權香港診所及 1 間 VetMap 示範診所
- [x] 驗證 Firebase Authentication 的 Email/Password provider 已啟用
- [x] 驗證 Firebase Authentication 的 Apple provider OAuth code flow 已正確設定
- [x] 建立獨立管理員帳戶，並在 `users/{uid}` 設定 `role: admin`
- [x] 建立不需 2FA 的普通、刪除測試及 fixture App Review 電郵／密碼帳戶
- [x] 以專用 fixture UID 建立 rights-cleared 示範診所、評價及報價，令 Helpful／Report／Block 路徑可達
- [x] 以專用 fixture UID 建立 rights-cleared 示範聊天室訊息，令 Send／Delete／Report／Block 路徑可達
- [x] 每次 migration 前以 0600 權限備份 production collection，再以 guarded script 寫入 179 間香港診所
- [x] 對帳 176/176 筆主資料及 29/29 筆補充資料；205 個唯一 lineage ID 全部存在
- [x] 兩對同名同址重複資料只顯示一間，但保留雙 source ID 及雙電話
- [x] 保留名稱、地址、電話及可靠香港座標；清除未核實星級、價錢、營業時間、服務、急診聲稱及 tags
- [x] 161 間有可靠座標；18 間保留完整列表／搜尋／聯絡資料，但不顯示假 pin、距離或導航
- [x] 台灣 17 間舊診所、舊 reviews／quotes 仍未 approved；沒有被誤公開
- [x] 移除 App 的台灣目錄引用，production `officialClinicCatalog` 匿名查詢已回 403
- [x] production 公開 124 項香港寵物服務（50 用品／50 美容／24 善終）及 3 個官方保險入口
- [x] 舊產品／保險文件及不帶精確 HK publication constraints 的匿名查詢均回 403
- [x] App「關於 VetMap」已加入香港政府地址搜尋服務及 DATA.GOV.HK attribution／terms 連結

注意：production 目前公開 179 間授權香港診所及 1 項 VetMap 示範診所／評價／報價。舊台灣及不一致社群資料仍隔離；註冊、投稿、審核及社群互動保持啟用。

## 待完成：Xcode Cloud / TestFlight

- [x] 已把安全／合規修正分批提交並推送至 GitHub `main`
- [x] 在 Xcode Cloud 建立 `main` workflow
- [x] Workflow 使用共用 `VetMap` scheme
- [x] 設定 secret `GOOGLE_SERVICE_INFO_PLIST_BASE64`
- [x] Xcode Cloud build `1.0 (6)` 成功並分發至 App Store Connect
- [x] 提交並推送 Build 7 權利安全修正
- [x] Xcode Cloud build `1.0 (7)` 成功且無 App Store validation error
- [x] 確認 Build 9 成功但地區方向錯誤，不可送審
- [x] Xcode Cloud build `1.0 (11)` 成功並已暫掛 iOS 1.0
- [x] 提交並推送完整香港診所庫、服務／保險目錄及 attribution 修正：`81ce204`
- [x] Xcode Cloud Build 12 成功；run `1a5339f2-fc82-46da-879e-175812548668`，ASC `VALID`／`APP_STORE_ELIGIBLE`
- [x] 聊天室初版 Cloud run `c980a28d-5fcd-4077-8c04-8e93f7f1bcf7` 找出並修正 Swift style type mismatch
- [x] 修正版 Cloud run `8a456702-9631-4f74-9c4f-165c5a28f2d5` 已成功 compile、archive 及產生三種 export；App Store preparation 因 Apple session proxy authentication 失敗，不能當作 ASC upload 成功
- [ ] Xcode Cloud build `1.0 (13)` 成功並在 ASC 完成 processing
- [ ] 在 TestFlight 真機完成登入、投稿、批核、公開、聊天室收發／刪除／舉報／封鎖及帳戶刪除 smoke test
- [x] 將 build 11 掛接至 App Store Connect iOS 1.0 作暫時 release candidate
- [x] 以 Build 12 取代 iOS 1.0 暫掛的 Build 11，API read-back 為 `READY_FOR_REVIEW`

本機舊 archive 及 Build 5 不能作為今次 release proof；本機是 macOS Beta，正式 build 只以 Xcode Cloud 結果為準。

## 待完成：App Store Connect

- [x] App record、iOS 1.0 版本、描述、keywords 及現有 screenshots 已建立
- [x] App 定價為免費，175 個地區可用
- [x] Support URL：`https://vetmap-app.web.app/support`
- [x] Privacy Policy URL：`https://vetmap-app.web.app`
- [x] Copyright：`2026 Chamotrans`
- [x] 「需要登入」保留勾選，填入 App Review 電郵及密碼
- [x] 填寫 App Review Notes，說明待審投稿、舉報、封鎖、帳戶刪除及測試路徑
- [x] 完成並 Publish App Privacy 問卷；2026-07-24 live UI 再確認為 Published
- [ ] 在 ASC live UI 將新增私人聊天室涵蓋於「其他用戶內容」，並重新核對 Published 狀態
- [x] 完成年齡分級問卷；結果 16+
- [x] 完成 regulated medical device 聲明：No
- [ ] 以香港修正版真實畫面取代所有舊 screenshots
- [x] 把 App Store 描述及 keywords 改為 [AppStoreMetadata.md](AppStoreMetadata.md) 的香港＋community 版本，並從 live ASC 讀回確認
- [ ] 完成 Content Rights。App 會顯示經批准的用戶內容，必須如實選擇 Yes；提交者須確認擁有或獲授權使用相關內容
- [x] 將 build 7 加入 iOS 1.0 review draft
- [x] iOS 1.0 已掛 Build 12：`e1cd2911-c0c2-4cd7-94c4-985c2295794a`
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
5. 由示範評價開啟聊天室，驗證雙向收發、作者軟刪除、另一方舉報及封鎖後不可再傳送。
6. 對評價及報價執行舉報與封鎖，確認內容即時從該用戶畫面消失。
7. 管理員處理舉報及下架，確認所有普通帳戶不再看見。
8. 測試每個帳戶對同一評價只能標記一次「有用」。
9. 測試電郵帳戶刪除；另以 Apple 登入帳戶測試重新驗證、token 撤銷及刪除。
