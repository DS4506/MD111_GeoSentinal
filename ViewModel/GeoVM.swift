import Foundation
import CoreLocation
import Combine

@MainActor
final class GeoVM: NSObject, ObservableObject {
    @Published var regions: [GeoRegion] = []
    @Published var settings = GeoSettings()
    @Published var authStatusDescription: String = "Unknown"
    @Published var preciseEnabled: Bool = true
    @Published var logs: [LogEntry] = []
    @Published var presence: [UUID: RegionRuntimeState] = [:]

    private var timers: [UUID: Task<Void, Never>] = [:]
    private var exitTimers: [UUID: Task<Void, Never>] = [:]
    private var cancellables: Set<AnyCancellable> = []

    private let location = LocationService.shared

    override init() {
        super.init()
        location.delegate = self
        NotificationCenter.default.addObserver(forName: .gsSnooze15, object: nil, queue: .main) { [weak self] n in
            guard let idStr = n.object as? String, let uuid = UUID(uuidString: idStr) else { return }
            self?.snooze(regionID: uuid, minutes: 15)
        }
        NotificationCenter.default.addObserver(forName: .gsDone, object: nil, queue: .main) { [weak self] n in
            guard let idStr = n.object as? String, let uuid = UUID(uuidString: idStr) else { return }
            self?.log("DONE tapped for region \(uuid).")
        }
    }

    func bootstrap() async {
        regions = Persistence.load([GeoRegion].self, key: StoreKeys.regions, default: [])
        settings = Persistence.load(GeoSettings.self, key: StoreKeys.settings, default: GeoSettings())
        presence = Persistence.load([UUID: RegionRuntimeState].self, key: StoreKeys.runtime, default: [:])

        await updateMonitoringMode()
        log("Bootstrap complete. Regions: \(regions.count). Mode: \(settings.batteryMode.title).")
        requestAuthIfNeeded()
    }

    func requestAuthIfNeeded() {
        location.requestWhenInUse()
    }

    func upgradeToAlways() {
        location.requestAlways()
    }

    func save() {
        Persistence.save(regions, key: StoreKeys.regions)
        Persistence.save(settings, key: StoreKeys.settings)
        Persistence.save(presence, key: StoreKeys.runtime)
    }

    // MARK: - Region CRUD
    func addRegion(_ r: GeoRegion) {
        regions.append(r)
        presence[r.id] = RegionRuntimeState()
        save()
        Task { await updateMonitoringMode() }
        log("Added region: \(r.name) (\(Int(r.radius)) m).")
    }

    func updateRegion(_ r: GeoRegion) {
        guard let idx = regions.firstIndex(where: { $0.id == r.id }) else { return }
        regions[idx] = r
        save()
        Task { await updateMonitoringMode() }
        log("Updated region: \(r.name).")
    }

    func deleteRegion(_ id: UUID) {
        if let idx = regions.firstIndex(where: { $0.id == id }) {
            let r = regions.remove(at: idx)
            presence[id] = nil
            save()
            Task { await updateMonitoringMode() }
            log("Deleted region: \(r.name).")
        }
    }

    func toggleEnabled(_ id: UUID) {
        guard let idx = regions.firstIndex(where: { $0.id == id }) else { return }
        regions[idx].enabled.toggle()
        save()
        Task { await updateMonitoringMode() }
        log("Toggled \(regions[idx].name) to \(regions[idx].enabled ? "enabled" : "disabled").")
    }

    func toggleBatteryMode() {
        settings.batteryMode = settings.batteryMode == .saver ? .highFidelity : .saver
        save()
        Task { await updateMonitoringMode() }
        log("Battery mode: \(settings.batteryMode.title).")
    }

    // MARK: - Monitoring Strategy
    func updateMonitoringMode() async {
        // Stop all first
        for r in location.monitoredRegions() {
            if let c = r as? CLCircularRegion { location.stopMonitoring(region: c) }
        }
        location.stopSignificant()
        location.stopVisits()

        // Determine which regions to monitor (≤20)
        let enabled = regions.filter { $0.enabled }
        let capped = Array(enabled.prefix(min(settings.maxMonitored, 20)))
        for r in capped {
            let region = CLCircularRegion(center: CLLocationCoordinate2D(latitude: r.latitude, longitude: r.longitude),
                                          radius: clampRadius(r.radius),
                                          identifier: r.id.uuidString)
            region.notifyOnEntry = r.notifyOnEntry
            region.notifyOnExit = r.notifyOnExit
            location.startMonitoring(region: region)
        }

        switch settings.batteryMode {
        case .saver:
            location.startSignificant()
            location.startVisits()
        case .highFidelity:
            break
        }
    }

    private func clampRadius(_ rad: Double) -> Double {
        if rad < 50 {
            log("Warning: radius \(Int(rad))m is small—GPS jitter may cause noise. Clamped to 50 m.")
            return 50
        }
        if rad > 2000 {
            log("Warning: radius \(Int(rad))m exceeds 2000—clamped to 2000 m.")
            return 2000
        }
        return rad
    }
    
    func snooze(regionID: UUID, minutes: Int) {
        var st = state(for: regionID)
        st.snoozedUntil = Calendar.current.date(byAdding: .minute, value: minutes, to: Date())
        setState(st, for: regionID)
        log("Snoozed \(regionID) for \(minutes)m.")
        
    }
    func log(_msg: String) {
        log.insert(LogEntry(message: msg), at: 0)
        Persistence.save(logs, key: StoreKeys.logs)
    }

    // MARK: - Event Handling
    private func state(for id: UUID) -> RegionRuntimeState {
        presence[id] ?? RegionRuntimeState()
    }
    private func setState(_ s: RegionRuntimeState, for id: UUID) {
        presence[id] = s
        save()
    }

    private func isSnoozed(_ id: UUID) -> Bool {
        if let until = presence[id]?.snoozedUntil { return until > Date() }
        return false
    }

    func handleEnterRaw(id: UUID) {
// TODO: Start a dwell timer of `settings.dwellSeconds`.
// Record a RAW ENTER timestamp in `presence[id]`.
// After the delay, call `confirmEnter(id:)` **iff** still inside / not snoozed.
log("TODO: RAW ENTER received for \(id). Start dwell …")

}
    func handleExitRaw(id: UUID) {
        //TODO: Start a debounce timer of settings.debounceSecounds
        //Record a RAW EXIT timestamp in presence[id]
        // After the delay, call confirmExit(id:)**iff** still inside/ not snoozed
        log("TODO: RAW EXIT received for \(id). Start debounce …")
    }

// MARK: - LocationServiceDelegate
extension GeoVM: LocationServiceDelegate {
    func didChangeAuth(status: CLAuthorizationStatus, precise: Bool) {
    preciseEnabled = precise
    // TODO: Reflect `status` in `authStatusDescription` and log changes.
    log("TODO: Auth changed. Precise=\(precise)")
}

func didEnter(region: CLRegion) {
    // TODO: Parse UUID from region.identifier and call handleEnterRaw(id:)
    log("TODO: didEnterRegion fired.")
}

func didExit(region: CLRegion) {
    // TODO: Parse UUID from region.identifier and call handleExitRaw(id:)
    log("TODO: didExitRegion fired.")
}

func didVisit(_ visit: CLVisit) {
    // Optional: Reconcile state using visits in Saver mode
    log("TODO: didVisit: arrival/dep available.")
}

func didUpdateSignificant(_ location: CLLocation) {
    // Optional: In Saver mode, re-center monitored set if the user moved far
    log("TODO: Significant location change received.")
}

func didFail(_ error: Error) {
    log("TODO: Location error: \(error.localizedDescription)")
}

func didDetermineState(_ state: CLRegionState, for region: CLRegion) {
    // TODO: Update presence[id] based on state (.inside/.outside/.unknown)
    log("TODO: didDetermineState for region.")
}

}
