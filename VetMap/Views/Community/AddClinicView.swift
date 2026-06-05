import SwiftUI

struct AddClinicView: View {
    var onSubmit: (VetClinic) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @StateObject private var viewModel = AddClinicViewModel()

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

                    TextField("地址", text: $viewModel.address, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($focusedField, equals: .address)

                    TextField("電話", text: $viewModel.phone)
                        .keyboardType(.phonePad)
                        .focused($focusedField, equals: .phone)

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

                    Toggle("已由社群驗證", isOn: $viewModel.verified)
                        .tint(AppTheme.primary)
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
            .navigationTitle("新增診所")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("提交") {
                        submit()
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.canSubmit)
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

    private func submit() {
        guard let clinic = viewModel.makeClinic() else { return }
        onSubmit(clinic)
        dismiss()
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
