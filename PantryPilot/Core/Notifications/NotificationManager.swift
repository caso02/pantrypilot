import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    @Published var isAuthorized = false

    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            AppLogger.notifications.info("Notification permission: \(granted)")
        } catch {
            AppLogger.notifications.error("Notification permission error: \(error.localizedDescription)")
        }
    }

    func scheduleExpiryNotification(for item: InventoryItem) {
        guard let expiryDate = item.estimatedExpiryDate else { return }

        let warningDate = Calendar.current.date(byAdding: .day, value: -1, to: expiryDate)!
        guard warningDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Bald ablaufend"
        content.body = "\(item.canonicalName) läuft morgen ab!"
        content.sound = .default
        content.categoryIdentifier = "EXPIRY_WARNING"

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour],
            from: warningDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "expiry-\(item.id.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                AppLogger.notifications.error("Schedule error: \(error.localizedDescription)")
            }
        }
    }

    func scheduleExpiryNotifications(for items: [InventoryItem]) {
        let expiring = items.filter { $0.estimatedExpiryDate != nil && !$0.isExpired }
        for item in expiring {
            scheduleExpiryNotification(for: item)
        }
    }

    func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
