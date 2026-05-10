import Foundation
import UserNotifications

/// Manages local notifications for daily practice reminders.
final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    /// Request notification permission
    func requestPermission(completion: @escaping (Bool) -> Void = { _ in }) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    /// Schedule daily practice reminder at the given hour/minute
    func scheduleDailyReminder(hour: Int = 19, minute: Int = 0) {
        cancelAll()

        let content = UNMutableNotificationContent()
        content.title = "二胡识谱"
        content.body = "今天练琴了吗？"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "dailyPracticeReminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Check if today is the first practice of the day
    var isFirstPracticeToday: Bool {
        let lastPracticeDate = UserDefaults.standard.object(forKey: "lastPracticeDate") as? Date ?? .distantPast
        return !Calendar.current.isDate(lastPracticeDate, inSameDayAs: Date())
    }

    /// Mark that the user has practiced today
    func markPracticedToday() {
        UserDefaults.standard.set(Date(), forKey: "lastPracticeDate")
    }

    /// Cancel all scheduled notifications
    func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["dailyPracticeReminder"]
        )
    }

    /// Check if notifications are enabled
    var isNotificationEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "notificationEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "notificationEnabled") }
    }

    /// Get/Set reminder time
    var reminderHour: Int {
        get { UserDefaults.standard.integer(forKey: "reminderHour").nonZero(19) }
        set { UserDefaults.standard.set(newValue, forKey: "reminderHour") }
    }

    var reminderMinute: Int {
        get { UserDefaults.standard.integer(forKey: "reminderMinute") }
        set { UserDefaults.standard.set(newValue, forKey: "reminderMinute") }
    }

    /// Get practice date set for calendar view
    var practiceDates: Set<Date> {
        get {
            guard let dates = UserDefaults.standard.array(forKey: "practiceDates") as? [TimeInterval] else {
                return []
            }
            return Set(dates.map { Date(timeIntervalSince1970: $0) })
        }
        set {
            let intervals = newValue.map { $0.timeIntervalSince1970 }
            UserDefaults.standard.set(intervals, forKey: "practiceDates")
        }
    }

    /// Record a practice date
    func recordPracticeDate() {
        var dates = practiceDates
        dates.insert(Calendar.current.startOfDay(for: Date()))
        practiceDates = dates
        markPracticedToday()
    }
}

private extension Int {
    func nonZero(_ value: Int) -> Int {
        self == 0 ? value : self
    }
}
