# App Store Connect 上架準備指南

## 一、建立 App Store Connect 應用程式記錄

### 1.1 登入 App Store Connect

前往 [App Store Connect](https://appstoreconnect.apple.com/)，使用 Apple Developer 帳號登入。

### 1.2 新增 App

1. 點擊 **「App」** → 左上角 **「+」按鈕** → **「新增 App」**
2. 填寫以下資訊：

| 欄位 | 值 |
|---|---|
| **平台** | iOS |
| **名稱** | VetMap - 寵物醫院地圖 |
| **主要語言** | 繁體中文（zh-Hant-HK） |
| **套裝 ID（Bundle ID）** | `com.vetmap.app` |
| **SKU** | `com.vetmap.app` |
| **使用者存取權** | 完整存取 |

3. 點擊 **「建立」**

---

## 二、App 資訊設定

### 2.1 類別設定

| 欄位 | 值 |
|---|---|
| **主要類別** | Medical（醫療） |
| **次要類別** | Lifestyle（生活風格） |

### 2.2 年齡分級

在 **「App 資訊」** → **「年齡分級」** 點擊編輯，填寫問卷。

建議設定：**4+**（不含使用者生成內容的過濾機制則設定為 **12+**，因本 App 具備評論與社群功能，建議設定為 **12+**）

常見問卷回答：

| 問題 | 回答 |
|---|---|
| 不受限制的網路存取 | 無 |
| 使用者生成內容／社群功能 | **是** |
| 內購 | **是**（Premium 訂閱） |
| 位置資訊 | **是**（地圖功能） |

### 2.3 定價

在 **「App 資訊」** → **「定價與供應狀況」** 設定：

| 設定 | 值 |
|---|---|
| **價格排程** | 免費（Free） |
| **供應地區** | 所有地區 / 或指定：台灣、香港、澳門 |

---

## 三、App 內購買項目（IAP）設定

### 3.1 建立訂閱群組

1. 在 App Store Connect 左側選單點擊 **「訂閱項目」**（若左側無此選項，先點擊 App 進入 → **「App 內購買」** 分頁）
2. 點擊 **「建立」** → 選擇 **「自動續訂型訂閱」**

### 3.2 建立月費方案

| 欄位 | 值 |
|---|---|
| **類型** | 自動續訂型訂閱 |
| **參考名稱** | VetMap Premium 月費 |
| **產品 ID** | `com.vetmap.premium.monthly` |
| **訂閱群組** | 新建「VetMap Premium」群組，群組參考名稱：`premium` |

價格設定：

| 設定 | 值 |
|---|---|
| **訂閱持續時間** | 1 個月 |
| **價格** | TWD 80（新台幣），HKD 20（港幣） |
| **試用期** | 無（或可選：1 週免費試用） |

### 3.3 建立年費方案

| 欄位 | 值 |
|---|---|
| **類型** | 自動續訂型訂閱 |
| **參考名稱** | VetMap Premium 年費 |
| **產品 ID** | `com.vetmap.premium.yearly` |
| **訂閱群組** | `premium` |

價格設定：

| 設定 | 值 |
|---|---|
| **訂閱持續時間** | 1 年 |
| **價格** | TWD 1,000（新台幣），HKD 250（港幣） |
| **試用期** | 無（或可選：1 個月免費試用） |

### 3.4 對應 Products.storekit

確認 `VetMap/Resources/Products.storekit` 檔案中已包含這兩個產品 ID，用於本地 StoreKit 測試。

目前的 storekit 檔案僅為空殼，需在 Xcode 中開啟此檔案並手動加入兩個產品：

1. 在 Xcode 專案導覽器中點擊 `Products.storekit`
2. 點擊左下角 **「+」** → 新增 **「Auto-Renewable Subscription」**
3. 參考名稱填入 `VetMap Premium Monthly`，產品 ID 為 `com.vetmap.premium.monthly`
4. 重複步驟，新增 `VetMap Premium Yearly`，產品 ID 為 `com.vetmap.premium.yearly`

---

## 四、螢幕截圖規格

### 4.1 必須提交的螢幕尺寸

| 尺寸 | 對應機型 | 解析度（直向） | 最少張數 |
|---|---|---|---|
| **6.9 吋** | iPhone 16 Pro Max, iPhone 15 Pro Max | 1320 x 2868 | 3 張 |
| **6.5 吋** | iPhone 11 Pro Max, iPhone XS Max | 1242 x 2688 | 3 張 |
| **5.5 吋** | iPhone 8 Plus, iPhone 7 Plus | 1242 x 2208 | 3 張 |

> **提示**: 可以只上傳 6.9 吋截圖，並在 App Store Connect 中勾選「使用 6.9 吋截圖」來自動套用到其他尺寸。但建議三種尺寸都準備以獲得最佳呈現效果。

### 4.2 截圖內容建議

每組截圖建議包含以下畫面：

1. **地圖主畫面** — 顯示附近獸醫診所的地圖標記
2. **診所詳情頁** — 包含評價、報價、聯絡資訊
3. **社群報價／評價列表** — 展示使用者互動功能
4. **搜尋與篩選** — 展示地區／價格篩選
5. **Premium 方案頁** — 展示付費功能（若有）

### 4.3 截圖規範

- 無狀態列（或隱藏狀態列中的時間／電信商資訊）
- 畫面必須為直向（Portrait）
- 不得包含模擬機邊框
- 文字必須清晰可讀
- 背景避免過於複雜

---

## 五、隱私權標籤

Apple 要求所有 App 提交時填寫隱私權營養標籤。

### 5.1 本 App 使用的資料類型

| 資料類型 | 用途 | 是否追蹤 |
|---|---|---|
| **聯絡資訊（電子郵件、姓名）** | App 功能：使用者登入與個人檔案 | 否 |
| **位置（精確位置）** | App 功能：顯示附近診所 | 否 |
| **使用者內容（評價、評論內容、照片）** | App 功能：社群功能 | 否 |
| **識別碼（使用者 ID）** | App 功能：帳號關聯 | 否 |
| **購買項目** | App 功能：Premium 訂閱管理 | 否 |

### 5.2 填寫方式

在 App Store Connect → App → **「App 隱私權」** 分頁 → 點擊 **「開始使用」**，依序回答問卷。

### 5.3 隱私權政策 URL

必須提供一個公開的隱私權政策網址。若暫無獨立頁面，可使用 [GitHub Pages](https://pages.github.com/) 或 [Notion 公開頁面](https://www.notion.so/) 暫代。

---

## 六、TestFlight 設定步驟

### 6.1 前置條件

- App Store Connect 應用程式記錄已建立
- App 至少上傳過一個通過審核的建置版本
- Apple Developer Program 會籍有效（年費已繳）

### 6.2 上傳建置版本

1. 在 Xcode 中選擇 **Any iOS Device (arm64)** 作為執行目標
2. 選單列 → **Product** → **Archive**
3. Archives 視窗開啟後，選擇剛產生的 archive → **Distribute App**
4. 選擇 **App Store Connect** → **Upload**
5. 勾選 **Manage Version and Build Number** 與 **Strip Swift symbols**（建議）
6. 等待上傳完成

### 6.3 建立測試群組

1. 前往 App Store Connect → **「App」** → 選擇 VetMap → **「TestFlight」** 分頁
2. 在 **「內部測試」** 區域，點擊 **「+」** 新增測試人員（Apple ID 郵箱）
3. 可建立 **「外部測試群組」** 邀請公開測試人員（最多 10,000 人，需通過 Beta App Review）
4. 上傳的建置版本會自動出現在 TestFlight 可選列表中
5. 設定測試資訊：
   - **測試內容說明（What to Test）**: 填寫本版本的測試重點
   - **測試回饋信箱**: 填寫開發團隊聯絡信箱
   - **Beta App 描述**: 對外公開的測試版說明

### 6.4 內部測試 vs 外部測試

| 特性 | 內部測試 | 外部測試 |
|---|---|---|
| 人數上限 | 100 人 | 10,000 人 |
| Beta 審核 | 不需要 | 需要（首次提交時） |
| 建置立即可用 | 是 | 需審核通過後 |
| 適用情境 | 開發團隊內部 | 種子用戶、公測 |

### 6.5 測試人員操作

測試人員會收到 Apple 的邀請郵件，點擊「View in TestFlight」後：

1. 在 iOS 裝置上安裝 TestFlight App
2. 接受邀請並安裝 Beta 版
3. 每次有新版本時自動收到更新通知
4. 可透過 TestFlight App 直接提交回饋（含螢幕截圖）

---

## 七、提交審核前檢查清單

- [ ] App 圖示（1024x1024 無圓角 PNG）
- [ ] 至少一組截圖（6.9 吋，最少 3 張）
- [ ] 隱私權政策 URL
- [ ] 隱私權標籤填寫完成
- [ ] 年齡分級問卷完成
- [ ] IAP 產品建立並狀態為「已核准」
- [ ] IAP 產品已加入 App 的 IAP 列表並顯示為「Ready to Submit」
- [ ] 建置版本已上傳且處理完成
- [ ] TestFlight 內部測試已通過基本驗證
- [ ] 版權資訊：`Copyright © 2025 VetMap. All rights reserved.`
- [ ] 沒有使用非公開 API
- [ ] 符合 App Store Review Guidelines
