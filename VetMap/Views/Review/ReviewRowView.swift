import SwiftUI

struct ReviewRowView: View {
    let review: Review
    let currency: String
    var onMarkHelpful: (() -> Void)?
    var onReport: ((String) -> Void)?
    var onBlockAuthor: (() -> Void)?

    private static let reportReasons = ["不實內容", "冒犯性言論", "廣告或垃圾訊息", "其他"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(review.title)
                        .font(.subheadline.weight(.semibold))

                    Text(review.userName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                starRatingView
            }

            Text(review.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let images = review.images, !images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(images.indices, id: \.self) { index in
                            KingfisherImage(
                                url: images[index],
                                placeholder: .default,
                                contentMode: .fill,
                                cornerRadius: AppTheme.compactRadius,
                                showsCardBorder: true
                            )
                            .frame(width: 100, height: 100)
                        }
                    }
                }
            }

            FlowLayout(spacing: 6) {
                if let treatmentType = review.treatmentType, !treatmentType.isEmpty {
                    Text(treatmentType)
                        .appChip(tint: AppTheme.accent)
                }

                if let cost = review.cost {
                    Text(formattedCost(cost))
                        .appChip(tint: AppTheme.primary)
                }

                if let onMarkHelpful {
                    Button {
                        onMarkHelpful()
                    } label: {
                        Label("有用 (\(review.helpfulCount))", systemImage: "hand.thumbsup")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .tint(AppTheme.warning)
                } else {
                    Label("\(review.helpfulCount)", systemImage: "hand.thumbsup.fill")
                        .appChip(tint: AppTheme.warning)
                }
            }

            HStack {
                Text(relativeDateString(from: review.createdAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                Text("評分 \(review.rating)/5")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if onReport != nil || onBlockAuthor != nil {
                    Menu {
                        if let onReport {
                            ForEach(Self.reportReasons, id: \.self) { reason in
                                Button {
                                    onReport(reason)
                                } label: {
                                    Text("舉報：\(reason)")
                                }
                            }
                        }
                        if let onBlockAuthor {
                            Button(role: .destructive) {
                                onBlockAuthor()
                            } label: {
                                Label("封鎖作者", systemImage: "person.crop.circle.badge.xmark")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.caption)
                    }
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("評價操作")
                }
            }
        }
        .padding(14)
        .appCard()
    }

    private var starRatingView: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { value in
                Image(systemName: value <= review.rating ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.warning)
                    .scaleEffect(value <= review.rating ? 1.0 : 0.8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6).delay(Double(value) * 0.1), value: review.rating)
            }
        }
        .accessibilityLabel("評分 \(review.rating) 分")
    }

    private func formattedCost(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let number = NSDecimalNumber(decimal: amount)
        return "\(currency) \(formatter.string(from: number) ?? number.stringValue)"
    }

    private func relativeDateString(from date: Date) -> String {
        let components = Calendar.current.dateComponents(
            [.year, .month, .weekOfYear, .day, .hour, .minute],
            from: date,
            to: Date()
        )

        if let years = components.year, years > 0 { return "\(years)年前" }
        if let months = components.month, months > 0 { return "\(months)個月前" }
        if let weeks = components.weekOfYear, weeks > 0 { return "\(weeks)週前" }
        if let days = components.day, days > 0 { return "\(days)天前" }
        if let hours = components.hour, hours > 0 { return "\(hours)小時前" }
        if let minutes = components.minute, minutes > 0 { return "\(minutes)分鐘前" }
        return "剛剛"
    }
}
