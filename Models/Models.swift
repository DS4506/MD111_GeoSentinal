import Foundation
import CoreLocation

struct GeoRegion: Identifiable, Codable, Equatable {
    var id: UUID = .init()
    var name: String
    var latitude: Double
    var longitude: Double
    var radius: Double    // meters
    var notifyOnEntry: Bool = true
    var notifyOnExit: Bool = true
    var enabled: Bool = true
}

enum BatteryMode: String, Codable, CaseIterable, Identifiable {
    case highFidelity, saver
    var id: String { rawValue }
    var title: String { self == .highFidelity ? "High fidelity" : "Battery saver" }
}

struct GeoSettings: Codable {
    var dwellSeconds: Int = 30
    var exitDebounceSeconds: Int = 20
    var batteryMode: BatteryMode = .saver
    var maxMonitored: Int = 10 // app-side cap (≤ 20 hard limit)
}

enum RegionPresence: String, Codable { case unknown, inside, outside }

struct RegionRuntimeState: Codable {
    var lastEnterRaw: Date? = nil
    var lastExitRaw: Date? = nil
    var lastConfirmedEnter: Date? = nil
    var lastConfirmedExit: Date? = nil
    var presence: RegionPresence = .unknown
    var snoozedUntil: Date? = nil
}

struct LogEntry: Identifiable, Codable {
    var id = UUID()
    var timestamp = Date()
    var message: String
}
