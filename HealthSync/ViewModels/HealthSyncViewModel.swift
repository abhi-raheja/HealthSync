import Foundation
import SwiftUI
import Combine

class HealthSyncViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var userProfile: HealthData.UserProfile?
    @Published var whoopMetrics: HealthData.WhoopMetrics?
    @Published var currentFastingWindow: HealthData.FastingWindow?
    @Published var todaySupplements: [HealthData.SupplementLog] = []
    @Published var aiInsights: [HealthData.CoachingInsight] = []
    @Published var fastingProgress: Double = 0
    @Published var fastingTimeRemaining: String = "--:--:--"
    
    // MARK: - Services
    private let whoopService = WhoopService.shared
    private let healthKitManager = HealthKitManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
    setupHealthKitAuthorization()
    loadUserProfile()
    setupFastingTimer()  // Add this line
    startDataSync()
}
    private func setupFastingTimer() {

    // Check for existing fasting window
    if let window = fastingManager.getCurrentFastingWindow(), !window.completed {
        currentFastingWindow = window
        startFastingTimer()
    } else {
        updateFastingWindow()
    }
}

    private func startFastingTimer() {

    // Cancel any existing timer
    fastingTimer?.invalidate()
    
    // Create a new timer that fires every second
    fastingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
        self?.updateFastingTimerDisplay()
    }
}

    private func updateFastingTimerDisplay() {
    guard let window = currentFastingWindow else { return }
    
    DispatchQueue.main.async {
        self.fastingTimeRemaining = self.fastingManager.formattedTimeRemaining(for: window)
        self.fastingProgress = self.fastingManager.progressPercentage(for: window)
    }
}
    
    // MARK: - Setup Methods
    private func setupHealthKitAuthorization() {
        healthKitManager.requestAuthorization { success, error in
            if success {
                print("HealthKit authorization successful")
                self.fetchHealthKitData()
            } else {
                print("HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    private func loadUserProfile() {
        // Load user profile from JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let url = Bundle.main.url(forResource: "UserProfile", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let profile = try? decoder.decode(HealthData.UserProfile.self, from: data) else {
            print("Failed to load user profile")
            return
        }
        
        DispatchQueue.main.async {
            self.userProfile = profile
        }
    }
    
    // MARK: - Data Sync
    private func startDataSync() {
        // Set up timer for periodic data sync
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.syncAllData()
            }
            .store(in: &cancellables)
    }
    
    private func syncAllData() {
        Task {
            do {
                // Fetch WHOOP metrics
                let metrics = try await whoopService.fetchDailyMetrics()
                DispatchQueue.main.async {
                    self.whoopMetrics = metrics
                }
                
                // Generate AI insights based on new data
                await generateAIInsights()
                
                // Update fasting window if needed
                updateFastingWindow()
                
                // Check and update supplement schedule
                updateSupplementSchedule()
            } catch {
                print("Data sync failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - AI Insights
    private func generateAIInsights() async {
        guard let metrics = whoopMetrics else { return }
        
        // Example insight generation based on WHOOP metrics
        if metrics.recovery < 33 {
            let insight = HealthData.CoachingInsight(
                date: Date(),
                type: "recovery",
                message: "Your recovery is low. Consider a light workout or active recovery today.",
                actionRequired: true,
                completed: nil
            )
            
            DispatchQueue.main.async {
                self.aiInsights.append(insight)
            }
        }
    }
    
    // MARK: - Fasting Management
    func updateFastingWindow() {
        let calendar = Calendar.current
        let now = Date()
        
        // Default fasting window (16:8)
        var fastingStart = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now)!
        var fastingEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!

        if fastingEnd < fastingStart {
        fastingEnd = calendar.date(byAdding: .day, value: 1, to: fastingEnd)!
    }
        
        let window = HealthData.FastingWindow(
            startTime: fastingStart,
            endTime: fastingEnd,
            targetDuration: 16 * 3600,
            actualDuration: nil,
            completed: false
        )
        
        fastingManager.setFastingWindow(window)
        currentFastingWindow = window
        startFastingTimer()

        func startFasting(duration: TimeInterval = 16 * 3600) {
        let window = fastingManager.startFast(duration: duration)
        currentFastingWindow = window
        startFastingTimer()
}

        func endFasting() {
        if let updated = fastingManager.endFast() {
        currentFastingWindow = updated
        fastingTimer?.invalidate()
        fastingTimer = nil
    }
}
    
    // MARK: - Supplement Management
    private func updateSupplementSchedule() {
        // Create daily supplement schedule based on the lifestyle plan
        let supplements = [
            ("Vitamin D3", "7000 IU", 8),  // 8 AM
            ("Omega 3", "2000mg", 8),      // 8 AM
            ("ALA", "600mg", 12),          // 12 PM
            ("Curcumin", "1000mg", 19),    // 7 PM
            ("Magnesium", "400mg", 22)     // 10 PM
        ]
        
        let calendar = Calendar.current
        let now = Date()
        
        let supplementLogs = supplements.map { supplement in
            let (name, dosage, hour) = supplement
            let scheduleTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now)!
            
            return HealthData.SupplementLog(
                name: name,
                dosage: dosage,
                timeToTake: scheduleTime,
                taken: false,
                notes: nil
            )
        }
        
        DispatchQueue.main.async {
            self.todaySupplements = supplementLogs
        }
    }
    
    // MARK: - Health Data Management
    private func fetchHealthKitData() {
        // Implement HealthKit data fetching
    }
}
