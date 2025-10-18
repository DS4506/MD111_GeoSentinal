import SwiftUI
import MapKit

struct RootView: View {
    @EnvironmentObject var vm: GeoVM

    var body: some View {
        TabView {
            RegionListView()
                .tabItem { Label("Regions", systemImage: "mappin.and.ellipse") }
            MapEditorView()
                .tabItem { Label("Map", systemImage: "map.circle") }
            DebugConsoleView()
                .tabItem { Label("Debug", systemImage: "terminal") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

struct RegionListView: View {
    @EnvironmentObject var vm: GeoVM
    @State private var editing: GeoRegion? = nil

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.regions) { r in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(r.name).font(.headline)
                            Text("\(r.latitude, specifier: "%.5f"), \(r.longitude, specifier: "%.5f") • \(Int(r.radius)) m")
                                .font(.caption).foregroundStyle(.secondary)
                            if let state = vm.presence[r.id]?.presence {
                                Text(state.rawValue.capitalized).font(.caption2)
                            }
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { r.enabled },
                            set: { _ in vm.toggleEnabled(r.id) }
                        ))
                        .labelsHidden()
                        Button { editing = r } label { Image(systemName: "pencil") }
                            .buttonStyle(.borderless)
                    }
                }
                .onDelete { idx in
                    for i in idx { vm.deleteRegion(vm.regions[i].id) }
                }
            }
            .navigationTitle("GeoSentinel Pro")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { editing = GeoRegion(name: "New Fence", latitude: 32.5149, longitude: -117.0382, radius: 200) } label {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editing) { region in
                RegionEditorSheet(region: region) { updated in
                    if vm.regions.contains(where: { $0.id == updated.id }) { vm.updateRegion(updated) }
                    else { vm.addRegion(updated) }
                }
            }
        }
    }
}

struct RegionEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var region: GeoRegion
    var onSave: (GeoRegion) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $region.name)
                Stepper("Radius: \(Int(region.radius)) m", value: $region.radius, in: 50...2000, step: 25)
                Toggle("Notify on Entry", isOn: $region.notifyOnEntry)
                Toggle("Notify on Exit", isOn: $region.notifyOnExit)
                HStack {
                    Text("Lat"); TextField("Lat", value: $region.latitude, format: .number).keyboardType(.decimalPad)
                    Text("Lon"); TextField("Lon", value: $region.longitude, format: .number).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Edit Region")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(region); dismiss() } }
            }
        }
    }
}
