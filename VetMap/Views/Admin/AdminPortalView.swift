import SwiftUI

// MARK: - 管理後台入口

struct AdminPortalView: View {
    @ObservedObject private var store = ModerationStore.shared

    var body: some View {
        List {
            if let error = store.errorMessage {
                Section {
                    Label(error, systemImage: "icloud.slash")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.warning)
                }
            }

            Section {
                NavigationLink {
                    AdminClinicManageView()
                } label: {
                    AdminRow(
                        title: "置頂與診所管理",
                        subtitle: "設定置頂、下架或還原診所",
                        systemImage: "pin.fill",
                        tint: AppTheme.primary
                    )
                }

                NavigationLink {
                    AdminPendingClinicsView()
                } label: {
                    AdminRow(
                        title: "待審核診所",
                        subtitle: "批核社群新增的診所",
                        systemImage: "building.2.crop.circle.fill",
                        tint: .blue,
                        badge: store.pendingClinics.count
                    )
                }

                NavigationLink {
                    AdminPendingReviewsView()
                } label: {
                    AdminRow(
                        title: "待審核留言",
                        subtitle: "批核社群留下的評價",
                        systemImage: "text.bubble.fill",
                        tint: .purple,
                        badge: store.pendingReviews.count
                    )
                }

                NavigationLink {
                    AdminPendingQuotesView()
                } label: {
                    AdminRow(
                        title: "待審核報價",
                        subtitle: "批核社群提交的費用資料",
                        systemImage: "dollarsign.circle.fill",
                        tint: .green,
                        badge: store.pendingQuotes.count
                    )
                }

                NavigationLink {
                    AdminReportsView()
                } label: {
                    AdminRow(
                        title: "舉報處理",
                        subtitle: "檢視並處理用戶舉報",
                        systemImage: "flag.fill",
                        tint: AppTheme.warning,
                        badge: store.pendingReportsCount
                    )
                }
            } footer: {
                Text("管理員身分由 Firestore 角色決定，所有操作會即時生效。")
            }
        }
        .navigationTitle("管理後台")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await store.refreshAdminQueue()
        }
        .refreshable {
            await store.refreshAdminQueue()
        }
    }
}

private struct AdminRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    let tint: Color
    var badge: Int = 0

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(tint, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if badge > 0 {
                Text("\(badge)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.warning, in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 置頂與診所管理

struct AdminClinicManageView: View {
    @ObservedObject private var store = ModerationStore.shared
    @State private var clinicViewModel = ClinicsViewModel()
    @State private var query = ""

    private var clinics: [VetClinic] {
        let all = clinicViewModel.clinics
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.address.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            ForEach(clinics) { clinic in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        if store.isPinned(clinic.id) {
                            Image(systemName: "pin.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.primary)
                        }
                        if store.isRemoved(clinicID: clinic.id) {
                            Text("已下架")
                                .appChip(tint: AppTheme.warning, isFilled: true)
                        }
                        Text(clinic.name)
                            .font(.subheadline.weight(.semibold))
                            .strikethrough(store.isRemoved(clinicID: clinic.id))
                    }

                    Text(clinic.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 10) {
                        Button {
                            Task {
                                await store.togglePin(clinic.id)
                                if store.errorMessage == nil { Haptics.medium() }
                            }
                        } label: {
                            Label(
                                store.isPinned(clinic.id) ? "取消置頂" : "置頂",
                                systemImage: store.isPinned(clinic.id) ? "pin.slash" : "pin"
                            )
                            .font(.caption.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                        .tint(AppTheme.primary)

                        Button(role: store.isRemoved(clinicID: clinic.id) ? nil : .destructive) {
                            Task {
                                await store.setClinicRemoved(
                                    clinic.id,
                                    !store.isRemoved(clinicID: clinic.id)
                                )
                                if store.errorMessage == nil { Haptics.medium() }
                            }
                        } label: {
                            Label(
                                store.isRemoved(clinicID: clinic.id) ? "還原" : "下架",
                                systemImage: store.isRemoved(clinicID: clinic.id) ? "arrow.uturn.backward" : "eye.slash"
                            )
                            .font(.caption.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .searchable(text: $query, prompt: "搜尋診所")
        .navigationTitle("診所管理")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await clinicViewModel.loadClinics()
        }
    }
}

// MARK: - 待審核診所

struct AdminPendingClinicsView: View {
    @ObservedObject private var store = ModerationStore.shared

    var body: some View {
        List {
            if store.pendingClinics.isEmpty {
                emptyRow("目前沒有待審核的診所")
            } else {
                ForEach(store.pendingClinics) { pending in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(pending.clinic.name)
                            .font(.subheadline.weight(.semibold))
                        Text(pending.clinic.address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(
                            "座標：\(pending.clinic.coordinate.latitude, specifier: "%.5f"), "
                                + "\(pending.clinic.coordinate.longitude, specifier: "%.5f")"
                        )
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        if !pending.clinic.services.isEmpty {
                            Text(pending.clinic.services.joined(separator: "、"))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                        }
                        Text("提交於 \(pending.submittedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        decisionButtons(
                            onApprove: {
                                Task {
                                    await store.approveSubmission(id: pending.id)
                                    if store.errorMessage == nil { Haptics.success() }
                                }
                            },
                            onReject: {
                                Task {
                                    await store.rejectSubmission(id: pending.id)
                                    if store.errorMessage == nil { Haptics.medium() }
                                }
                            }
                        )
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("待審核診所")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 待審核留言

struct AdminPendingReviewsView: View {
    @ObservedObject private var store = ModerationStore.shared

    var body: some View {
        List {
            if store.pendingReviews.isEmpty {
                emptyRow("目前沒有待審核的留言")
            } else {
                ForEach(store.pendingReviews) { pending in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(pending.review.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Label("\(pending.review.rating)", systemImage: "star.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.warning)
                        }
                        Text(pending.clinicName)
                            .font(.caption)
                            .foregroundStyle(AppTheme.primary)
                        Text(pending.review.content)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("由 \(pending.review.userName) · \(pending.submittedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        decisionButtons(
                            onApprove: {
                                Task {
                                    await store.approveSubmission(id: pending.id)
                                    if store.errorMessage == nil { Haptics.success() }
                                }
                            },
                            onReject: {
                                Task {
                                    await store.rejectSubmission(id: pending.id)
                                    if store.errorMessage == nil { Haptics.medium() }
                                }
                            }
                        )
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("待審核留言")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 待審核報價

struct AdminPendingQuotesView: View {
    @ObservedObject private var store = ModerationStore.shared

    var body: some View {
        List {
            if store.pendingQuotes.isEmpty {
                emptyRow("目前沒有待審核的報價")
            } else {
                ForEach(store.pendingQuotes) { pending in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(pending.quote.treatmentType)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(pending.quote.currency) \(pending.quote.estimatedCost)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }
                        Text(pending.clinicName)
                            .font(.caption)
                            .foregroundStyle(AppTheme.primary)
                        if !pending.quote.notes.isEmpty {
                            Text(pending.quote.notes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text("提交於 \(pending.submittedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        decisionButtons(
                            onApprove: {
                                Task {
                                    await store.approveSubmission(id: pending.id)
                                    if store.errorMessage == nil { Haptics.success() }
                                }
                            },
                            onReject: {
                                Task {
                                    await store.rejectSubmission(id: pending.id)
                                    if store.errorMessage == nil { Haptics.medium() }
                                }
                            }
                        )
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("待審核報價")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 舉報處理

struct AdminReportsView: View {
    @ObservedObject private var store = ModerationStore.shared

    private var sortedReports: [Report] {
        store.reports.sorted { lhs, rhs in
            if (lhs.status == .pending) != (rhs.status == .pending) {
                return lhs.status == .pending
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    var body: some View {
        List {
            if store.reports.isEmpty {
                emptyRow("目前沒有舉報")
            } else {
                ForEach(sortedReports) { report in
                    let canonicalTarget = store.canonicalTarget(for: report)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(report.targetType.label, systemImage: report.targetType.systemImage)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            statusChip(report.status)
                        }
                        if let canonicalTarget {
                            Text(canonicalTarget.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                            Text(canonicalTarget.details)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("內容 ID：\(canonicalTarget.id)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        } else {
                            Label("找不到原始內容；不可執行下架", systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.warning)
                        }
                        Text("原因：\(report.reason)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(report.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        if report.status == .pending {
                            decisionButtons(
                                approveTitle: "下架內容",
                                approveIcon: "eye.slash",
                                approveDisabled: canonicalTarget == nil,
                                rejectTitle: "駁回",
                                rejectIcon: "xmark",
                                onApprove: {
                                    Task {
                                        await store.resolveReport(id: report.id, takeDown: true)
                                        if store.errorMessage == nil { Haptics.success() }
                                    }
                                },
                                onReject: {
                                    Task {
                                        await store.resolveReport(id: report.id, takeDown: false)
                                        if store.errorMessage == nil { Haptics.medium() }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("舉報處理")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statusChip(_ status: ModerationStatus) -> some View {
        let tint: Color = switch status {
        case .pending: AppTheme.warning
        case .approved: .red
        case .rejected: .secondary
        }
        let label: LocalizedStringKey = switch status {
        case .pending: "待處理"
        case .approved: "已下架"
        case .rejected: "已駁回"
        }
        return Text(label).appChip(tint: tint, isFilled: status == .pending)
    }
}

// MARK: - 共用元件

private func decisionButtons(
    approveTitle: LocalizedStringKey = "批准",
    approveIcon: String = "checkmark",
    approveDisabled: Bool = false,
    rejectTitle: LocalizedStringKey = "拒絕",
    rejectIcon: String = "xmark",
    onApprove: @escaping () -> Void,
    onReject: @escaping () -> Void
) -> some View {
    HStack(spacing: 10) {
        Button(action: onApprove) {
            Label(approveTitle, systemImage: approveIcon)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .tint(AppTheme.primary)
        .disabled(approveDisabled)

        Button(role: .destructive, action: onReject) {
            Label(rejectTitle, systemImage: rejectIcon)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
    }
    .padding(.top, 4)
}

@ViewBuilder
private func emptyRow(_ message: LocalizedStringKey) -> some View {
    HStack {
        Spacer()
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 24)
        Spacer()
    }
    .listRowBackground(Color.clear)
}

#Preview {
    NavigationStack {
        AdminPortalView()
    }
}
