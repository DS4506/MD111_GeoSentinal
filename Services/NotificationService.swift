import Foundation
import UserNotifications

enum NotifCategory: String {
    case geofence = "GEOFENCE_EVENT"
}

enum NotifAction: String {
    case snooze15 = "SNOOZE_15"
    case done = "MARK_DONE"
}

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func register() async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        if !granted { print("Notifications not granted") }
        let actions = [
            UNNotificationAction(identifier: NotifAction.snooze15.rawValue, title: "Snooze 15m"),
            UNNotificationAction(identifier: NotifAction.done.rawValue, title: "Done", options: [.foreground])
        ]
        let category = UNNotificationCategory(identifier: NotifCategory.geofence.rawValue, actions: actions, intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    func postGeofence(title: String, body: String, userInfo: [AnyHashable: Any]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = NotifCategory.geofence.rawValue
        content.userInfo = userInfo

        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    func handleAction(response: UNNotificationResponse) {
        let id = response.actionIdentifier
        guard let regionID = response.notification.request.content.userInfo["regionID"] as? String else { return }
        switch id {
        case NotifAction.snooze15.rawValue:
            NotificationCenter.default.post(name: .gsSnooze15, object: regionID)
        case NotifAction.done.rawValue:
            NotificationCenter.default.post(name: .gsDone, object: regionID)
        default: break
        }
    }
}

extension Notification.Name {
    static let gsSnooze15 = Notification.Name("gs_snooze_15")
    static let gsDone     = Notification.Name("gs_done")
}
