import SwiftUI

// MARK: - 自訂字體工具
// 使用 Rounded Mplus 1c (圓體) 作為 display/heading 字體
// Body/Caption 保持 San Francisco 確保可讀性

enum VetMapFont {
    /// 大標題專用 — Rounded Mplus 1c Bold
    static let display: Font = {
        let size: CGFloat = UIFont.preferredFont(forTextStyle: .largeTitle).pointSize
        return .custom("Rounded Mplus 1c", size: size, relativeTo: .largeTitle)
    }()

    /// 次標題 — Rounded Mplus 1c Regular
    static let heading: Font = {
        let size: CGFloat = UIFont.preferredFont(forTextStyle: .title2).pointSize
        return .custom("Rounded Mplus 1c", size: size, relativeTo: .title2)
    }()
}

extension View {
    /// 在 display/heading 層級使用自訂圓體字型
    func vetMapDisplayFont() -> some View {
        self.font(.custom("Rounded Mplus 1c", size: UIFont.preferredFont(forTextStyle: .largeTitle).pointSize, relativeTo: .largeTitle))
    }
}

// MARK: - 字體註冊輔助（Debug 用）

enum FontRegistration {
    /// 打印所有已註冊字體名稱 — Debug 用途
    static func logAvailableFonts() {
        #if DEBUG
        for family in UIFont.familyNames.sorted() {
            let names = UIFont.fontNames(forFamilyName: family)
            if !names.isEmpty {
                print("📝 Font family: \(family) → \(names.joined(separator: ", "))")
            }
        }
        #endif
    }
}
