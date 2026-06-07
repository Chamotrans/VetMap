import SwiftUI

struct ConfettiView: View {
    @State private var particles: [Particle] = []
    @State private var isAnimating = false
    
    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var rotation: Double
        var color: Color
        var scale: CGFloat
    }
    
    let colors: [Color] = [.teal, .indigo, .orange, .pink, .yellow, .green, .purple, .red]
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: 8, height: 8)
                    .scaleEffect(particle.scale)
                    .position(x: particle.x, y: particle.y)
                    .rotationEffect(.degrees(particle.rotation))
                    .opacity(isAnimating ? 0 : 1)
            }
        }
        .onAppear {
            generateParticles()
            withAnimation(.easeOut(duration: 1.5)) {
                isAnimating = true
            }
        }
    }
    
    private func generateParticles() {
        for _ in 0..<40 {
            particles.append(Particle(
                x: CGFloat.random(in: 0...400),
                y: -20,
                rotation: Double.random(in: 0...360),
                color: colors.randomElement()!,
                scale: CGFloat.random(in: 0.5...1.5)
            ))
        }
    }
}

struct ConfettiOverlay: ViewModifier {
    @Binding var show: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if show {
                    ConfettiView()
                        .allowsHitTesting(false)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                show = false
                            }
                        }
                }
            }
    }
}

extension View {
    func confetti(isShowing: Binding<Bool>) -> some View {
        modifier(ConfettiOverlay(show: isShowing))
    }
}
