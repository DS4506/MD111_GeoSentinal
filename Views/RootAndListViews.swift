
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

// MARK: - Region List + Editor
struct RegionListView: View {
    @EnvironmentObject var vm: GeoVM
    @State private var showingAdd = false
    @State private var draft = GeoRegion(name: "New Place", latitude: 0, longitude: 0, radius: 200)

    var body: some View {
        NavigationView {
            List {
                ForEach(vm.regions) { r in
                    NavigationLink(
                        destination: RegionEditView(region: r) { updated in
                            if let idx = vm.regions.firstIndex(where: { $0.id == updated.id }) {
                                vm.regions[idx] = updated
                                vm.save()
                            }
                        }
                    ) {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(r.name).font(.headline)
                                if let p = vm.presence[r.id]?.presence {
                                    Text(p.rawValue.capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.15))
                                        .cornerRadius(4)
                                }
                            }
                            Text("Lat \(r.latitude), Lon \(r.longitude), \(Int(r.radius)) m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { idx in
                    for i in idx { vm.removeRegion(id: vm.regions[i].id) }
                }
            }
            .navigationTitle("Regions")
            // Use the older, universally supported toolbar initializer to avoid
            // “Trailing closure passed to parameter of type 'Visibility' …” and “Cannot find 'label' in scope”.
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAdd = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                NavigationView {
                    RegionEditView(region: draft) { newR in
                        vm.addRegion(newR)
                        draft = GeoRegion(name: "New Place", latitude: 0, longitude: 0, radius: 200)
                    }
                    .navigationTitle("New Region")
                }
            }
        }
    }
}

struct RegionEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State var region: GeoRegion
    var onSave: (GeoRegion) -> Void

    var body: some View {
        Form {
            Section(header: Text("Basics")) {
                TextField("Name", text: $region.name)
                Toggle("Enabled", isOn: $region.enabled)
                Stepper("Radius: \(Int(region.radius)) m", value: $region.radius, in: 50...1000, step: 10)
                Toggle("Notify on Entry", isOn: $region.notifyOnEntry)
                Toggle("Notify on Exit", isOn: $region.notifyOnExit)
            }
            Section(header: Text("Location")) {
                HStack {
                    Text("Lat")
                    TextField("Lat", value: $region.latitude, format: .number)
                        .keyboardType(.decimalPad)
                }
                HStack {
                    Text("Lon")
                    TextField("Lon", value: $region.longitude, format: .number)
                        .keyboardType(.decimalPad)
                }
            }
        }
        .navigationTitle("Edit Region")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { onSave(region); dismiss() }
            }
        }
    }
}
