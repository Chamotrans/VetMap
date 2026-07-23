import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ClinicEntry {
        ClinicEntry(clinics: MockClinicRepository.hkClinics.prefix(3).map { .init(id: $0.id, name: $0.name, rating: $0.avgRating) })
    }

    func getSnapshot(in context: Context, completion: @escaping (ClinicEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClinicEntry>) -> Void) {
        let clinics = MockClinicRepository.hkClinics.prefix(3).map {
            WidgetClinic(id: $0.id, name: $0.name, rating: $0.avgRating)
        }
        let entry = ClinicEntry(clinics: clinics)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
        completion(timeline)
    }
}

struct WidgetClinic: Identifiable { let id: String; let name: String; let rating: Double }

struct ClinicEntry: TimelineEntry {
    let date: Date = Date()
    let clinics: [WidgetClinic]
}

struct VetMapWidgetEntryView: View {
    var entry: ClinicEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "pawprint.fill").foregroundStyle(.teal)
                Text("VetMap 社群").font(.headline)
                Spacer()
            }

            if entry.clinics.isEmpty {
                Text("開啟 VetMap 投稿診所資料")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(entry.clinics) { clinic in
                    HStack {
                        Text(clinic.name).font(.caption).lineLimit(1)
                        Spacer()
                        Label(String(format: "%.1f", clinic.rating), systemImage: "star.fill")
                            .font(.caption2).foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding()
    }
}

struct VetMapWidget: Widget {
    let kind = "VetMapWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            VetMapWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("VetMap 社群")
        .description("快速開啟獸醫診所社群")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
