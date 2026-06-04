import SwiftUI
import MapKit

struct ClinicMapView: View {
    @StateObject private var viewModel = MapViewModel()
    @StateObject private var locationService = LocationService()
    @State private var clinicForDetail: VetClinic?
    @State private var shouldFocusOnUserLocation = false

    var body: some View {
        ZStack {
            Map(position: $viewModel.cameraPosition, selection: $viewModel.selectedClinicID) {
                UserAnnotation()

                ForEach(viewModel.clinics) { clinic in
                    Marker(clinic.name, systemImage: "cross.case.fill", coordinate: clinic.mapCoordinate)
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
        }
        .onChange(of: locationService.currentLocation) { _, location in
            guard shouldFocusOnUserLocation else { return }
            shouldFocusOnUserLocation = false
            viewModel.focusOnUserLocation(location)
        }
        .sheet(item: $clinicForDetail) { clinic in
            ClinicDetailView(clinic: clinic)
        }
    }

    private var topOverlay: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("附近獸醫")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)

                Text("\(viewModel.clinics.count) 間診所")
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
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .stroke(.white.opacity(0.36), lineWidth: 1)
        )
    }

    private var clinicCarousel: some View {
        GeometryReader { proxy in
            let cardWidth = min(max(proxy.size.width - 40, 280), 360)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(viewModel.clinics) { clinic in
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

    private func focusOnUserLocation() {
        shouldFocusOnUserLocation = true

        if locationService.canUseLocation, locationService.currentLocation != nil {
            shouldFocusOnUserLocation = false
            viewModel.focusOnUserLocation(locationService.currentLocation)
            return
        }

        locationService.refreshLocation()
    }
}

#Preview {
    ClinicMapView()
}
