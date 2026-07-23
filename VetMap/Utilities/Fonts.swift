import SwiftUI

// MARK: - 字體工具
// 使用系統 rounded design，避免在 release bundle 夾帶未有 rights packet
// 及 license notice 的第三方字型。

enum VetMapFont {
    /// 大標題專用
    static let display: Font = .system(.largeTitle, design: .rounded).weight(.bold)

    /// 次標題
    static let heading: Font = .system(.title2, design: .rounded)
}

extension View {
    /// 在 display/heading 層級使用系統圓體字型
    func vetMapDisplayFont() -> some View {
        self.font(VetMapFont.display)
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
