import SwiftUI

struct ContributorBadge: View {
    let reviewCount: Int
    
    private var badge: (String, Color, String) {
        switch reviewCount {
        case 0..<1: return ("", .gray, "")
        case 1..<5: return ("leaf.fill", .green, "新手")
        case 5..<10: return ("star.fill", .yellow, "常客")
        case 10..<20: return ("star.circle.fill", .orange, "達人")
        case 20..<50: return ("crown.fill", .purple, "專家")
        default: return ("crown.fill", .indigo, "大師")
        }
    }
    
    var body: some View {
        if reviewCount > 0 {
            let (icon, color, title) = badge
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption2)
            }
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
        }
    }
}
