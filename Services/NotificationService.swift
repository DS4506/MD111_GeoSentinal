
import Foundation
import UserNotifications

enum NotifCategory: String { case geofence = "GEOFENCE_EVENT" }
enum NotifAction: String {
    case snooze15 = "SNOOZE_15"
    case done = "MARK_DONE"
}

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    // Exists for the call site in AppDelegate above
    func configureCategories() {
        let snooze = UNNotificationAction(
            identifier: NotifAction.snooze15.rawValue,
            title: "Snooze 15m",
            options: []
        )
        let done = UNNotificationAction(
            identifier: NotifAction.done.rawValue,
            title: "Done",
            options: [.foreground]
        )
        let cat = UNNotificationCategory(
            identifier: NotifCategory.geofence.rawValue,
            actions: [snooze, done],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([cat])
    }

    // Exists for the call site in AppDelegate above
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    cont.resume(returning: granted)
                }
        }
    }

    func scheduleRegionNotification(regionID: UUID, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = NotifCategory.geofence.rawValue
        content.userInfo = ["regionID": regionID.uuidString]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.6, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func handleAction(response: UNNotificationResponse) {
        let info = response.notification.request.content.userInfo
        let regionID = info["regionID"] as? String

        switch response.actionIdentifier {
        case NotifAction.snooze15.rawValue:
            NotificationCenter.default.post(name: .gsSnooze15, object: regionID)
        case NotifAction.done.rawValue:
            NotificationCenter.default.post(name: .gsDone, object: regionID)
        default:
            break
        }
    }
}

extension Notification.Name {
    static let gsSnooze15 = Notification.Name("gs_snooze_15")
    static let gsDone     = Notification.Name("gs_done")
}
