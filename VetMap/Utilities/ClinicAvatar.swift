import SwiftUI

// MARK: - 診所頭像 — 以診所名首字取代通用 icon

struct ClinicAvatar: View {
    let name: String
    var size: CGFloat = 46
    var font: Font = .headline

    /// 柔和診所配色：依名稱 hash 揀色，確保同一診所每次相同色
    private var tintColor: Color {
        let colors: [Color] = [
            Color(red: 0.91, green: 0.66, blue: 0.22), // warm amber
            Color(red: 0.24, green: 0.48, blue: 0.36), // sage green
            Color(red: 0.35, green: 0.55, blue: 0.75), // sky blue
            Color(red: 0.75, green: 0.40, blue: 0.40), // terracotta
            Color(red: 0.55, green: 0.45, blue: 0.65), // lavender
            Color(red: 0.30, green: 0.60, blue: 0.55), // teal
            Color(red: 0.85, green: 0.50, blue: 0.35), // rust
            Color(red: 0.40, green: 0.45, blue: 0.60), // slate blue
        ]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }

    /// 診所名首字（取第一個非空白字元）
    private var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tintColor.opacity(0.13))

            Circle()
                .stroke(tintColor.opacity(0.30), lineWidth: 1.5)

            Text(initial)
                .font(font.weight(.bold))
                .foregroundStyle(tintColor)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - 小型 avatar（列表用）

struct ClinicAvatarSmall: View {
    let name: String

    var body: some View {
        ClinicAvatar(name: name, size: 42, font: .headline)
    }
}

#Preview {
    HStack(spacing: 16) {
        ClinicAvatar(name: "VetMap 測試診所 A")
        ClinicAvatar(name: "VetMap 測試診所 B")
        ClinicAvatar(name: "VetMap Preview Clinic")
        ClinicAvatar(name: "VetMap 測試診所 C")
        ClinicAvatar(name: "VetMap Preview Centre")
    }
    .padding()
}
