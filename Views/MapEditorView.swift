
import SwiftUI
import MapKit

// iOS 15 friendly SwiftUI Map using coordinateRegion binding.
struct MapEditorView: View {
    @EnvironmentObject var vm: GeoVM

    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431),
        span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
    )

    var body: some View {
        VStack {
            Map(coordinateRegion: $mapRegion, annotationItems: vm.regions.filter { $0.enabled }) { r in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: r.latitude, longitude: r.longitude)) {
                    ZStack {
                        Circle().fill(Color.blue.opacity(0.2)).frame(width: 14, height: 14)
                        Circle().strokeBorder(Color.blue, lineWidth: 2).frame(width: 14, height: 14)
                    }
                    .overlay(
                        Text(r.name)
                            .font(.caption2)
                            .padding(4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(4)
                            .offset(y: -18)
                    )
                }
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Auth: \(vm.authStatusDescription)").font(.caption)
                    Text("Monitored: \(vm.regions.filter{$0.enabled}.count) • Mode: \(vm.settings.batteryMode.title)").font(.caption2)
                }
                .padding(8)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .padding()
            }

            HStack {
                Button {
                    vm.toggleBatteryMode()
                } label: {
                    Label(vm.settings.batteryMode.title,
                          systemImage: vm.settings.batteryMode == .saver ? "leaf" : "target")
                }
                Spacer()
                Button("Upgrade to Always") { vm.upgradeToAlways() }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .navigationTitle("Map")
        .onAppear {
            if let first = vm.regions.first {
                mapRegion.center = CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)
            }
        }
    }
}
