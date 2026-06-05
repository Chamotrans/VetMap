# Kingfisher 整合指南

> **Kingfisher** 為 Swift 原生圖片下載與快取框架，支援漸進式載入、磁碟快取、GIF 處理等功能。

## SPM 安裝步驟

### 1. 在 Xcode 中加入套件

1. 開啟 `VetMap.xcodeproj`
2. 選單列 → **File** → **Add Package Dependencies…**
3. 搜尋框貼上 Kingfisher 倉庫網址：

   ```
   https://github.com/onevcat/Kingfisher.git
   ```

4. 在 Dependency Rule 選擇 **Up to Next Major Version**，最低版本 `8.0.0`
5. 點擊 **Add Package**
6. 在出現的對話框中，將 Kingfisher 加入 **VetMap** target
7. 點擊 **Add Package** 完成

### 2. 驗證安裝

安裝完成後，專案會自動支援 Kingfisher。程式碼中的 `#if canImport(Kingfisher)` 條件編譯區塊會自動選用 `KFImage`。

無需任何額外的 import 或初始化設定。

## 專案內整合

### KingfisherImage 工具元件

專案已提供 `VetMap/Utilities/KingfisherImage.swift` 作為統一圖片元件：

- **優先路徑**: 當 Kingfisher 已連結時，使用 `KFImage`（支援磁碟快取、漸進式載入）
- **降級路徑**: 當 Kingfisher 未連結時，自動降級為 SwiftUI `AsyncImage`
- **狀態處理**: 載入中 → 進度指示器、錯誤 → 警告圖示、無 URL → 佔位圖示
- **設計系統**: 自動套用 `AppTheme` 色系（teal primary、orange warning）及 `.appCard()` 邊框樣式

### 使用方式

```swift
// 基本用法
KingfisherImage(url: URL(string: "https://example.com/photo.jpg"))
    .frame(width: 200, height: 200)

// 寵物商品圖片（無圖片時顯示 pawprint）
KingfisherImage.product(product.imageURL)
    .frame(width: 100, height: 100)

// 評價照片（無圖片時顯示 photo）
KingfisherImage.review(reviewImageURL)
    .frame(width: 80, height: 80)
```

### 不新增全域設定

本專案採用「無全域預設」策略：不注入 `KF.options` 或全域 `ImageCache` 設定。所有設定直接在 `KingfisherImage` 元件內處理，確保行為統一且可預測。

## 遷移現有圖片位置

以下檔案目前使用暫存圖片或 `Image(systemName:)`，日後可遷移至 `KingfisherImage`：

| 檔案 | 目前做法 | 建議 |
|---|---|---|
| `ProductDetailView.swift` | `Image(systemName: "pawprint.fill")` 佔位 | 改用 `KingfisherImage.product(product.imageURL)` |
| `ProductListView.swift` (ProductCardView) | `Image(systemName: "pawprint.fill")` 佔位 | 改用 `KingfisherImage.product(product.imageURL)` |
| `AddReviewView.swift` (photoThumbnail) | `UIImage(data:)` + `Image(uiImage:)` | 本機照片保留直接載入；遠端 URL 改用 `KingfisherImage.review(url)` |
| `ReviewRowView.swift` | 目前無圖片區塊 | 可加入 `KingfisherImage.review(review.images?.first)` |

> **注意**: `AddReviewView` 的 `PhotosPicker` 流程處理的是本機 `Data`，不需要 Kingfisher。Kingfisher 僅用於遠端 URL 圖片（Firebase Storage 或其他 CDN）。
