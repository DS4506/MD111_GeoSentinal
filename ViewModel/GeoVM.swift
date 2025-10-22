
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

    private var timers: [UUID: Task<Void, Never>] = [:]       // dwell timers
    private var exitTimers: [UUID: Task<Void, Never>] = [:]   // exit debounce timers
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

    // MARK: - Bootstrap
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

    // MARK: - Persistence
    func save() {
        Persistence.save(regions, key: StoreKeys.regions)
        Persistence.save(settings, key: StoreKeys.settings)
        Persistence.save(presence, key: StoreKeys.runtime)
        Persistence.save(logs, key: StoreKeys.logs)
        log("Saved.")
        Task { await updateMonitoringMode() }
    }

    // MARK: - Logging
    func log(_ message: String) {
        logs.insert(LogEntry(message: message), at: 0)
    }

    // MARK: - Region editing helpers
    func addRegion(_ region: GeoRegion) {
        regions.append(region)
        save()
    }

    func removeRegion(id: UUID) {
        regions.removeAll { $0.id == id }
        timers[id]?.cancel()
        timers[id] = nil
        exitTimers[id]?.cancel()
        exitTimers[id] = nil
        presence[id] = nil
        save()
    }

    func clampRadius(_ r: Double) -> CLLocationDistance {
        let minR = 50.0
        let maxR = 1000.0
        return max(minR, min(maxR, r))
    }

    // MARK: - Battery
    func toggleBatteryMode() {
        settings.batteryMode = (settings.batteryMode == .saver) ? .highFidelity : .saver
        save()
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

    // MARK: - Snooze
    func snooze(regionID: UUID, minutes: Int) {
        var rt = presence[regionID, default: RegionRuntimeState()]
        rt.snoozedUntil = Calendar.current.date(byAdding: .minute, value: minutes, to: Date())
        presence[regionID] = rt
        save()
        log("Snoozed \(regionID) for \(minutes)m.")
    }

    private func isSnoozed(_ id: UUID) -> Bool {
        if let until = presence[id]?.snoozedUntil {
            return until > Date()
        }
        return false
    }

    // MARK: - Confirmed transitions
    private func confirmEnter(_ id: UUID) {
        var rt = presence[id, default: RegionRuntimeState()]
        rt.lastConfirmedEnter = Date()
        rt.presence = .inside
        presence[id] = rt
        save()

        if let region = regions.first(where: { $0.id == id }) {
            NotificationService.shared.scheduleRegionNotification(
                regionID: id,
                title: "Arrived: \(region.name)",
                body: "You entered \(region.name)"
            )
        }
        log("ENTER confirmed for \(id).")
    }

    private func confirmExit(_ id: UUID) {
        var rt = presence[id, default: RegionRuntimeState()]
        rt.lastConfirmedExit = Date()
        rt.presence = .outside
        presence[id] = rt
        save()

        if let region = regions.first(where: { $0.id == id }) {
            NotificationService.shared.scheduleRegionNotification(
                regionID: id,
                title: "Left: \(region.name)",
                body: "You exited \(region.name)"
            )
        }
        log("EXIT confirmed for \(id).")
    }

    // MARK: - Raw events and timers
    private func startDwellTimer(for id: UUID) {
        timers[id]?.cancel()
        let seconds = max(1, settings.dwellSeconds)
        timers[id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            guard let self = self, !Task.isCancelled else { return }

            // If an exit debounce is running, entering cancels it
            self.exitTimers[id]?.cancel()
            self.exitTimers[id] = nil

            self.confirmEnter(id)
            self.timers[id] = nil
        }
    }

    private func startExitDebounce(for id: UUID) {
        exitTimers[id]?.cancel()
        let seconds = max(1, settings.exitDebounceSeconds)
        exitTimers[id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            guard let self = self, !Task.isCancelled else { return }
            self.confirmExit(id)
            self.exitTimers[id] = nil
        }
    }
}

// MARK: - LocationServiceDelegate
extension GeoVM: LocationServiceDelegate {
    // Auth change handling
    func didChangeAuth(status: CLAuthorizationStatus, precise: Bool) {
        preciseEnabled = precise

        let text: String
        switch status {
        case .notDetermined: text = "Not Determined"
        case .restricted:    text = "Restricted"
        case .denied:        text = "Denied"
        case .authorizedWhenInUse: text = "When In Use"
        case .authorizedAlways:    text = "Always"
        @unknown default:    text = "Unknown"
        }
        authStatusDescription = "\(text) • Precise: \(precise ? "On" : "Off")"
        log("Auth changed. \(authStatusDescription)")
    }

    // Raw enter
    func didEnter(region: CLRegion) {
        guard let id = UUID(uuidString: region.identifier) else { return }
        if isSnoozed(id) { log("ENTER ignored for \(id). Snoozed."); return }

        var rt = presence[id, default: RegionRuntimeState()]
        rt.lastEnterRaw = Date()
        presence[id] = rt
        save()

        // Start a dwell timer of `settings.dwellSeconds`.
        startDwellTimer(for: id)
        log("RAW ENTER for \(id). Dwell \(settings.dwellSeconds)s started.")
    }

    // Raw exit
    func didExit(region: CLRegion) {
        guard let id = UUID(uuidString: region.identifier) else { return }
        if isSnoozed(id) { log("EXIT ignored for \(id). Snoozed."); return }

        var rt = presence[id, default: RegionRuntimeState()]
        rt.lastExitRaw = Date()
        presence[id] = rt
        save()

        // Cancel any pending dwell timer, then start exit debounce
        timers[id]?.cancel()
        timers[id] = nil

        // Start a debounce timer of settings.exitDebounceSeconds
        startExitDebounce(for: id)
        log("RAW EXIT for \(id). Debounce \(settings.exitDebounceSeconds)s started.")
    }

    // Visits
    func didVisit(_ visit: CLVisit) {
        log("Visit received. Arrival: \(visit.arrivalDate), Departure: \(visit.departureDate)")
    }

    // Significant changes
    func didUpdateSignificant(_ location: CLLocation) {
        log("Significant location update @ \(location.coordinate.latitude), \(location.coordinate.longitude)")
        // In Saver mode you could re-center your monitored set based on distance moved.
    }

    // Errors
    func didFail(_ error: Error) {
        log("Location error: \(error.localizedDescription)")
    }

    // State queries
    func didDetermineState(_ state: CLRegionState, for region: CLRegion) {
        guard let id = UUID(uuidString: region.identifier) else {
            log("State for unknown region id \(region.identifier)")
            return
        }

        var rt = presence[id, default: RegionRuntimeState()]
        switch state {
        case .inside:
            rt.presence = .inside
        case .outside:
            rt.presence = .outside
        case .unknown:
            rt.presence = .unknown
        @unknown default:
            rt.presence = .unknown
        }
        presence[id] = rt
        save()
        log("State determined for \(id): \(rt.presence.rawValue)")
    }
}
