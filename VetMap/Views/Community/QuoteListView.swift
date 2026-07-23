import SwiftUI

struct QuoteListView: View {
    let clinicId: String
    let clinicName: String

    @State private var viewModel: QuoteViewModel
    @State private var isAddingQuote = false

    init(clinicId: String, clinicName: String) {
        self.clinicId = clinicId
        self.clinicName = clinicName
        _viewModel = State(
            wrappedValue: QuoteViewModel(clinicId: clinicId, clinicName: clinicName)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let error = viewModel.storageError {
                    Label(error, systemImage: "externaldrive.badge.exclamationmark")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.warning)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appCard(fill: AppTheme.warning.opacity(0.12), stroke: AppTheme.warning.opacity(0.22))
                }

                if viewModel.visibleQuotes.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.visibleQuotes) { quote in
                        quoteCard(quote)
                    }
                }
            }
            .padding(16)
        }
        .background(AppTheme.screenBackground)
        .refreshable {
            await viewModel.loadQuotes()
        }
        .navigationTitle("\(clinicName) 費用報價")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddingQuote = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingQuote) {
            AddQuoteView(viewModel: viewModel)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "dollarsign.circle")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.primary)
                .accessibilityHidden(true)

            Text("尚無報價記錄，成為第一個分享的吧！")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .appCard()
    }

    private func quoteCard(_ quote: Quote) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text("💉")
                    .font(.title3)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(quote.treatmentType)
                        .font(.subheadline.weight(.semibold))

                    costSummary(quote)
                }

                Spacer()

                Text(quote.currency)
                    .appChip(
                        tint: quote.currency == "TWD" ? AppTheme.primary : AppTheme.accent,
                        isFilled: true
                    )

                Menu {
                    ForEach(["資料不實", "冒犯內容", "廣告或垃圾訊息", "其他"], id: \.self) { reason in
                        Button {
                            Task { _ = await viewModel.report(quote, reason: reason) }
                        } label: {
                            Text("舉報：\(reason)")
                        }
                    }
                    Button(role: .destructive) {
                        Task { _ = await viewModel.blockAuthor(of: quote) }
                    } label: {
                        Label("封鎖作者", systemImage: "person.crop.circle.badge.xmark")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.tertiary)
                }
            }

            if !quote.notes.isEmpty {
                Text(quote.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Text(quote.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .environment(\.locale, Locale(identifier: "zh_Hant"))
            }
        }
        .padding(14)
        .appCard()
    }

    @ViewBuilder
    private func costSummary(_ quote: Quote) -> some View {
        if let actualCost = quote.actualCost, actualCost != quote.estimatedCost {
            Text("預估 \(costText(quote.estimatedCost, currency: quote.currency)) → 實際 \(costText(actualCost, currency: quote.currency))")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let actualCost = quote.actualCost {
            Text(costText(actualCost, currency: quote.currency))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("預估 \(costText(quote.estimatedCost, currency: quote.currency))（尚未治療）")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func costText(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        let number = NSDecimalNumber(decimal: amount)
        let symbol = currency == "TWD" ? "NT$" : "HK$"
        return "\(symbol)\(formatter.string(from: number) ?? number.stringValue)"
    }
}

#Preview {
    NavigationStack {
        QuoteListView(clinicId: "debug-clinic", clinicName: "VetMap 測試診所")
    }
}
