# VetMap App Store Connect 送審設定

> App ID: `6777361219`
> Bundle ID: `com.vetmap.app`
> Version: `1.0`
> Target build: Xcode Cloud `8`

此文件是今次免費首版的實際填表基線；Premium／IAP 不屬於 1.0。最後必須停在正式「提交以供審核」按鈕前。

## Version Information

使用 [AppStoreMetadata.md](AppStoreMetadata.md) 的描述、subtitle 及 keywords。

必填：

- Support URL：`https://vetmap-app.web.app/support`
- Privacy Policy URL：`https://vetmap-app.web.app`
- Copyright：`2026 Chamotrans`
- Primary category：Medical
- Secondary category：Lifestyle
- Price：Free

描述須保留醫療免責聲明：

> 診所、評價及費用資料只供一般參考，不構成獸醫診斷或治療建議；緊急情況請直接聯絡合資格獸醫診所。

## Screenshots

App Store Connect 現時的舊截圖包含已移除的商戶、保險及未授權診所內容，不可重用。Build 8 必須重新截取：

- 只展示 Build 8 真實 UI 及功能；
- 不顯示已移除的相片上載或已隱藏的 Premium；
- 不聲稱未經證明的資料數量、驗證狀態或醫療結果；
- 至少一張清楚展示社群投稿／審核，另一張展示舉報／封鎖或帳戶控制。

舊 `04-Products` 自動截圖路徑會明確停止執行，不得再用該檔名或舊產品文案製作 App Store 截圖；新社群畫面使用 `04-Community`。

## App Review Information

「需要登入」保持勾選，填入一個穩定、無 2FA 的普通 Email/Password 帳戶。另準備一個可刪除的測試帳戶，避免 reviewer 刪除主要帳戶後不能繼續。

不要把 reviewer password 提交到 Git。

Review Notes：

```text
VetMap is a veterinary clinic directory and moderated community platform.
It does not diagnose, monitor, prevent, or treat medical conditions and is
not a regulated medical device.

Test account:
Email: <REVIEW_EMAIL>
Password: <REVIEW_PASSWORD>

Test paths:
1. My → Login / Sign Up.
2. Clinics → switch to “社群地圖診所” → + to submit a clinic.
3. In “社群地圖診所”, open “VetMap 示範診所（非真實商戶）”
   → Add Review or Add Quote.
4. Open its approved demo review/quote → Helpful / Report / Block Author.
5. My → Account Settings → Delete Account.

All new clinic, review, and quote submissions remain Pending until manually
reviewed by an administrator. No IAP or subscription UI is exposed in v1.0.
Location permission is optional and precise location is processed on device
only to center the map and calculate distance.

The single demo clinic, review, and quote are VetMap-owned test fixtures. Each
is prominently labelled as non-real and contains no third-party business name,
medical experience, or real price claim.

The default “台灣官方登記” directory is a 2026-01-12 snapshot of Taiwan
Ministry of Agriculture veterinary practice licence data, reused under
OGDL-Taiwan 1.0 with source and licence attribution shown in the app. The
source has no coordinates, ratings, opening hours or service claims; VetMap
does not invent them.

Disposable deletion-test account:
Email: <DELETE_TEST_EMAIL>
Password: <DELETE_TEST_PASSWORD>

Support: https://vetmap-app.web.app/support
```

Review 帳戶登入後必須已看得到由另一個 UID 發佈的 approved review／quote，讓 reviewer 實際測試 Helpful、Report 及 Block。

## App Privacy

Tracking：No。

| Data Type | Linked to User | Tracking | Purpose |
|---|---:|---:|---|
| Name | Yes | No | App Functionality |
| Email Address | Yes | No | App Functionality |
| User ID | Yes | No | App Functionality |
| Other User Content | Yes | No | App Functionality |
| Crash Data | No | No | App Functionality |
| Other Diagnostic Data | No | No | App Functionality, Analytics |
| Other Data Types | No | No | App Functionality |

不要勾選：

- Precise Location：目前位置只在裝置處理；
- Photos or Videos：1.0 沒有相片投稿；
- Purchase History：1.0 沒有公開 IAP；
- Product Interaction／Search History：Firebase Analytics 已移除；
- Advertising Data：沒有廣告；
- Data Used to Track You：沒有跨 App／網站追蹤。

問卷答案必須 Publish，不能只儲存草稿。

## Age Rating

按 App Store Connect 當日顯示的現行問卷如實作答，讓 Apple 計算結果；不要手動猜 4+／12+。

以目前功能作保守基線：

- User-Generated Content：Yes
- Social／community interaction：Yes
- Messaging or Chat：Yes（現行問卷如把公開投稿列入）
- Under-13 social controls：No（沒有 Declared Age Range API）
- Unrestricted Web Access：Yes（clinic URL 透過 in-app Safari 開啟）
- Advertising：No，前提是商戶列表沒有收費推廣
- Medical／Treatment Information：Infrequent or Mild
- Gambling、Loot Boxes、Dating、Violence、Sexual Content、Drugs：No

如 ASC 問卷字眼或選項有更新，以畫面原文及真實功能為準。

## Regulated Medical Device

選擇 `No`。VetMap 是診所目錄及社群資料工具，不診斷、監測、預防或治療疾病，也不控制醫療裝置。

這項聲明與 Primary Category 是 Medical 無衝突，但 Review Notes 及描述必須一致。

## Content Rights

不能回答「No third-party content」。Build 8 會顯示經批准的用戶內容，以及依 OGDL-Taiwan 1.0 使用的台灣農業部官方資料：

1. 回答 App contains, shows, or accesses third-party content：`Yes`。
2. 勾選「擁有必要權利」前，由帳戶持有人確認並保存 license、permission 或其他合法使用依據。
3. 用戶新投稿由 Terms of Service 的內容授權條款涵蓋。
4. repo 註解、來源連結或「資料真實」並不是授權證據。
5. 台灣官方目錄須保留農業部／動植物防疫檢疫署、資料集、2026-01-12 快照及 OGDL-Taiwan 1.0 顯名聲明。
6. 既有未能證明權利的香港 dataset、商戶、保險、seed reviews／quotes 及自訂字型已從 Build 8 移除。
7. 完整邊界及來源研究見 [CONTENT_RIGHTS.md](CONTENT_RIGHTS.md)。

此項是法律聲明，不能由自動化代替帳戶持有人確認。

## In-App Purchases

1.0 不提供 Premium 或 subscription UI：

- `FeatureFlags.premiumEnabled = false`
- 不把任何 IAP 加入本次 review draft
- Metadata、screenshots 及 Review Notes 均不得宣傳 Premium

StoreKit 程式碼及測試產品留作後續版本，不代表今次需要建立或提交 IAP。

## Build and TestFlight

本機是 macOS Beta，不用本機 archive 作送審 build。

1. 推送 release commit 至 GitHub `main`。
2. Xcode Cloud 使用共用 `VetMap` scheme。
3. 設定 `GOOGLE_SERVICE_INFO_PLIST_BASE64` secret。
4. Build 6 已成功但包含未有 rights packet 的舊 seed data，不可掛接。
5. Build 7 已成功並暫掛 iOS 1.0。
6. 推送官方目錄修正，讓 workflow 建立 Build 8 Release Archive 並分發至 App Store Connect。
7. 安裝同一 Build 8 作真機 UGC／account deletion smoke test。
8. 將 processing 完成的 Build 8 掛接至 iOS 1.0，取代 Build 7。

## 最後核對

- 所有 metadata 已保存，沒有紅色 required-field 警告
- App Privacy 已 Publish
- Age Rating 已完成
- Medical Device 已選 No
- Content Rights 已由帳戶持有人確認
- Reviewer credentials 及 Review Notes 已填
- Build 8 已掛接
- Review draft 只包含 iOS 1.0 及正確 build，沒有 IAP
- 停在「提交以供審核」前，交由帳戶持有人最後確認
