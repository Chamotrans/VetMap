import SwiftUI

// MARK: - 有機質感背景
// 用 Canvas 生成微粒紋理取代純色 gray background
// 靈感來自診所木質櫃枱 / 溫暖紙紋

struct OrganicBackgroundModifier: ViewModifier {
    var baseColor: Color = Color(red: 0.98, green: 0.96, blue: 0.93) // warm cream
    var grainOpacity: Double = 0.035
    var grainCount: Int = 600

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    baseColor

                    // 微粒紋理
                    Canvas { context, size in
                        var rng = SeededRandom(seed: 42)
                        for _ in 0..<grainCount {
                            let x = rng.next() * size.width
                            let y = rng.next() * size.height
                            let radius = rng.next() * 1.5 + 0.3
                            let alpha = rng.next() * grainOpacity

                            let rect = CGRect(x: x, y: y, width: radius * 2, height: radius * 2)
                            context.fill(
                                Path(ellipseIn: rect),
                                with: .color(.brown.opacity(alpha))
                            )
                        }
                    }
                    .allowsHitTesting(false)
                }
            )
    }
}

/// 簡單 deterministic pseudo-random (Canvas 不支援系統 random 因每次 render 結果不同)
private struct SeededRandom {
    private var value: UInt64

    init(seed: Int) {
        self.value = UInt64(bitPattern: Int64(seed))
    }

    mutating func next() -> Double {
        value = value &* 6364136223846793005 &+ 1442695040888963407
        let bits = Double(value >> 2) / Double(UInt64.max)
        return bits
    }
}

// MARK: - 卡片點按縮放

struct PressScaleModifier: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: 50) { } onPressingChanged: { pressing in
                isPressed = pressing
            }
    }
}

// MARK: - View Extensions

extension View {
    /// 有機微粒紋理背景
    func organicBackground(
        color: Color = Color(red: 0.98, green: 0.96, blue: 0.93),
        grainOpacity: Double = 0.035
    ) -> some View {
        modifier(OrganicBackgroundModifier(baseColor: color, grainOpacity: grainOpacity))
    }

    /// 卡片點按縮放效果
    func pressScale() -> some View {
        modifier(PressScaleModifier())
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(0..<3) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .frame(height: 80)
                    .pressScale()
            }
        }
        .padding()
    }
    .organicBackground()
}
