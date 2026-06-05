import SwiftUI
import PhotosUI

struct AddReviewView: View {
    let clinicName: String
    var onSubmit: (ReviewDraft) -> Bool

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var rating = 5
    @State private var title = ""
    @State private var content = ""
    @State private var treatmentType = "一般診療"
    @State private var cost = ""
    @State private var validationMessage: String?

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedPhotoData: [Data] = []

    private let treatmentTypes = [
        "疫苗接種", "一般診療", "外科手術", "牙科",
        "皮膚科", "影像檢查", "夜間門診", "初診", "其他"
    ]

    private let maxPhotos = 3

    private enum Field: Hashable {
        case title
        case content
        case cost
    }

    var body: some View {
        NavigationStack {
            Form {
                ratingSection
                contentSection
                treatmentSection
                photoSection
                validationSection
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenBackground)
            .navigationTitle("新增評價")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("提交") { submit() }
                        .fontWeight(.semibold)
                        .disabled(!canSubmit)
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

    // MARK: - Sections

    private var ratingSection: some View {
        Section {
            VStack(alignment: .center, spacing: 10) {
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            rating = value
                        } label: {
                            Image(systemName: value <= rating ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundStyle(value <= rating ? AppTheme.warning : .gray.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(value) 星")
                    }
                }

                Text(ratingDescription)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        } header: {
            Label("整體評分", systemImage: "star.fill")
        }
    }

    private var contentSection: some View {
        Section {
            TextField("例如：醫生很有耐心", text: $title)
                .focused($focusedField, equals: .title)

            TextField("分享你的診療經驗...", text: $content, axis: .vertical)
                .lineLimit(4...8)
                .focused($focusedField, equals: .content)
        } header: {
            Label("評價內容", systemImage: "text.bubble.fill")
        } footer: {
            Text("標題和內容均為必填項目")
        }
    }

    private var treatmentSection: some View {
        Section {
            Picker("治療類型", selection: $treatmentType) {
                ForEach(treatmentTypes, id: \.self) { type in
                    Text(type).tag(type)
                }
            }

            HStack {
                Text(clinicName.localizedCaseInsensitiveContains("香港") ? "HKD" : "TWD")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)

                TextField("實際收費（選填）", text: $cost)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .cost)
            }

            if hasInvalidCost {
                Label("請輸入有效金額，或留空。", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.warning)
            }
        } header: {
            Label("治療與費用", systemImage: "dollarsign.circle.fill")
        } footer: {
            Text(clinicName)
        }
    }

    private var photoSection: some View {
        Section {
            if !selectedPhotoData.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(selectedPhotoData.enumerated()), id: \.offset) { index, data in
                            photoThumbnail(data: data, index: index)
                        }
                    }
                }
            }

            if selectedPhotoItems.count < maxPhotos {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: maxPhotos,
                    matching: .images
                ) {
                    Label(
                        "新增照片 (\(selectedPhotoItems.count)/\(maxPhotos))",
                        systemImage: "photo.on.rectangle.angled"
                    )
                }
            }
        } header: {
            Label("照片", systemImage: "photo")
        } footer: {
            // Firebase Storage upload will be added in a future update.
            Text("照片將儲存於本機，稍後將支援雲端備份。")
        }
        .onChange(of: selectedPhotoItems) { _, items in
            Task {
                selectedPhotoData = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        selectedPhotoData.append(data)
                    }
                }
            }
        }
    }

    private func photoThumbnail(data: Data, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.compactRadius))
            }

            Button {
                selectedPhotoData.remove(at: index)
                selectedPhotoItems.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .background(Circle().fill(.black.opacity(0.55)))
            }
            .offset(x: 6, y: -6)
        }
    }

    @ViewBuilder
    private var validationSection: some View {
        if let validationMessage {
            Section {
                Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Computed properties

    private var ratingDescription: String {
        switch rating {
        case 1: return "非常不滿意"
        case 2: return "不滿意"
        case 3: return "一般"
        case 4: return "滿意"
        case 5: return "非常滿意"
        default: return ""
        }
    }

    private var canSubmit: Bool {
        !trimmed(title).isEmpty && !trimmed(content).isEmpty && !hasInvalidCost
    }

    private var hasInvalidCost: Bool {
        !trimmed(cost).isEmpty && parsedCost == nil
    }

    private var parsedCost: Decimal? {
        let value = trimmed(cost).replacingOccurrences(of: ",", with: "")
        guard !value.isEmpty else { return nil }
        return Decimal(string: value)
    }

    // MARK: - Submission

    private func submit() {
        guard !trimmed(title).isEmpty else {
            validationMessage = "請填寫評價標題。"
            return
        }

        guard !trimmed(content).isEmpty else {
            validationMessage = "請填寫評價內容。"
            return
        }

        guard (1...5).contains(rating) else {
            validationMessage = "請選擇評分。"
            return
        }

        guard !hasInvalidCost else {
            validationMessage = "請輸入有效金額，或留空後再提交。"
            return
        }

        let draft = ReviewDraft(
            rating: rating,
            title: title,
            content: content,
            treatmentType: treatmentType,
            cost: parsedCost
        )

        if onSubmit(draft) {
            dismiss()
        } else {
            validationMessage = "提交失敗，請稍後再試。"
        }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Firebase Storage upload will be added in a future update.
    private func savePhotosLocally() -> [URL] {
        let directory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "review-photos", directoryHint: .isDirectory)

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        return selectedPhotoData.compactMap { data in
            let url = directory.appending(path: "\(UUID().uuidString).jpg")
            do {
                try data.write(to: url)
                return url
            } catch {
                return nil
            }
        }
    }
}

#Preview {
    AddReviewView(clinicName: "安心動物醫院") { _ in true }
}
