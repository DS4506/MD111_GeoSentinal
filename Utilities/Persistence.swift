import Foundation
import CoreLocation

enum StoreKeys {
    static let regions = "gs_regions_v1"
    static let settings = "gs_settings_v1"
    static let runtime  = "gs_runtime_v1"
    static let logs     = "gs_logs_v1"
}

struct Persistence {
    static func save<T: Codable>(_ value: T, key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            UserDefaults.standard.set(data, forKey: key)
        } catch { print("Persist encode error: \(error)") }
    }
    static func load<T: Codable>(_ type: T.Type, key: String, default value: T) -> T {
        guard let data = UserDefaults.standard.data(forKey: key) else { return value }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { print("Persist decode error: \(error)"); return value }
    }
}
