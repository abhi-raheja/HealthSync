import Foundation
import UserNotifications

class FastingManager {
    static let shared = FastingManager()
    
    private let userDefaults = UserDefaults.standard
    private let fastingWindowKey = "currentFastingWindow"
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // MARK: - Fasting Window Management
    
    func getCurrentFastingWindow() -> HealthData.FastingWindow? {
        guard let data = userDefaults.data(forKey: fastingWindowKey) else { return nil }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try? decoder.decode(HealthData.FastingWindow.self, from: data)
    }
    
    func setFastingWindow(_ window: HealthData.FastingWindow) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let encoded = try? encoder.encode(window) {
            userDefaults.set(encoded, forKey: fastingWindowKey)
            scheduleNotifications(for: window)
        }
    }
    
    func startFast(duration: TimeInterval) -> HealthData.FastingWindow {
        let now = Date()
        let endTime = now.addingTimeInterval(duration)
        
        let window = HealthData.FastingWindow(
            startTime: now,
            endTime: endTime,
            targetDuration: duration,
            actualDuration: nil,
            completed: false
        )
        
        setFastingWindow(window)
        return window
    }
    
    func endFast() -> HealthData.FastingWindow? {
        guard var window = getCurrentFastingWindow(), !window.completed else {
            return nil
        }
        
        let now = Date()
        let actualDuration = now.timeIntervalSince(window.startTime)
        
        window.actualDuration = actualDuration
        window.completed = true
        
        setFastingWindow(window)
        cancelNotifications()
        
        return window
    }
    
    // MARK: - Time Calculations
    
    func timeRemaining(for window: HealthData.FastingWindow) -> TimeInterval {
        guard !window.completed else { return 0 }
        
        let now = Date()
        return max(0, window.endTime.timeIntervalSince(now))
    }
    
    func formattedTimeRemaining(for window: HealthData.FastingWindow) -> String {
        let remaining = timeRemaining(for: window)
        
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    func isInFastingWindow(_ window: HealthData.FastingWindow) -> Bool {
        guard !window.completed else { return false }
        
        let now = Date()
        return now >= window.startTime && now <= window.endTime
    }
    
    func progressPercentage(for window: HealthData.FastingWindow) -> Double {
        guard !window.completed else { return 1.0 }
        
        let totalDuration = window.targetDuration
        let elapsed = Date().timeIntervalSince(window.startTime)
        
        return min(1.0, max(0.0, elapsed / totalDuration))
    }
    
    // MARK: - Notifications
    
    private func scheduleNotifications(for window: HealthData.FastingWindow) {
        cancelNotifications()
        
        // Request notification permissions if needed
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
            guard granted else { return }
            
            self.scheduleStartNotification(for: window)
            self.scheduleHalfwayNotification(for: window)
            self.scheduleEndNotification(for: window)
        }
    }
    
    private func scheduleStartNotification(for window: HealthData.FastingWindow) {
        let content = UNMutableNotificationContent()
        content.title = "Fasting Started"
        content.body = "Your fasting period has begun. It will end at \(formatTime(window.endTime))."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "fasting.start", content: content, trigger: trigger)
        
        notificationCenter.add(request)
    }
    
    private func scheduleHalfwayNotification(for window: HealthData.FastingWindow) {
        let content = UNMutableNotificationContent()
        content.title = "Halfway There!"
        content.body = "You're halfway through your fast. Keep going!"
        content.sound = .default
        
        let halfwayPoint = window.startTime.addingTimeInterval(window.targetDuration / 2)
        let timeUntilHalfway = max(1, halfwayPoint.timeIntervalSinceNow)
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeUntilHalfway, repeats: false)
        let request = UNNotificationRequest(identifier: "fasting.halfway", content: content, trigger: trigger)
        
        notificationCenter.add(request)
    }
    
    private func scheduleEndNotification(for window: HealthData.FastingWindow) {
        let content = UNMutableNotificationContent()
        content.title = "Fasting Complete!"
        content.body = "Congratulations! You've completed your fasting window."
        content.sound = .default
        
        let timeUntilEnd = max(1, window.endTime.timeIntervalSinceNow)
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeUntilEnd, repeats: false)
        let request = UNNotificationRequest(identifier: "fasting.end", content: content, trigger: trigger)
        
        notificationCenter.add(request)
    }
    
    private func cancelNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}