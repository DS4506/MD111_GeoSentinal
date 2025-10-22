
import SwiftUI
import UserNotifications

@main
struct GeoSentinelProApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var vm = GeoVM()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(vm)
                .onAppear {
                    Task { await vm.bootstrap() }
                }
        }
    }
}

// MARK: - AppDelegate
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // These two were reported as “no member” in your screenshot. They exist below in NotificationService.swift.
        NotificationService.shared.configureCategories()
        Task {
            _ = await NotificationService.shared.requestAuthorization()
        }
        return true
    }

    // Foreground presentation
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    // Action handling
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NotificationService.shared.handleAction(response: response)
        completionHandler()
    }
}
