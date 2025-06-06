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
    
    // New HealthKit-related properties
    @Published var todayActivity: HealthData.ActivitySummary?
    @Published var recentWorkouts: [HealthData.WorkoutSession] = []
    @Published var lastNightSleep: HealthData.SleepData?
    @Published var healthMetrics: HealthData.HealthMetrics?
    @Published var isHealthKitAuthorized: Bool = false
    
    // MARK: - Services
    private let whoopService = WhoopService.shared
    private let healthKitManager = HealthKitManager.shared
    private let fastingManager = FastingManager.shared
    private let coreDataManager = CoreDataManager.shared
    private var fastingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        // Perform one-time migration from UserDefaults to CoreData
        migrateDataIfNeeded()
        
        setupHealthKitAuthorization()
        loadUserProfile()
        setupFastingTimer()
        startDataSync()
        
        // Set up notification observer for HealthKit data updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHealthDataUpdate),
            name: .newHealthDataAvailable,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        fastingTimer?.invalidate()
        fastingTimer = nil
        
        // Clean up HealthKit observers
        healthKitManager.cleanup()
    }
    
    @objc private func handleHealthDataUpdate() {
        // Refresh health data when notification is received
        fetchHealthKitData()
    }
    
    private func migrateDataIfNeeded() {
        // Check if we've already migrated
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "hasPerformedCoreDataMigration") {
            coreDataManager.migrateFromUserDefaults()
            defaults.set(true, forKey: "hasPerformedCoreDataMigration")
        }
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
        healthKitManager.requestAuthorization { [weak self] success, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isHealthKitAuthorized = success
            }
            
            if success {
                print("HealthKit authorization successful")
                self.fetchHealthKitData()
                self.healthKitManager.enableBackgroundUpdates()
            } else {
                print("HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    private func loadUserProfile() {
        // First try to load from CoreData
        if let profile = coreDataManager.getUserProfile() {
            DispatchQueue.main.async {
                self.userProfile = profile
            }
            return
        }
        
        // Fallback to JSON file if CoreData is empty
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let url = Bundle.main.url(forResource: "UserProfile", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let profile = try? decoder.decode(HealthData.UserProfile.self, from: data) else {
            print("Failed to load user profile")
            return
        }
        
        // Save to CoreData for future use
        coreDataManager.saveUserProfile(profile: profile)
        
        DispatchQueue.main.async {
            self.userProfile = profile
        }
    }
    
    // MARK: - Data Sync
    private func startDataSync() {
        // Load initial data from CoreData
        loadStoredData()
        
        // Set up timer for periodic data sync
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.syncAllData()
            }
            .store(in: &cancellables)
    }
    
    private func loadStoredData() {
        // Load WHOOP metrics
        if let metrics = coreDataManager.getLatestWhoopMetrics() {
            DispatchQueue.main.async {
                self.whoopMetrics = metrics
            }
        }
        
        // Load supplements
        let supplements = coreDataManager.getTodaySupplements()
        DispatchQueue.main.async {
            self.todaySupplements = supplements
        }
        
        // Load insights
        let insights = coreDataManager.getCoachingInsights()
        DispatchQueue.main.async {
            self.aiInsights = insights
        }
        
        // Load workouts
        let workouts = coreDataManager.getRecentWorkouts()
        DispatchQueue.main.async {
            self.recentWorkouts = workouts
        }
    }
    
    private func syncAllData() {
        Task {
            do {
                // Fetch WHOOP metrics
                let metrics = try await whoopService.fetchDailyMetrics()
                DispatchQueue.main.async {
                    self.whoopMetrics = metrics
                }
                
                // Save to CoreData
                coreDataManager.saveWhoopMetrics(metrics: metrics)
                
                // Fetch HealthKit data
                fetchHealthKitData()
                
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
    
    // MARK: - HealthKit Data Fetching
    private func fetchHealthKitData() {
        // Fetch all health data
        healthKitManager.fetchAllHealthData { [weak self] in
            self?.fetchActivityData()
            self?.fetchWorkoutsData()
            self?.fetchSleepData()
            self?.fetchHealthMetricsData()
        }
    }
    
    private func fetchActivityData() {
        healthKitManager.fetchTodayActivity { [weak self] activity in
            guard let self = self, let activity = activity else { return }
            
            DispatchQueue.main.async {
                self.todayActivity = activity
            }
            
            // Save to CoreData if needed
            // This would typically be implemented in the CoreDataManager
        }
    }
    
    private func fetchWorkoutsData() {
        healthKitManager.fetchRecentWorkouts { [weak self] workouts in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.recentWorkouts = workouts
            }
            
            // Save to CoreData
            for workout in workouts {
                self.coreDataManager.saveWorkoutSession(workout: workout)
            }
        }
    }
    
    private func fetchSleepData() {
        healthKitManager.fetchLastNightSleep { [weak self] sleepData in
            guard let self = self, let sleepData = sleepData else { return }
            
            DispatchQueue.main.async {
                self.lastNightSleep = sleepData
            }
            
            // Save to CoreData if needed
            // This would typically be implemented in the CoreDataManager
        }
    }
    
    private func fetchHealthMetricsData() {
        healthKitManager.fetchHealthMetrics { [weak self] metrics in
            guard let self = self, let metrics = metrics else { return }
            
            DispatchQueue.main.async {
                self.healthMetrics = metrics
            }
            
            // Save to CoreData if needed
            // This would typically be implemented in the CoreDataManager
        }
    }
    
    // MARK: - AI Insights
    private func generateAIInsights() async {
        // Collect all available data for insights
        let whoopData = whoopMetrics
        let activityData = todayActivity
        let sleepData = lastNightSleep
        
        var newInsights: [HealthData.CoachingInsight] = []
        
        // Generate insights based on WHOOP recovery if available
        if let metrics = whoopData, metrics.recovery < 33 {
            let insight = HealthData.CoachingInsight(
                date: Date(),
                type: "recovery",
                message: "Your recovery is low. Consider a light workout or active recovery today.",
                actionRequired: true,
                completed: nil
            )
            
            newInsights.append(insight)
        }
        
        // Generate insights based on sleep if available
        if let sleep = sleepData, sleep.quality < 70 {
            let insight = HealthData.CoachingInsight(
                date: Date(),
                type: "sleep",
                message: "Your sleep quality was below optimal. Focus on improving sleep hygiene tonight.",
                actionRequired: true,
                completed: nil
            )
            
            newInsights.append(insight)
        }
        
        // Generate insights based on activity if available
        if let activity = activityData, activity.steps < 5000 {
            let insight = HealthData.CoachingInsight(
                date: Date(),
                type: "activity",
                message: "You're not meeting your daily step goal. Take a short walk to increase activity.",
                actionRequired: true,
                completed: nil
            )
            
            newInsights.append(insight)
        }
        
        if !newInsights.isEmpty {
            // Save to CoreData
            coreDataManager.saveCoachingInsights(insights: newInsights)
            
            DispatchQueue.main.async {
                self.aiInsights = newInsights
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
    }
    
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
        
        // Save to CoreData
        coreDataManager.saveSupplementLogs(supplements: supplementLogs)
        
        DispatchQueue.main.async {
            self.todaySupplements = supplementLogs
        }
    }
    
    // MARK: - Profile Management
    func updateUserProfile(name: String, age: Int) {
        // Update the user profile
        let updatedProfile = HealthData.UserProfile(
            name: name,
            age: age,
            testDate: Date()
        )
        
        // Save to CoreData
        coreDataManager.updateUserProfile(profile: updatedProfile)
        
        DispatchQueue.main.async {
            self.userProfile = updatedProfile
        }
    }
    
    // MARK: - Public Health Data Methods
    
    /// Manually triggers a refresh of all health data
    func refreshHealthData() {
        fetchHealthKitData()
    }
    
    /// Returns formatted metrics for display
    func formattedHealthMetrics() -> [String: String] {
        var metrics: [String: String] = [:]
        
        // Activity metrics
        if let activity = todayActivity {
            metrics["steps"] = "\(activity.steps)"
            metrics["activeCalories"] = "\(Int(activity.activeEnergyBurned)) kcal"
            metrics["exerciseMinutes"] = "\(activity.exerciseMinutes) min"
        }
        
        // WHOOP metrics
        if let whoop = whoopMetrics {
            metrics["recovery"] = "\(Int(whoop.recovery))%"
            metrics["strain"] = String(format: "%.1f", whoop.strain)
            metrics["restingHR"] = "\(Int(whoop.restingHeartRate)) bpm"
            metrics["hrv"] = "\(Int(whoop.hrv)) ms"
        }
        
        // Sleep metrics
        if let sleep = lastNightSleep {
            let hours = Int(sleep.duration / 3600)
            let minutes = Int((sleep.duration.truncatingRemainder(dividingBy: 3600)) / 60)
            metrics["sleepDuration"] = "\(hours)h \(minutes)m"
            metrics["sleepQuality"] = "\(Int(sleep.quality))%"
        }
        
        return metrics
    }
}
