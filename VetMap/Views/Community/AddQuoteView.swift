import SwiftUI

struct AddQuoteView: View {
    let viewModel: QuoteViewModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var treatmentType = "疫苗接種"
    @State private var estimatedCost = ""
    @State private var actualCost = ""
    @State private var isNotTreated = false
    @State private var notes = ""
    @State private var validationMessage: String?
    @State private var isSubmitting = false
    @State private var showSubmittedNotice = false

    private let treatmentTypes = [
        "疫苗接種", "一般診療", "外科手術", "牙科", "腫瘤諮詢",
        "影像檢查", "住院治療", "夜間門診", "結紮手術", "健康檢查",
        "皮膚科", "行為諮詢", "其他"
    ]

    private enum Field: Hashable {
        case estimatedCost
        case actualCost
        case notes
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("治療類型", selection: $treatmentType) {
                        ForEach(treatmentTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                } header: {
                    Label("治療類型", systemImage: "cross.case.fill")
                }

                Section {
                    HStack {
                        Text("HK$")
                            .foregroundStyle(.secondary)
                        TextField("預估費用", text: $estimatedCost)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .estimatedCost)
                    }

                    Toggle("尚未治療", isOn: $isNotTreated.animation())

                    if !isNotTreated {
                        HStack {
                            Text("HK$")
                                .foregroundStyle(.secondary)
                            TextField("實際費用（選填）", text: $actualCost)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .actualCost)
                        }
                    }

                    LabeledContent("幣別") {
                        Text("HKD (港幣)")
                    }
                } header: {
                    Label("費用明細", systemImage: "dollarsign.circle.fill")
                }

                Section {
                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("寫下治療心得或注意事項...")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $notes)
                            .frame(minHeight: 100)
                            .focused($focusedField, equals: .notes)
                    }
                } header: {
                    Label("備註", systemImage: "text.bubble.fill")
                }

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenBackground)
            .navigationTitle("新增報價")
            .navigationBarTitleDisplayMode(.inline)
            .alert("已送出", isPresented: $showSubmittedNotice) {
                Button("好") { dismiss() }
            } message: {
                Text("報價已提交，待管理員審核後公開。")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("提交")
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSubmit || isSubmitting)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        focusedField = nil
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var canSubmit: Bool {
        !trimmed(treatmentType).isEmpty && parsedEstimatedCost != nil
    }

    private var parsedEstimatedCost: Decimal? {
        let value = trimmed(estimatedCost).replacingOccurrences(of: ",", with: "")
        guard !value.isEmpty else { return nil }
        guard let decimal = Decimal(string: value), decimal > 0 else { return nil }
        return decimal
    }

    private var parsedActualCost: Decimal? {
        guard !isNotTreated else { return nil }
        let value = trimmed(actualCost).replacingOccurrences(of: ",", with: "")
        guard !value.isEmpty else { return nil }
        return Decimal(string: value)
    }

    private func submit() async {
        guard let estCost = parsedEstimatedCost else {
            validationMessage = "請輸入有效的預估費用。"
            return
        }

        let actCost = isNotTreated ? nil : parsedActualCost

        isSubmitting = true
        let succeeded = await viewModel.addQuote(
            treatmentType: treatmentType,
            estimatedCost: estCost,
            actualCost: actCost,
            currency: "HKD",
            notes: notes
        )
        isSubmitting = false

        if succeeded {
            showSubmittedNotice = true
        } else {
            validationMessage = viewModel.storageError ?? "暫時無法提交報價。"
        }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
