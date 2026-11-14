import Foundation
import UserNotifications

/// Posts a system notification (used when the result could not be inserted and was put on the clipboard).
@MainActor
protocol UserNotifying: AnyObject {
    func notify(title: String, body: String)
}

@MainActor
final class SystemUserNotifier: NSObject, UserNotifying, UNUserNotificationCenterDelegate {
    private var didSetUp = false

    func notify(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        if !didSetUp {
            didSetUp = true
            center.delegate = self
        }
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return } // denied: the overlay still shows the result
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request)
        }
    }

    // Accessory (menu bar) apps count as foreground while the overlay is up: still show the banner.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
