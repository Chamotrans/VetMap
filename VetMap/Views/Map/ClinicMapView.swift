import SwiftUI
import MapKit
import UIKit

struct ClinicMapView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = MapViewModel()
    @State private var locationService = LocationService()
    @State private var clinicForDetail: VetClinic?
    @State private var shouldFocusOnUserLocation = false
    @State private var isShowingLocationSettingsAlert = false

    var body: some View {
        ZStack {
            Map(position: $viewModel.cameraPosition, selection: $viewModel.selectedClinicID) {
                UserAnnotation()

                ForEach(viewModel.mappableClinics) { clinic in
                    if let coordinate = clinic.mapCoordinate {
                        Annotation(coordinate: coordinate) {
                            Image(systemName: "cross.case.fill")
                                .foregroundStyle(
                                    clinic.isOpen(at: viewModel.availabilityNow)
                                        ? Color.green
                                        : AppTheme.primary
                                )
                        } label: {
                            Text(
                                [clinic.name, clinic.availabilityLabel(at: viewModel.availabilityNow)]
                                    .compactMap { $0 }
                                    .joined(separator: "・")
                            )
                        }
                        .tint(AppTheme.primary)
                        .tag(clinic.id)
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea()
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            topOverlay
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            clinicCarousel
                .padding(.bottom, 10)
        }
        .onAppear {
            viewModel.loadClinics()
            // Reading the current status does not show a system prompt.
            locationService.refreshAuthorizationStatus()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            locationService.refreshAuthorizationStatus()
        }
        .onChange(of: locationService.currentLocation) { _, location in
            viewModel.updateContextualLocation(location)
            guard shouldFocusOnUserLocation, let location else { return }
            shouldFocusOnUserLocation = false
            viewModel.focusOnUserLocation(location)
        }
        .onChange(of: locationService.locationRequestFailed) { _, failed in
            if failed {
                shouldFocusOnUserLocation = false
            }
        }
        .onChange(of: locationService.authorizationStatus) { _, _ in
            if locationService.requiresSettingsRecovery {
                shouldFocusOnUserLocation = false
            }
        }
        .sheet(item: $clinicForDetail) { clinic in
            ClinicDetailView(clinic: clinic)
        }
        .alert("需要定位權限", isPresented: $isShowingLocationSettingsAlert) {
            Button("取消", role: .cancel) {}
            Button("開啟設定") {
                openLocationSettings()
            }
        } message: {
            Text(locationSettingsRecoveryMessage)
        }
    }

    private var topOverlay: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("附近獸醫")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)

                    Text(resultCountText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    focusOnUserLocation()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: AppTheme.cardRadius))
                .tint(AppTheme.primary)
                .accessibilityLabel("定位到目前位置")
                .accessibilityHint(locationButtonAccessibilityHint)
            }

            if locationService.requiresSettingsRecovery {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Label(locationSettingsRecoveryMessage, systemImage: "location.slash.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 4)

                    Button("開啟設定") {
                        openLocationSettings()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: AppTheme.compactRadius))
                    .tint(AppTheme.primary)
                    .accessibilityHint("前往系統設定更改 VetMap 定位權限")
                }
            } else if locationService.locationRequestFailed {
                Label("暫時無法取得位置，請稍後再試", systemImage: "location.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let pendingLocationMessage {
                Label(pendingLocationMessage, systemImage: "mappin.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(pendingLocationMessage)
            }

            ClinicSearchField(text: $viewModel.filter.query, placeholder: "搜尋診所、地址、服務")
            urgentCareControl
            ClinicFilterControls(filter: $viewModel.filter)
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .liquidGlass(cornerRadius: AppTheme.cardRadius)
    }

    private var resultCountText: String {
        if viewModel.isUrgentMode {
            return "急需排序 \(viewModel.filteredClinics.count) / \(viewModel.directoryClinics.count) 間・地圖 \(viewModel.mappableClinics.count) 個標記"
        }

        if viewModel.filter.isActive {
            return "目錄 \(viewModel.filteredClinics.count) / \(viewModel.directoryClinics.count) 間・地圖 \(viewModel.mappableClinics.count) 個標記"
        }

        return "目錄 \(viewModel.directoryClinics.count) 間・地圖 \(viewModel.mappableClinics.count) 個標記"
    }

    private var pendingLocationMessage: String? {
        let count = viewModel.pendingLocationCount
        guard count > 0 else { return nil }
        return "\(count) 間診所位置待確認，仍可在下方目錄查看詳情"
    }

    private var urgentCareControl: some View {
        Button {
            let wasUrgent = viewModel.isUrgentMode
            viewModel.toggleUrgentMode()
            if !wasUrgent {
                focusOnUserLocation()
            }
        } label: {
            Label(
                viewModel.isUrgentMode ? "結束急需模式" : "急需睇獸醫",
                systemImage: viewModel.isUrgentMode ? "xmark.circle.fill" : "cross.case.fill"
            )
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity, minHeight: 46)
            .foregroundStyle(viewModel.isUrgentMode ? Color.white : AppTheme.primary)
            .background(
                viewModel.isUrgentMode ? AppTheme.warning : AppTheme.primary.opacity(0.10),
                in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
            )
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: AppTheme.cardRadius))
        .tint(viewModel.isUrgentMode ? AppTheme.warning : AppTheme.primary)
        .accessibilityLabel(viewModel.isUrgentMode ? "急需模式已啟用，按兩下結束" : "急需睇獸醫")
        .accessibilityValue(viewModel.isUrgentMode ? "已啟用" : "未啟用")
        .accessibilityHint(viewModel.isUrgentMode ? "結束急需排序並回復一般目錄次序" : "優先排序 24 小時、營業中及夜診診所；未提供工時的診所仍會保留")
        .accessibilityAddTraits(viewModel.isUrgentMode ? .isSelected : [])
    }

    @ViewBuilder
    private var clinicCarousel: some View {
        if viewModel.isLoading && viewModel.clinics.isEmpty {
            ProgressView("正在載入診所資料")
                .frame(maxWidth: .infinity)
                .padding(20)
                .liquidGlass(cornerRadius: AppTheme.cardRadius)
                .padding(.horizontal, 16)
                .frame(height: 132)
        } else if viewModel.filteredClinics.isEmpty {
            mapEmptyState
                .padding(.horizontal, 16)
                .frame(height: 132)
        } else {
            GeometryReader { proxy in
                let cardWidth = min(max(proxy.size.width - 40, 280), 360)
                let carouselInset = max((proxy.size.width - cardWidth) / 2, 16)

                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 10) {
                            ForEach(viewModel.filteredClinics) { clinic in
                                ClinicRowView(
                                    clinic: clinic,
                                    currentLocation: locationService.currentLocation,
                                    availabilityDate: viewModel.availabilityNow,
                                    isSelected: viewModel.selectedClinicID == clinic.id,
                                    isUrgentMode: viewModel.isUrgentMode,
                                    onCall: {
                                        call(clinic)
                                    },
                                    onNavigate: {
                                        navigate(to: clinic)
                                    },
                                    onOpenDetails: {
                                        clinicForDetail = clinic
                                    }
                                )
                                .frame(width: cardWidth)
                                .id(clinic.id)
                                .onTapGesture {
                                    focusOnClinic(clinic)
                                }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityAction {
                                    focusOnClinic(clinic)
                                }
                            }
                        }
                        .padding(.horizontal, carouselInset)
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .onAppear {
                        scrollToSelectedClinic(
                            viewModel.selectedClinicID,
                            using: scrollProxy
                        )
                    }
                    .onChange(of: viewModel.selectedClinicID) { _, clinicID in
                        scrollToSelectedClinic(clinicID, using: scrollProxy)
                    }
                }
            }
            .frame(height: viewModel.isUrgentMode ? 208 : 164)
        }
    }

    private func scrollToSelectedClinic(
        _ clinicID: String?,
        using proxy: ScrollViewProxy
    ) {
        guard
            let clinicID,
            viewModel.filteredClinics.contains(where: { $0.id == clinicID })
        else {
            return
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            proxy.scrollTo(clinicID, anchor: .center)
        }
    }

    private func focusOnClinic(_ clinic: VetClinic) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            viewModel.focus(on: clinic)
        }
    }

    private var mapEmptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.headline)
                .foregroundStyle(AppTheme.primary)
                .frame(width: 44, height: 44)
                .background(AppTheme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Group {
                    if viewModel.networkError != nil {
                        Text("無法載入診所資料")
                    } else if viewModel.clinics.isEmpty {
                        Text("暫未有已審核診所")
                    } else {
                        Text("沒有符合條件")
                    }
                }
                .font(.subheadline.weight(.semibold))

                Group {
                    if viewModel.networkError != nil {
                        Text("請檢查網絡連線後重試")
                    } else if viewModel.clinics.isEmpty {
                        Text("請到「診所」分頁提交資料")
                    } else {
                        Text(viewModel.filter.activeDescription)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }

            Spacer()

            if viewModel.networkError != nil {
                Button {
                    viewModel.retryLoad()
                } label: {
                    Text("重試")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: AppTheme.cardRadius))
                .tint(AppTheme.primary)
            } else if viewModel.filter.isActive {
                Button {
                    viewModel.clearFilters()
                } label: {
                    Text("清除")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: AppTheme.cardRadius))
                .tint(AppTheme.primary)
            }
        }
        .padding(14)
        .liquidGlass(cornerRadius: AppTheme.cardRadius)
    }

    private func focusOnUserLocation() {
        shouldFocusOnUserLocation = true

        switch locationService.requestLocationFromButton() {
        case .requestedPermission:
            break
        case .requestedLocation:
            // Recenter immediately when a cached fix exists, then apply the
            // fresh one-shot result when CLLocationManager returns it.
            if let location = locationService.currentLocation {
                viewModel.updateContextualLocation(location)
                viewModel.focusOnUserLocation(location)
            }
        case .requiresSettings:
            shouldFocusOnUserLocation = false
            isShowingLocationSettingsAlert = true
        }
    }

    private var locationSettingsRecoveryMessage: String {
        if locationService.authorizationStatus == .restricted {
            return "此裝置限制了定位服務，請在「設定」檢查定位服務或裝置限制。"
        }

        return "定位權限已關閉，請在「設定」允許 VetMap 於使用 App 期間取用位置。"
    }

    private var locationButtonAccessibilityHint: String {
        if locationService.requiresSettingsRecovery {
            return "顯示前往系統設定的選項"
        }

        if locationService.canUseLocation {
            return "取得最新位置並將地圖移到附近"
        }

        return "請求使用位置，以顯示附近診所"
    }

    private func openLocationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        openURL(url)
    }

    private func call(_ clinic: VetClinic) {
        guard let phone = callablePhone(for: clinic), let url = URL(string: "tel:\(phone)") else {
            return
        }
        openURL(url)
    }

    private func navigate(to clinic: VetClinic) {
        guard let coordinate = clinic.mapCoordinate else { return }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = clinic.name
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func callablePhone(for clinic: VetClinic) -> String? {
        guard let firstNumber = clinic.phone
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { "/,;|".contains($0) })
            .first
        else {
            return nil
        }

        let normalized = firstNumber.filter { $0.isNumber || $0 == "+" }
        return normalized.isEmpty ? nil : normalized
    }
}

#Preview {
    ClinicMapView()
}
