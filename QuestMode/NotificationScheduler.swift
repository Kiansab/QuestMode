import Foundation
import UserNotifications

enum NotificationScheduler {

    private static let dailyQuestId = "questmode.daily.reminder"
    private static let streakRiskId = "questmode.streak.evening"

    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    /// Morning reminder that new quests are available (09:00 local).
    static func scheduleDailyQuestReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyQuestId])

        let content = UNMutableNotificationContent()
        content.title = "Daily quests are ready"
        content.body = "Open Quest Mode and pick your next real-life win."
        content.sound = .default

        var date = DateComponents()
        date.hour = 9
        date.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: dailyQuestId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// Optional evening nudge if streak > 0 (20:00 local). App refreshes this when progress changes.
    static func refreshStreakReminder(hasActiveStreak: Bool) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [streakRiskId])
        guard hasActiveStreak else { return }

        let content = UNMutableNotificationContent()
        content.title = "Keep your streak alive"
        content.body = "Complete at least one quest today to stay on your run."
        content.sound = .default

        var date = DateComponents()
        date.hour = 20
        date.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: streakRiskId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
