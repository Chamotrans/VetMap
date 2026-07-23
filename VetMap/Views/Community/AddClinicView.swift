import SwiftUI

struct AddClinicView: View {
    var successMessage: LocalizedStringKey = "新增成功"
    var onSubmit: (VetClinic) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var viewModel = AddClinicViewModel()
    @State private var showSuccess = false
    @State private var isSubmitting = false

    private enum Field: Hashable {
        case name
        case address
        case phone
        case website
        case latitude
        case longitude
        case services
        case tags
        case openingHours
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("診所名稱", text: $viewModel.name)
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .name)
                        .accessibilityLabel("診所名稱")

                    TextField("地址", text: $viewModel.address, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($focusedField, equals: .address)
                        .accessibilityLabel("診所地址")

                    TextField("電話", text: $viewModel.phone)
                        .keyboardType(.phonePad)
                        .focused($focusedField, equals: .phone)
                        .accessibilityLabel("診所電話")

                    TextField("網站 URL", text: $viewModel.website)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .website)
                } header: {
                    Label("基本資料", systemImage: "cross.case.fill")
                }

                Section {
                    Button {
                        focusedField = nil
                        Task {
                            await viewModel.lookupAddressLocation()
                        }
                    } label: {
                        HStack {
                            if viewModel.isResolvingLocation {
                                ProgressView()
                            } else {
                                Image(systemName: "magnifyingglass")
                                    .accessibilityHidden(true)
                            }

                            Text(viewModel.isResolvingLocation ? "查找中" : "查找位置")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: AppTheme.cardRadius))
                    .disabled(!viewModel.canLookupAddress)

                    Picker("地區", selection: $viewModel.selectedRegion) {
                        ForEach(AddClinicViewModel.RegionPreset.allCases) { region in
                            Text(region.rawValue).tag(region)
                        }
                    }

                    if viewModel.selectedRegion == .custom {
                        TextField("緯度", text: $viewModel.latitude)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .latitude)

                        TextField("經度", text: $viewModel.longitude)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .longitude)
                    }

                    locationLookupFeedback
                } header: {
                    Label("位置", systemImage: "mappin.and.ellipse")
                }

                Section {
                    TextField("服務項目", text: $viewModel.services, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($focusedField, equals: .services)

                    TextField("標籤", text: $viewModel.tags, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($focusedField, equals: .tags)

                    TextField("今日營業時間", text: $viewModel.openingHours)
                        .focused($focusedField, equals: .openingHours)
                } header: {
                    Label("社群資訊", systemImage: "person.2.fill")
                } footer: {
                    Text("多個服務或標籤請用逗號分隔。")
                }

                Section {
                    Stepper(value: $viewModel.priceLevel, in: 1...3) {
                        HStack {
                            Text("價格等級")
                            Spacer()
                            Text(String(repeating: "$", count: viewModel.priceLevel))
                                .foregroundStyle(.teal)
                                .fontWeight(.semibold)
                        }
                    }

                    Label("提交後由管理員人工審核", systemImage: "person.badge.shield.checkmark")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("分類", systemImage: "slider.horizontal.3")
                }

                if let validationMessage = viewModel.validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenBackground)
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(
                TapGesture().onEnded {
                    focusedField = nil
                },
                including: focusedField != nil ? .all : .subviews
            )
            .navigationTitle("新增診所")
            .navigationBarTitleDisplayMode(.inline)
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
                    .disabled(!viewModel.canSubmit || isSubmitting)
                    .accessibilityLabel("提交診所資料")
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        focusedField = nil
                    }
                    .fontWeight(.semibold)
                }
            }
            .overlay {
                if showSuccess {
                    successOverlay
                }
            }
        }
    }

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(AppTheme.primary)

                Text(successMessage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(showSuccess ? 1 : 0.5)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showSuccess)
        }
    }

    private func submit() async {
        guard let clinic = viewModel.makeClinic() else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await onSubmit(clinic)
            Analytics.clinicAdded(clinic.name)
            Haptics.success()
            showSuccess = true
            try? await Task.sleep(for: .milliseconds(800))
            showSuccess = false
            dismiss()
        } catch {
            viewModel.validationMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private var locationLookupFeedback: some View {
        switch viewModel.locationLookupState {
        case .idle, .resolving:
            EmptyView()
        case .resolved(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.primary)
                .fixedSize(horizontal: false, vertical: true)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    AddClinicView { _ in }
}
