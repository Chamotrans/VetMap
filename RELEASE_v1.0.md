# VetMap iOS 1.0 — Release Candidate Notes

> 目前狀態：production 已恢復完整授權香港診所庫及部署聊天室 backend；ASC Build 12 暫掛 iOS 1.0；聊天室 Cloud Run 39 已成功 archive，但 delivery 被 `ITMS-90382 Upload limit reached` 拒絕，須等 Apple 24 小時 window 重置後再上載；香港修正版 iPhone／iPad screenshots 已同步到 ASC；尚未正式提交 App Review。
> 本文件不以舊本機 archive、舊 commit 數或未部署設定冒充 release proof。

## 首版範圍

- 已審核獸醫診所的地圖、列表、搜尋、篩選、電話、網站及導航
- 179 間已授權香港診所；161 間有可靠地圖位置、18 間安全地只作列表顯示
- 124 項香港寵物用品／美容／善終服務目錄
- 3 個香港寵物保險官方產品入口
- 電郵／密碼註冊及登入
- Sign in with Apple
- 新增診所、評價及治療報價
- 所有社群投稿先進入雲端待審佇列，批准後才公開
- 評價、報價及診所舉報
- 封鎖評價／報價作者
- 由已批准評價作者入口開始的一對一私人聊天室
- 聊天訊息收發、自己訊息軟刪除、訊息舉報及封鎖對方
- 每帳戶一次的評價「有用」標記
- App 內帳戶及相關用戶資料刪除

## 明確不在 1.0 公開範圍

- Premium 訂閱及 IAP：程式碼仍保留作後續版本，但 `FeatureFlags.premiumEnabled` 為 `false`
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
| `conversations/{id}` | 一對一對話及訊息 preview | 只限兩名參與者讀取；建立時必須連結已批准、未下架且作者為收件人的評價，並符合 canonical ID、participant／preview 一致性 |
| `conversations/{id}/messages/{id}` | 私人訊息 | 只限兩名參與者讀取；sender 綁定登入 UID；自己可軟刪除；管理員只可讀取／處理有對應舉報 marker 的該一則訊息 |
| `chatModeration/{conversationId}/reportedMessages/{messageId}` | 私人 moderation marker | 與 message report 原子建立；普通用戶不可讀，管理員只藉此取得已舉報訊息的最小權限 |

公開 collection 只有管理員可以建立或刪除。管理員批准投稿時，以 batch 同步建立公開文件及更新 submission 狀態。

## 帳戶刪除

刪除流程要求最近登入：

1. 電郵帳戶重新輸入密碼，或 Apple 帳戶重新取得 Apple credential。
2. 重新驗證 Firebase Auth。
3. 呼叫 `asia-east1` callable function `purgeUserData` 清除 Firestore 及 Storage 內的用戶資料。
4. Apple 帳戶撤銷 authorization code。
5. 刪除 Firebase Auth user，再清除本機資料。

## 資料及內容邊界

- 香港修正版不載入舊台灣／未批准評價／未批准報價資料；不要使用「ALL REAL」、「全部已驗證」等無法證明的宣傳字眼。
- production 179 間香港診所來自我方建立或已獲授權的原有 VetMap 資料庫，只保留名稱、地址、電話及可靠香港座標，並標記 `verified: false`。
- 176 筆主資料及 29 筆補充資料均有唯一 lineage；兩對同名同址重複紀錄合併後仍保留全部來源 ID 及電話。
- 161 間有可靠座標；18 間仍可搜尋及查看聯絡資料，但不顯示假 pin、距離或導航。
- 124 項香港服務目錄不顯示未有來源的價格、評分或營業時間；3 項保險只連到供應商官方頁，不複製價錢或保障聲稱。
- 舊星級、價錢、營業時間、服務、急診聲稱、tags 及圖片已清除；舊 reviews／quotes 保持隔離。
- 台灣 17 間舊診所及 `officialClinicCatalog` 不會公開；App 亦不再載入或顯示台灣目錄。
- 第三方自訂字型已從 target 移除並改用系統字型。
- 新社群內容必須經雲端待審流程。
- 私人聊天室訊息不公開亦不作預先人工審核；只有對話雙方可讀取，訊息被舉報後獲授權管理員才可為審核讀取及處理。
- `verified` 不作獨立核實聲稱；列表／地圖不顯示未有可靠同步機制的舊 aggregate 星級或評價數，詳情只以實際公開評價即時計算。
- 新診所投稿必須使用香港境內的 geocode 或手動座標；未知價錢不會歸入平價篩選。
- 帳戶持有人已確認原有診所庫由我方建立或已獲授權；完整 ASC Content Rights（包括服務目錄、官方保險連結及用戶投稿）仍需另行明確確認。
- 詳細證據及來源邊界見 [CONTENT_RIGHTS.md](CONTENT_RIGHTS.md)。

## 私隱

- 帳戶名稱、電郵、UID 及用戶投稿會與帳戶連結，用於 App 功能。
- 私人聊天室訊息與帳戶及對話參與者連結，用於訊息傳送、安全舉報、封鎖及內容審核。
- 目前位置只在裝置上用於距離計算，不上傳或儲存。
- Crashlytics 收集不綁定帳戶身份的 crash／diagnostic data。
- Cloud Functions 會產生包括 function name 及 caller IP 的服務請求中繼資料。
- 不作跨 App／網站追蹤，不含第三方廣告，不在 1.0 收集產品行為分析。

## 已完成的本機非 build 驗證

- Swift 語法 parse：通過
- Firestore／Storage Rules emulator：17/17 通過
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

目前已確認的上一個 ASC release baseline：

- GitHub `main` commit：`81ce20483a83bb4b85ae3625c357924c89eff103`
- Xcode Cloud run：`1a5339f2-fc82-46da-879e-175812548668`，Build 12，`SUCCEEDED`
- ASC build：`e1cd2911-c0c2-4cd7-94c4-985c2295794a`，`VALID`、`APP_STORE_ELIGIBLE`
- iOS 1.0 draft：已讀回掛接 Build 12，狀態 `READY_FOR_REVIEW`
- 實體 iPhone「是條小狗」：已安裝 `VetMap 1.0 (12)`；真實畫面顯示診所 180、地圖標記 162、寵物服務 124

聊天室候選驗證：

- production Firestore rules、indexes、`purgeUserData` 及示範聊天室已部署；示範對話已連結已批准評價，並以雙方帳戶 read-back 驗證 source、participant、sender 及 incoming message
- 聊天室來源加固 code commit `70918e8` 已推送至 `main`；GitHub Actions run `30762479857` 對 semantic rules 16/16、catalog、Functions 及 patch hygiene 全部通過
- production rules 於 2026-08-03 經 Firebase compile 後成功 release；匿名 conversation list 及 message read 均回 403，公開 catalog audit 仍為 clinics 180、reviews 1、quotes 1、services 124、insurances 3
- Xcode Cloud Run 39 的 Archive 及三種 exports 成功，但整體 run 因 Apple delivery 回報 `ITMS-90382 Upload limit reached` 而為 `FAILED`；Build 39 沒有進入 ASC processing
- Run 39 development artifact `VetMap 1.0 (39)` 已安裝到實體 iPhone「是條小狗」，新訊息 tab 及未登入安全提示可達
- Xcode Cloud Run 41（`fe0b7c5b-da2a-4199-8576-db3f6ff04153`）以專用 screenshot test plan 在 iPhone 17 Pro Max 及 iPad Pro 13-inch 模擬器完成 `SUCCEEDED`；12 張附件均不屬於 failure
- ASC `en-GB` 及 `zh-Hant` 已同步香港修正版 screenshots：每個 locale 各 5 張 iPhone、6 張 iPad，22 張均由 API 讀回 `COMPLETE`；舊台北、199 間及未證明 verified／rating 畫面已移除
- iPhone 地圖附件因被 Apple Intelligence 系統通知遮擋而明確排除；iPad 地圖附件未受遮擋並已上載
- 臨時 screenshot-only workflow 已還原為 `Default` Archive／`APP_STORE_ELIGIBLE` 配置並保持 disabled，避免 24 小時 upload limit 期間自動再上載
- 2026-08-03 ASC API live read-back 再確認 iOS 1.0 為 `READY_FOR_REVIEW`、仍掛 Build 12 `VALID`、ASC 最新 processed build 為 35、workflow disabled，最新 Cloud run 仍為 41
- 同日實體 iPhone「是條小狗」live read-back 為 `VetMap 1.0 (39)`；App 成功啟動並顯示 production 香港目錄 180 間／162 個地圖標記及訊息 tab。iPhone Mirroring 逾時，故未把此證據當作完整聊天室互動 smoke test
- 聊天室 least-privilege candidate 已在 source 收窄 admin 權限：report、conversation marker 及 message marker 必須 atomic；17/17 emulator 證明 admin 在舉報前不能讀 conversation／message，舉報後仍不能讀或刪同一對話內未被舉報的第二則訊息。production rules 要待相容的新 Cloud candidate 安裝後才部署，避免令 Build 39 的舊 report writer 中斷
- 上述 candidate commit `00fa4a2` 已推送至 GitHub `main`；Backend and Config Validation run `30763791472` 全綠。Xcode Cloud workflow 仍保持 disabled，沒有在 upload quota 期間建立新 run
- 下一個 Cloud candidate 必須在 upload limit 重置後取得 ASC processing 及完整真機聊天室 smoke test，才可取代上面的 Build 12 baseline

完整進度以 [PREFLIGHT_CHECKLIST.md](PREFLIGHT_CHECKLIST.md) 為準。
