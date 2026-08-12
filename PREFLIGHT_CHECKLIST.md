# VetMap iOS 1.0 — 送審前必要完成

> App Store Connect ID: `6777361219`
> Bundle ID: `com.vetmap.app`
> Release candidate: source fix commit `bb9f484`；Xcode Cloud Run 43 的 ASC Build `1.0 (43)`（`3afbaa31-05a8-4c86-b89f-2e8549fcd73f`）已掛接 iOS 1.0
> 最後核對：2026-08-12

本表只記錄可驗證的目前狀態。帳戶持有人已授權 send-for-review workflow，但只可在所有列出的 release gates 完成、App Privacy 已 Publish，並取得完整 Content Rights 法律 attest 後才可正式按下 App Store Connect「提交以供審核」。

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
- [x] 香港寵物服務及官方保險入口可收藏到帳戶；Profile 提供同步、重試、跨帳戶隔離、舊值移除及失效目錄提示，Swift／Rules 共用精確 127-ID allowlist
- [x] 診所、評價及報價表單在 session 過期時保留 immutable 草稿；只會在明確 `authenticationRequired` 後登入續交，一般網絡／backend 錯誤不會自動重試
- [x] Helpful、訊息、診所／評價／報價舉報及封鎖全部先驗證登入；登入成功只恢復一次原意圖，舉報／封鎖仍須再次確認，取消登入不寫資料
- [x] 電郵登入提供忘記密碼：正規化地址、防止帳戶枚舉、跟隨 App 語言、還原 Firebase 全域語言設定、VoiceOver 結果聚焦及重複請求保護
- [x] Profile 在登入及未登入狀態均提供支援／聯絡入口，與 ASC Support URL 及 `vetmap.app@gmail.com` 一致；無效的假「高對比模式」設定已移除
- [x] App 內提供帳戶刪除、重新驗證、Apple token 撤銷及伺服器資料清除
- [x] `purgeUserData` 行為 coverage 已由 GitHub Java 21 成功 test gate 驗證：五分鐘 recent-auth 邊界、投稿／評價／報價／聊天室／舉報／moderation marker／封鎖引用／Helpful vote／4 個 Storage prefix、他人資料保留及重試冪等
- [x] Firestore／Storage rules coverage 已由 GitHub Java 21 成功 test gate 驗證（包括聊天室 participant query、批准評價來源、反向重複 ID、已下架來源、message report atomic marker、admin least-privilege 及舊 `savedProducts` migration regression）；本機最新 emulator attempt 為 inconclusive，並非本項成功依據
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
- [x] 已部署相容聊天室舉報 least-privilege `FirestoreRules.rules` 及 `purgeUserData`；rules compile／release 成功，`purgeUserData` 已在 `asia-east1` 更新為 Node.js 22 v2 callable。GitHub Java 21 是成功的測試 gate；本機 emulator 曾在第一個 TAP case 超過五分鐘後停止，結果 inconclusive，不視為 pass 或 fail。
- [x] 部署 `StorageRules.rules`
- [x] 部署 `firestore.indexes.json`，包括刪戶所需 collection-group indexes
- [x] production `purgeUserData`（包括相容 `chatModeration` recursive cleanup source）已部署；Node.js 22、`asia-east1`、v2 callable。
- [x] 部署 `public/` 的私隱政策、使用條款及支援頁，三個 production URL 均回應 HTTP 200
- [x] 未登入直接 POST `purgeUserData` 實際回應 HTTP `401`、status `UNAUTHENTICATED`，message 為 `You must sign in again before deleting your account.`
- [x] production 公開 approved 查詢為 clinics 180、reviews 1、quotes 1；clinics 包括 179 間授權香港診所及 1 間 VetMap 示範診所
- [x] 2026-08-12 post-deploy public-only audit：180 間診所（179 authorised + 1 demo）、161 mappable、18 list-only、availability `11/10/1`、1 review、1 quote、124 HK services、3 official insurance links；legacy anonymous reads denied。此 public-only audit 不可證明 hidden inventory。
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
- [x] 帳戶同步「收藏服務／保險」source candidate 已推送至 GitHub `main`：commit `25258d7`；Actions run `31408603722` 全綠，包含精確 127-ID drift gate、legacy migration、Functions 及 Firestore／Storage rules 18/18
- [x] 帳戶復原及社群登入續接 source candidate 已推送至 GitHub `main`：commit `a1eca9f`；Actions run `31411453992` 全綠，包含診所／評價／報價草稿續接、UGC action gate、忘記密碼、支援入口、Functions 及 Firestore／Storage rules 18/18
- [x] Feature commit `98809ad` 的 GitHub run `31413231064` 成功；其 Xcode Cloud Run 42 `b5c3bdf5-bd8d-4063-a29e-89e5c4a05a06` 由同一 source 觸發，但 Archive 因 `ProfileTab.swift:366` 的 `Section` overload 失敗，沒有 build resource，不能重用或作 release 證據
- [x] Fix commit `bb9f484`（`fix: disambiguate favourites section header`）的 GitHub run `31576278579` 成功；local Node `91/91`、Swift parse 均通過，fresh Sol verdict 為 ship
- [x] Xcode Cloud Run 43 `3fabe55c-63fe-4eca-991d-b342da404b73` 由 exact `bb9f484` 成功產生；唯一 action `d055b536-aa03-46fb-9dbe-bc255573db55` 成功。exactly-one trigger 後 workflow 已停用
- [x] ASC Build 43 `3afbaa31-05a8-4c86-b89f-2e8549fcd73f` 為 `VALID`、`APP_STORE_ELIGIBLE`、未過期，並已掛接 iOS 1.0 `READY_FOR_REVIEW`
- [x] 2026-08-12 review submission draft live read-back：`6e901867-779d-454f-8258-bf434993744c` 為 `READY_FOR_REVIEW`、`submittedDate: null`，含一個 item（`appStoreVersion` `583c6199-bf1e-42d9-8bd4-69c2e51f4d2c`）；這是獨立於 version／build 的 draft evidence，尚未正式提交
- [x] Cloud development artifact SHA-256 `46628b8ea4febc9b35d1f4fcdfad7ada5a0fd8c2b4d5ab6fd9c284beb469fc37` 已驗證 bundle `com.vetmap.app`、`1.0 (43)`、Team `637V678N3Q`，並已安裝／read-back 至實體 iPhone「是條小狗」
- [ ] 在實體 iPhone「是條小狗」完成登入、投稿、批核、公開、聊天室收發／刪除／舉報／封鎖及帳戶刪除 smoke test；development artifact 的 launch 兩次都只因裝置 locked 被拒，未取得 launch 或 UI smoke evidence
- [ ] 在已安裝的 candidate 以 fixture 信箱驗證忘記密碼電郵送達、App 語言、連結可用及不存在帳戶的 generic success；source／CI 不可代替 Firebase 郵件實測
- [x] 將 build 11 掛接至 App Store Connect iOS 1.0 作暫時 release candidate
- [x] Build 43 已取代早前暫掛 build，ASC read-back 為 iOS 1.0 `READY_FOR_REVIEW`

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
- [ ] 在 ASC App Privacy 加入並 Publish Product Interaction：linked to identity、not used for tracking、App Functionality；目前仍 unpublished，因兩個可用 browser session 均要求 ASC login，未作 UI mutation
- [x] 完成年齡分級問卷並如實申報 messaging/chat、UGC 及 social media；2026-08-03 live UI 顯示現行分級 `16+`（173 個國家或地區；南韓 `15+`），pre-OS 26／舊 global rating 為 `17+`，與 API `SEVENTEEN_PLUS` 對應
- [x] 完成 regulated medical device 聲明：No
- [x] 以 Xcode Cloud 香港修正版取代全部舊 screenshots；ASC API read-back：`en-GB`／`zh-Hant` 各 5 張 iPhone、6 張 iPad，22 張均為 `COMPLETE`
- [x] 把 App Store 描述及 keywords 改為 [AppStoreMetadata.md](AppStoreMetadata.md) 的香港＋community 版本，並從 live ASC 讀回確認
- [x] `What's New` 不適用於首個 App 版本；Apple API 對 1.0 回覆 `STATE_ERROR` 且官方文件說明首版不提供此欄，故舊 API 殘值不作 storefront／送審缺漏
- [ ] 完成 Content Rights。現時仍為 `DOES_NOT_USE_THIRD_PARTY_CONTENT`；正式提交前須由帳戶持有人作完整 legal attestation，涵蓋診所資料庫、香港服務目錄、官方保險連結及按使用條款提交的用戶內容，然後才可改為使用／存取第三方內容
- [x] 將 build 7 加入 iOS 1.0 review draft
- [x] iOS 1.0 已掛 Build 43：`3afbaa31-05a8-4c86-b89f-2e8549fcd73f`
- [x] 2026-08-03 03:49 CST live UI：iOS 1.0 為「準備審查」、Build 12 仍掛接；Review Submission draft 於 2026-07-14 06:07 建立，含 1 項，仍只顯示「提交項目草稿 (1)」，未正式送出
- [x] 2026-08-12 ASC read-back：iOS 1.0 為 `READY_FOR_REVIEW`，Build 43 為 `VALID`、`APP_STORE_ELIGIBLE`、未過期並已掛接；此狀態不代表 `WAITING_FOR_REVIEW`、TestFlight distribution 或 public release
- [ ] 最後逐頁核對沒有紅色缺漏或矛盾
- [ ] submit 已獲帳戶持有人授權，但只可在 App Privacy Product Interaction Publish、完整 Content Rights legal attestation，及本表所有其餘 release gates 完成後才可按「提交以供審核」；Release type 保持 `MANUAL`，不得 public release

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

2026-08-12 device read-back：Cloud development artifact `VetMap 1.0 (43)` 已安裝至實體 iPhone「是條小狗」。嘗試 launch 兩次均只因裝置 locked 被拒；這不構成 launch、UI 或完整 smoke evidence，因此以下互動 smoke 仍未完成。

1. 用 App Review 帳戶登入。
2. 在繁中及英文 App 語言各要求一次忘記密碼，驗證電郵送達、語言及重設連結；以不存在地址確認畫面不洩露帳戶狀態。
3. 分別提交一項新診所、一項評價及一項報價，並在各表單模擬 session 過期，確認登入後草稿只續交一次。
4. 用管理員帳戶批准三項投稿。
5. 用第二個普通帳戶確認批准內容可見。
6. 由示範評價開啟聊天室，驗證雙向收發、作者軟刪除、另一方舉報及封鎖後不可再傳送。
7. 對評價及報價執行舉報與封鎖，確認登入續接只返回確認步驟，完成後內容才從該用戶畫面消失。
8. 管理員處理舉報及下架，確認所有普通帳戶不再看見。
9. 測試每個帳戶對同一評價只能標記一次「有用」。
10. 測試電郵帳戶刪除；另以 Apple 登入帳戶測試重新驗證、token 撤銷及刪除。
