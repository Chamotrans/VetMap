# VetMap iOS 1.0 — 送審前必要完成

> App Store Connect ID: `6777361219`
> Bundle ID: `com.vetmap.app`
> Release candidate: GitHub `main` source candidate `824c78a`（待下一次 Cloud build）；ASC 暫掛 build `1.0 (12)`
> 最後核對：2026-08-10

本表只記錄可驗證的目前狀態。正式按下 App Store Connect「提交以供審核」不在自動執行範圍內。

## 已完成：程式及安全基線

- [x] 保留電郵註冊、Apple 登入、診所／評價／報價投稿及社群互動
- [x] Firebase Auth 使用單一共享登入狀態，投稿及舉報綁定真實 UID
- [x] 所有診所、評價及報價投稿先寫入 `submissions` 待審佇列
- [x] 公開內容只容許管理員由待審佇列批准建立
- [x] 評價、報價及診所均可舉報；評價及報價作者可被封鎖
- [x] 一對一聊天室只限參與者讀取；只有訊息被舉報後，管理員才可讀取／處理該一則訊息；支援刪除自己訊息、舉報訊息及封鎖對方
- [x] 聊天室 listener 以帳戶／對話 generation 隔離；登出、刪戶或切換帳戶會清除舊資料；最近 200 則訊息以時間順序顯示，載入失敗可重試
- [x] 新聊天室只可由已批准、未下架的評價發起；`sourceReviewId`、評價作者、兩名參與者及 canonical conversation ID 均由 Firestore rules 驗證
- [x] Firestore rules 同時檢查雙方封鎖清單；任一方封鎖後不可再寫入新訊息
- [x] 聊天室首個訊息及 conversation preview 以 atomic batch 建立／更新，sender、participant 及 preview 內容受 rules 一致性檢查
- [x] 「有用」標記改為每個 Firebase UID 對每項評價一次
- [x] 診所詳情可收藏／取消收藏；「我的收藏」提供登入提示、Cloud 同步、跨帳戶隔離、離線 cache、刪除及失效診所提示，並以 Firestore rules 限制每戶最多 200 個診所 ID
- [x] App 內提供帳戶刪除、重新驗證、Apple token 撤銷及伺服器資料清除
- [x] `purgeUserData` Firestore emulator 行為測試 2/2：五分鐘 recent-auth 邊界、投稿／評價／報價／聊天室／舉報／moderation marker／封鎖引用／Helpful vote／4 個 Storage prefix、他人資料保留及重試冪等均通過
- [x] Firestore／Storage 規則 emulator 測試：17/17 通過（包括聊天室 participant query、批准評價來源、反向重複 ID、已下架來源、message report atomic marker 及 admin least-privilege regression）
- [x] Firebase Functions lint 及載入檢查通過
- [x] GitHub validation actions 已升級至原生 Node 24 runtime：`checkout@v7`、`setup-node@v7`、`setup-java@v5`；run `30764946922` 全綠且沒有 Node 20 deprecation annotation
- [x] 全部 Swift 檔案 `swiftc -parse` 通過
- [x] App、Widget、Privacy manifest、Xcode scheme 及 project 檔案語法檢查通過
- [x] 共用 `VetMap` scheme 已提交準備供 Xcode Cloud 使用
- [x] Xcode Cloud `ci_post_clone.sh` 已準備以 secret 注入 Firebase plist
- [x] Release target 已移除 Firebase Analytics；首版不收集產品行為分析資料
- [x] 啟動／onboarding 不再主動請求通知或定位；定位只可由地圖上可見按鈕觸發，拒絕／撤銷後提供 Settings recovery 並清除舊位置
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
- [x] 2026-08-03 部署聊天室來源加固 rules；Firebase compile／release 成功，匿名 conversation／message REST read 均回 403
- [ ] 部署聊天室舉報 least-privilege rules 及相容 `purgeUserData`：程式、Functions purge emulator 2/2 及 rules emulator 17/17 已通過；為免令現有 Build 39 的舊 report writer 失效，必須先由 Xcode Cloud 產生及安裝含 atomic moderation marker 的新 candidate，再部署並做真機舉報／管理員處理／刪戶 smoke test
- [x] 部署 `StorageRules.rules`
- [x] 部署 `firestore.indexes.json`，包括刪戶所需 collection-group indexes
- [x] production baseline `purgeUserData` 已部署；Node.js 22、`asia-east1`、ACTIVE。含 `chatModeration` recursive cleanup 及新 emulator gate 的相容 source 尚待新 candidate 安裝後部署
- [x] 部署 `public/` 的私隱政策、使用條款及支援頁，三個 production URL 均回應 HTTP 200
- [x] 未登入直接呼叫 `purgeUserData` 會回應 `UNAUTHENTICATED`
- [x] production 公開 approved 查詢為 clinics 180、reviews 1、quotes 1；clinics 包括 179 間授權香港診所及 1 間 VetMap 示範診所
- [x] 驗證 Firebase Authentication 的 Email/Password provider 已啟用
- [x] 驗證 Firebase Authentication 的 Apple provider OAuth code flow 已正確設定
- [x] 建立獨立管理員帳戶，並在 `users/{uid}` 設定 `role: admin`
- [x] 建立不需 2FA 的普通、刪除測試及 fixture App Review 電郵／密碼帳戶
- [x] 以專用 fixture UID 建立 rights-cleared 示範診所、評價及報價，令 Helpful／Report／Block 路徑可達
- [x] 以專用 fixture UID 建立 rights-cleared 示範聊天室訊息，並連結已批准示範評價；雙方帳戶 read-back 驗證 source、participant、sender 及 incoming message
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
- [x] Xcode Cloud run 39 的 Archive／exports 成功，但整體 run 因 `ITMS-90382` delivery 失敗而為 `FAILED`；Cloud development artifact `VetMap 1.0 (39)` 已安裝到實體 iPhone「是條小狗」
- [x] Xcode Cloud Run 41 screenshot test plan 在 iPhone 17 Pro Max 及 iPad Pro 13-inch 完成 `SUCCEEDED`；12 張 release evidence 附件已匯出及逐張驗收
- [x] Xcode Cloud workflow 已還原為 `Default` Archive／`APP_STORE_ELIGIBLE`，並在 upload limit 重置前保持 disabled
- [x] 聊天室來源加固已推送至 GitHub `main`：code commit `70918e8`；Actions run `30762479857` 全綠，Firestore／Storage rules 16/16
- [x] 2026-08-03 ASC API live read-back：workflow `DBB6C988-A379-476E-9E99-3235B11BAD2E` 仍為 disabled，最新 run 仍是 41，沒有因後續 push 自動產生新 Cloud upload
- [x] 2026-08-03 03:49 CST ASC live UI 再確認 `Default` workflow 仍停用、最後修改時間為同日 02:42、最新 run 仍是 41、沒有 Run 42；Archive 使用 `VetMap` scheme，distribution preparation 選擇 App Store Connect
- [x] 聊天室 least-privilege candidate 已推送至 GitHub `main`：commit `00fa4a2`；Actions run `30763791472` 全綠，Firestore／Storage rules 17/17
- [x] 帳戶刪除 behavior gate 已推送至 GitHub `main`：commit `703aa12`；Actions run `30764734390` 全綠，Functions purge 2/2 及 Firestore／Storage rules 17/17
- [x] Apple 24 小時 upload window 已重置；Run 39 delivery 被 `ITMS-90382 Upload limit reached` 拒絕且未進入 ASC processing，以 2026-08-03 01:55 CST 為保守基準的等待期已於 2026-08-04 03:00 CST 後完成
- [x] 帳戶同步「收藏診所」source candidate 已推送至 GitHub `main`：feature commit `adeb7d8`、CI fix `5d8c9b0`；Actions run `31402624859` 全綠，包含收藏模型 harness、App Review metadata drift、Functions 及 Firestore／Storage rules 17/17
- [x] 聊天 session／定位權限 source hardening 已推送至 GitHub `main`：commit `824c78a`；Actions run `31404496717` 全綠，包含新 privacy/chat source gate、Functions、catalog validators 及 Firestore／Storage emulator rules
- [ ] 帳戶持有人明確確認 Content Rights 並指示繼續後，啟用／觸發新 Xcode Cloud candidate，守到 ASC processing 終態；2026-08-09 live read-back 顯示 workflow 仍 disabled、最新 run 仍為 41，沒有 Run 42
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
- [x] 填寫 App Review Notes，說明待審投稿、Helpful、公開內容舉報／封鎖、私人聊天室收發／訊息舉報／封鎖／刪除訊息、帳戶刪除及測試路徑；manual setup 與 ASC updater 由 CI drift gate 對帳
- [x] 完成並 Publish App Privacy 問卷；2026-07-24 live UI 再確認為 Published
- [x] 2026-08-03 03:49 CST ASC live UI 再確認 App Privacy 已 Published；7 類資料包括「其他用戶內容」，其設定為 linked to identity、用於 App Functionality，已涵蓋私人聊天室
- [ ] 在 ASC App Privacy 加入並 Publish Product Interaction：linked to identity、not used for tracking、App Functionality；現有 7 類 live snapshot 未涵蓋帳戶收藏
- [x] 完成年齡分級問卷並如實申報 messaging/chat、UGC 及 social media；2026-08-03 live UI 顯示現行分級 `16+`（173 個國家或地區；南韓 `15+`），pre-OS 26／舊 global rating 為 `17+`，與 API `SEVENTEEN_PLUS` 對應
- [x] 完成 regulated medical device 聲明：No
- [x] 以 Xcode Cloud 香港修正版取代全部舊 screenshots；ASC API read-back：`en-GB`／`zh-Hant` 各 5 張 iPhone、6 張 iPad，22 張均為 `COMPLETE`
- [x] 把 App Store 描述及 keywords 改為 [AppStoreMetadata.md](AppStoreMetadata.md) 的香港＋community 版本，並從 live ASC 讀回確認
- [x] `What's New` 不適用於首個 App 版本；Apple API 對 1.0 回覆 `STATE_ERROR` 且官方文件說明首版不提供此欄，故舊 API 殘值不作 storefront／送審缺漏
- [ ] 完成 Content Rights。2026-08-03 03:49 CST live UI 仍顯示「否，此 App 不包含、顯示或存取第三方內容」；App 會顯示經批准的用戶內容，提交者確認完整權利範圍後必須改為使用／存取第三方內容
- [x] 將 build 7 加入 iOS 1.0 review draft
- [x] iOS 1.0 已掛 Build 12：`e1cd2911-c0c2-4cd7-94c4-985c2295794a`
- [x] 2026-08-03 03:49 CST live UI：iOS 1.0 為「準備審查」、Build 12 仍掛接；Review Submission draft 於 2026-07-14 06:07 建立，含 1 項，仍只顯示「提交項目草稿 (1)」，未正式送出
- [x] 2026-08-09 ASC API read-only 核對：iOS 1.0 及 review submission 均為 `READY_FOR_REVIEW`、`submittedDate` 為空，仍掛 Build 12 `VALID`；最新 processed build 為 35，未見 Build 39 或新 candidate
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
| Product Interaction | 是 | 否 | App 功能 |
| Crash Data | 否 | 否 | App 功能 |
| Other Diagnostic Data | 否 | 否 | App 功能／Analytics（SDK 運作與穩定性） |
| Other Data Types（雲端功能請求中繼資料，包括 IP） | 否 | 否 | App 功能 |

不要為首版勾選精確位置、相片、購買紀錄或廣告資料。帳戶收藏屬 Product Interaction，必須如實披露。

## 真機驗收流程

2026-08-03 live device baseline：`是條小狗` 可連線，安裝 `VetMap 1.0 (39)`；App 成功啟動並從 production 顯示 180 間診所、162 個地圖標記、18 間待確認位置及訊息 tab。iPhone Mirroring 連接逾時，因此以下互動 smoke 尚未完成。

1. 用 App Review 帳戶登入。
2. 分別提交一項新診所、一項評價及一項報價，確認畫面顯示待審而不是假成功。
3. 用管理員帳戶批准三項投稿。
4. 用第二個普通帳戶確認批准內容可見。
5. 由示範評價開啟聊天室，驗證雙向收發、作者軟刪除、另一方舉報及封鎖後不可再傳送。
6. 對評價及報價執行舉報與封鎖，確認內容即時從該用戶畫面消失。
7. 管理員處理舉報及下架，確認所有普通帳戶不再看見。
8. 測試每個帳戶對同一評價只能標記一次「有用」。
9. 測試電郵帳戶刪除；另以 Apple 登入帳戶測試重新驗證、token 撤銷及刪除。
