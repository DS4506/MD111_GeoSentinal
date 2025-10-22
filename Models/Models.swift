
import Foundation
import CoreLocation

struct GeoRegion: Identifiable, Codable, Equatable {
    var id: UUID = .init()
    var name: String
    var latitude: Double
    var longitude: Double
    var radius: Double
    var notifyOnEntry: Bool = true
    var notifyOnExit: Bool = true
    var enabled: Bool = true
}

enum BatteryMode: String, Codable, CaseIterable, Identifiable {
    case highFidelity
    case saver

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highFidelity: return "High Fidelity"
        case .saver: return "Saver"
        }
    }
}

struct GeoSettings: Codable, Equatable {
    var dwellSeconds: Int = 30
    var exitDebounceSeconds: Int = 20
    var batteryMode: BatteryMode = .highFidelity
    var maxMonitored: Int = 20
}

enum RegionPresence: String, Codable {
    case inside, outside, unknown
}

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
