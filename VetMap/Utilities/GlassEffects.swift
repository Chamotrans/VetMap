import SwiftUI

// MARK: - Liquid Glass (iOS 26+) with graceful fallback
// iOS 26 引入 Liquid Glass 設計語言。floating / 導航元素應使用玻璃效果，
// 內容背景則維持實色。此 helper 在 iOS 26 套用原生 .glassEffect()，
// 較舊系統則降級為 .regularMaterial，確保 iOS 17+ 一致體驗。

extension View {
    /// 對浮動元素套用 Liquid Glass（iOS 26+），舊版降級為 material。
    /// - Parameters:
    ///   - cornerRadius: 圓角半徑
    ///   - tint: 可選色調（iOS 26 玻璃染色）
    @ViewBuilder
    func liquidGlass(
        cornerRadius: CGFloat = AppTheme.cardRadius,
        tint: Color? = nil
    ) -> some View {
        if #available(iOS 26.0, *) {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            if let tint {
                self.glassEffect(.regular.tint(tint).interactive(), in: shape)
            } else {
                self.glassEffect(.regular.interactive(), in: shape)
            }
        } else {
            self
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.36), lineWidth: 1)
                )
        }
    }

    /// Capsule 形狀的 Liquid Glass（用於 FAB、藥丸按鈕）。
    @ViewBuilder
    func liquidGlassCapsule(tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                self.glassEffect(.regular.tint(tint).interactive(), in: .capsule)
            } else {
                self.glassEffect(.regular.interactive(), in: .capsule)
            }
        } else {
            self
                .background(tint ?? Color(.systemBackground), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
        }
    }
}
