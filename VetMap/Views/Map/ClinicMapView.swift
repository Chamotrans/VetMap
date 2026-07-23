import SwiftUI
import MapKit

struct ClinicMapView: View {
    @State private var viewModel = MapViewModel()
    @State private var locationService = LocationService()
    @State private var clinicForDetail: VetClinic?
    @State private var shouldFocusOnUserLocation = false
    @State private var initialLocationApplied = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        ZStack {
            Map(position: $viewModel.cameraPosition, selection: $viewModel.selectedClinicID) {
                UserAnnotation()

                ForEach(viewModel.filteredClinics) { clinic in
                    Annotation(coordinate: clinic.mapCoordinate) {
                    Image(systemName: clinic.avgRating >= 4.5 ? "star.circle.fill" : "cross.case.fill")
                        .foregroundStyle(clinic.avgRating >= 4.5 ? .green : AppTheme.primary)
                } label: {
                    Text(clinic.name)
                }
                        .tint(clinic.verified ? AppTheme.primary : AppTheme.accent)
                        .tag(clinic.id)
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
            // 只在過咗 onboarding 先請求定位，避免權限對話框蓋住 onboarding
            // 截圖模式唔請求定位，避免權限彈窗蓋住自動截圖
            if hasSeenOnboarding && !AppLaunchFlags.isScreenshotMode {
                applyInitialLocation()
            }
        }
        .onChange(of: hasSeenOnboarding) { _, seen in
            if seen { applyInitialLocation() }
        }
        .onChange(of: locationService.currentLocation) { _, location in
            if !initialLocationApplied, let location {
                initialLocationApplied = true
                viewModel.focusOnUserLocation(location)
                return
            }
            guard shouldFocusOnUserLocation else { return }
            shouldFocusOnUserLocation = false
            viewModel.focusOnUserLocation(location)
        }
        .sheet(item: $clinicForDetail) { clinic in
            ClinicDetailView(clinic: clinic)
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
            }

            ClinicSearchField(text: $viewModel.filter.query, placeholder: "搜尋診所、地址、服務")
            ClinicFilterControls(filter: $viewModel.filter)
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .liquidGlass(cornerRadius: AppTheme.cardRadius)
    }

    private var resultCountText: String {
        if viewModel.filter.isActive {
            return "\(viewModel.filteredClinics.count) / \(viewModel.clinics.count) 間診所"
        }

        return "\(viewModel.clinics.count) 間診所"
    }

    @ViewBuilder
    private var clinicCarousel: some View {
        if viewModel.filteredClinics.isEmpty {
            mapEmptyState
                .padding(.horizontal, 16)
                .frame(height: 132)
        } else {
            GeometryReader { proxy in
                let cardWidth = min(max(proxy.size.width - 40, 280), 360)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(viewModel.filteredClinics) { clinic in
                            ClinicRowView(
                                clinic: clinic,
                                currentLocation: locationService.currentLocation,
                                isSelected: viewModel.selectedClinicID == clinic.id,
                                onOpenDetails: {
                                    clinicForDetail = clinic
                                }
                            )
                            .frame(width: cardWidth)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                    viewModel.focus(on: clinic)
                                }
                            }
                            .accessibilityAddTraits(.isButton)
                        }
                    }
                    .padding(.horizontal, 16)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
            }
            .frame(height: 164)
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
                Text("沒有符合條件")
                    .font(.subheadline.weight(.semibold))

                Text(viewModel.filter.activeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if viewModel.filter.isActive {
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

        if locationService.canUseLocation, locationService.currentLocation != nil {
            shouldFocusOnUserLocation = false
            viewModel.focusOnUserLocation(locationService.currentLocation)
            return
        }

        locationService.refreshLocation()
    }

    /// 開 App 自動移到當前位置（未授權則請求權限）
    private func applyInitialLocation() {
        guard !initialLocationApplied else { return }

        if locationService.canUseLocation, let location = locationService.currentLocation {
            initialLocationApplied = true
            viewModel.focusOnUserLocation(location)
        } else {
            // notDetermined → 請求權限；已授權但未有快取 → 請求一次定位
            // 授權/定位更新後由 onChange(currentLocation) 完成 focus
            locationService.requestPermission()
        }
    }
}

#Preview {
    ClinicMapView()
}
