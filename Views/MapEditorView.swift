import SwiftUI
import MapKit

struct MapEditorView: View {
    @EnvironmentObject var vm: GeoVM
    @State private var mapPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        VStack {
            Map(position: $mapPosition) {
                ForEach(vm.regions.filter { $0.enabled }) { r in
                    let coord = CLLocationCoordinate2D(latitude: r.latitude, longitude: r.longitude)
                    Annotation(r.name, coordinate: coord) {
                        ZStack {
                            Circle().fill(.blue.opacity(0.2)).frame(width: 14, height: 14)
                            Circle().strokeBorder(.blue, lineWidth: 2).frame(width: 14, height: 14)
                        }
                    }
                    MapCircle(center: coord, radius: r.radius).stroke(.blue, lineWidth: 1)
                }
                UserAnnotation()
            }
            .mapControls {
                MapUserLocationButton()
                MapPitchToggle()
                MapCompass()
                MapScaleView()
            }
            .onTapGesture { location in
                if case let .coordinate(coord) = location {
                    let new = GeoRegion(name: "Pin", latitude: coord.latitude, longitude: coord.longitude, radius: 200)
                    vm.addRegion(new)
                }
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auth: \(vm.authStatusDescription)")
                    Text("Precise: \(vm.preciseEnabled.description)")
                }
                .font(.caption)
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding()
            }

            HStack {
                Button {
                    vm.toggleBatteryMode()
                } label:{
                    Label(vm.settings.batteryMode.title, systemImage: vm.settings.batteryMode == .saver ? "leaf" : "target")
                }
                Spacer()
                Button("Upgrade to Always") { vm.upgradeToAlways() }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}
