import SwiftUI

// MARK: - Liquid Glass (iOS 26 / Xcode 26+) with graceful fallback
// .glassEffect() is only available in the Xcode 26 SDK (Swift 6.2+).
// The #if compiler(>=6.2) guard prevents compile errors on CI (Xcode 16.x).
// At runtime, #available(iOS 26, *) ensures it runs only on iOS 26 devices.

extension View {
    /// Applies Liquid Glass on iOS 26+ (Xcode 26 SDK); falls back to .regularMaterial.
    @ViewBuilder
    func liquidGlass(
        cornerRadius: CGFloat = AppTheme.cardRadius,
        tint: Color? = nil
    ) -> some View {
        #if compiler(>=6.2)
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
        #else
        self
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.36), lineWidth: 1)
            )
        #endif
    }

    /// Capsule-shaped Liquid Glass (for FABs and pill buttons).
    @ViewBuilder
    func liquidGlassCapsule(tint: Color? = nil) -> some View {
        #if compiler(>=6.2)
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
        #else
        self
            .background(tint ?? Color(.systemBackground), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
        #endif
    }
}
