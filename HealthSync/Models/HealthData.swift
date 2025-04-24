import Foundation
import HealthKit
import CoreData

/// Namespace for various health data models used in the app
enum HealthData {
    
    /// Metrics from WHOOP integration
    struct WhoopMetrics {
        let strain: Double
        let recovery: Double
        let hrv: Double
        let restingHeartRate: Double
        let sleepPerformance: Double
        let respiratoryRate: Double
        
        /// Initialize with default values for previews
        static var preview: WhoopMetrics {
            return WhoopMetrics(
                strain: 12.3,
                recovery: 67.0,
                hrv: 58.0,
                restingHeartRate: 52.0,
                sleepPerformance: 85.0,
                respiratoryRate: 15.3
            )
        }
    }
    
    /// Workout session data from any source
    struct WorkoutSession {
        let type: String
        let startTime: Date
        let endTime: Date
        let strain: Double
        let heartRateData: [Int] // Array of heart rate values (average, max, etc.)
        let caloriesBurned: Double
        let notes: String?
        
        /// Initialize with default values for previews
        static var preview: WorkoutSession {
            return WorkoutSession(
                type: "Running",
                startTime: Date().addingTimeInterval(-3600), // 1 hour ago
                endTime: Date(),
                strain: 9.5,
                heartRateData: [142, 175], // Average, max
                caloriesBurned: 450,
                notes: "Felt good, pushed hard on the last mile"
            )
        }
    }
    
    /// Fasting session data
    struct FastingSession {
        let startTime: Date
        let endTime: Date?
        let targetDuration: TimeInterval
        let protocol: FastingProtocol
        let notes: String?
        
        var isActive: Bool {
            return endTime == nil
        }
        
        var currentDuration: TimeInterval {
            return Date().timeIntervalSince(startTime)
        }
        
        var progress: Double {
            return min(currentDuration / targetDuration, 1.0)
        }
        
        /// Initialize with default values for previews
        static var preview: FastingSession {
            return FastingSession(
                startTime: Date().addingTimeInterval(-60 * 60 * 8), // 8 hours ago
                endTime: nil,
                targetDuration: 60 * 60 * 16, // 16 hours
                protocol: .intermittent16_8,
                notes: nil
            )
        }
        
        /// Initialize a completed fasting session for previews
        static var previewCompleted: FastingSession {
            let start = Date().addingTimeInterval(-60 * 60 * 20) // 20 hours ago
            return FastingSession(
                startTime: start,
                endTime: start.addingTimeInterval(60 * 60 * 18), // 18 hours later
                targetDuration: 60 * 60 * 16, // 16 hours
                protocol: .intermittent16_8,
                notes: "Felt good, exceeded target by 2 hours"
            )
        }
    }
    
    /// Fasting protocol types
    enum FastingProtocol: String, CaseIterable, Identifiable {
        case intermittent16_8 = "16:8 Intermittent"
        case intermittent18_6 = "18:6 Intermittent"
        case omad = "One Meal A Day (OMAD)"
        case alternateDay = "Alternate Day Fast"
        case extendedFast = "Extended Fast"
        case custom = "Custom"
        
        var id: String { self.rawValue }
        
        var description: String {
            switch self {
            case .intermittent16_8:
                return "16 hours fasting, 8 hours eating window"
            case .intermittent18_6:
                return "18 hours fasting, 6 hours eating window"
            case .omad:
                return "23 hours fasting, 1 hour eating window"
            case .alternateDay:
                return "36 hours fasting, 12 hours eating window"
            case .extendedFast:
                return "48+ hours fasting"
            case .custom:
                return "Custom fasting schedule"
            }
        }
        
        var targetHours: Double {
            switch self {
            case .intermittent16_8: return 16
            case .intermittent18_6: return 18
            case .omad: return 23
            case .alternateDay: return 36
            case .extendedFast: return 48
            case .custom: return 0 // To be set by user
            }
        }
    }
    
    /// Supplement data
    struct Supplement {
        let name: String
        let dose: String
        let frequency: SupplementFrequency
        let timeOfDay: [TimeOfDay]
        let withFood: Bool
        let notes: String?
        
        /// Initialize with default values for previews
        static var preview: Supplement {
            return Supplement(
                name: "Vitamin D3",
                dose: "2000 IU",
                frequency: .daily,
                timeOfDay: [.morning],
                withFood: true,
                notes: "Take with breakfast"
            )
        }
    }
    
    /// Supplement frequency
    enum SupplementFrequency: String, CaseIterable, Identifiable {
        case daily = "Daily"
        case twiceDaily = "Twice Daily"
        case everyOtherDay = "Every Other Day"
        case weekly = "Weekly"
        case asNeeded = "As Needed"
        
        var id: String { self.rawValue }
    }
    
    /// Time of day for supplements
    enum TimeOfDay: String, CaseIterable, Identifiable {
        case morning = "Morning"
        case afternoon = "Afternoon"
        case evening = "Evening"
        case beforeBed = "Before Bed"
        
        var id: String { self.rawValue }
    }
    
    /// Health insight generated by the app
    struct Insight {
        let title: String
        let description: String
        let type: InsightType
        let source: String
        let date: Date
        let actionable: Bool
        let action: String?
        
        /// Initialize with default values for previews
        static var preview: Insight {
            return Insight(
                title: "Recovery Trending Down",
                description: "Your recovery scores have been trending downward over the past 7 days. Consider focusing on sleep quality and reducing training intensity.",
                type: .recovery,
                source: "WHOOP",
                date: Date(),
                actionable: true,
                action: "View recovery recommendations"
            )
        }
    }
    
    /// Type of health insight
    enum InsightType: String, CaseIterable, Identifiable {
        case recovery = "Recovery"
        case sleep = "Sleep"
        case workout = "Workout"
        case nutrition = "Nutrition"
        case stress = "Stress"
        case fasting = "Fasting"
        
        var id: String { self.rawValue }
        
        var color: String {
            switch self {
            case .recovery: return "green"
            case .sleep: return "indigo"
            case .workout: return "orange"
            case .nutrition: return "purple"
            case .stress: return "red"
            case .fasting: return "blue"
            }
        }
        
        var icon: String {
            switch self {
            case .recovery: return "heart.fill"
            case .sleep: return "bed.double.fill"
            case .workout: return "figure.run"
            case .nutrition: return "fork.knife"
            case .stress: return "brain.head.profile"
            case .fasting: return "timer"
            }
        }
    }
    
    /// User sleep data
    struct SleepData {
        let date: Date
        let duration: TimeInterval
        let quality: Double
        let stages: SleepStages
        let heartRate: [Double]
        let respiratoryRate: Double
        
        /// Initialize with default values for previews
        static var preview: SleepData {
            return SleepData(
                date: Date().addingTimeInterval(-28800), // 8 hours ago
                duration: 28800, // 8 hours
                quality: 85.0,
                stages: SleepStages(
                    deep: 5400,    // 1.5 hours
                    rem: 7200,     // 2 hours
                    light: 14400,  // 4 hours
                    awake: 1800    // 0.5 hours
                ),
                heartRate: [55, 68, 52], // min, avg, max during sleep
                respiratoryRate: 15.2
            )
        }
    }
    
    /// Sleep stages data
    struct SleepStages {
        let deep: TimeInterval
        let rem: TimeInterval
        let light: TimeInterval
        let awake: TimeInterval
        
        var total: TimeInterval {
            return deep + rem + light + awake
        }
        
        var deepPercentage: Double {
            return deep / total * 100
        }
        
        var remPercentage: Double {
            return rem / total * 100
        }
        
        var lightPercentage: Double {
            return light / total * 100
        }
        
        var awakePercentage: Double {
            return awake / total * 100
        }
    }
    
    /// Activity summary data from HealthKit
    struct ActivitySummary {
        let date: Date
        let activeEnergyBurned: Double
        let exerciseMinutes: Int
        let standHours: Int
        let steps: Int
        let distance: Double
        let flightsClimbed: Int
        
        /// Initialize with default values for previews
        static var preview: ActivitySummary {
            return ActivitySummary(
                date: Date(),
                activeEnergyBurned: 320,
                exerciseMinutes: 45,
                standHours: 10,
                steps: 8500,
                distance: 5.2,
                flightsClimbed: 12
            )
        }
    }
    
    /// Health metrics data
    struct HealthMetrics {
        let date: Date
        let bodyMass: Double?
        let bodyFatPercentage: Double?
        let restingHeartRate: Double?
        let heartRateVariability: Double?
        let bloodPressureSystolic: Double?
        let bloodPressureDiastolic: Double?
        let bloodOxygen: Double?
        let respiratoryRate: Double?
        
        /// Initialize with default values for previews
        static var preview: HealthMetrics {
            return HealthMetrics(
                date: Date(),
                bodyMass: 75.5,
                bodyFatPercentage: 15.2,
                restingHeartRate: 55.0,
                heartRateVariability: 68.0,
                bloodPressureSystolic: 120.0,
                bloodPressureDiastolic: 80.0,
                bloodOxygen: 98.0,
                respiratoryRate: 15.0
            )
        }
    }
}

// MARK: - HealthKit Authorization
class HealthKitManager {
    static let shared = HealthKitManager()
    let healthStore = HKHealthStore()
    private let healthKitService = HealthKitService.shared
    
    /// Request authorization for accessing HealthKit data
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        Task {
            let success = await healthKitService.requestAuthorization()
            DispatchQueue.main.async {
                completion(success, nil)
            }
        }
    }
    
    /// Fetch all relevant health data in one call
    func fetchAllHealthData(completion: @escaping () -> Void) {
        Task {
            await healthKitService.fetchAllHealthData()
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    /// Fetch today's activity data
    func fetchTodayActivity(completion: @escaping (HealthData.ActivitySummary?) -> Void) {
        Task {
            let steps = await healthKitService.fetchTodaySteps()
            let activeEnergy = await healthKitService.fetchTodayActiveEnergy()
            
            // Additional metrics would be fetched here in a complete implementation
            let exerciseMinutes = 0
            let standHours = 0
            let distance = 0.0
            let flightsClimbed = 0
            
            let summary = HealthData.ActivitySummary(
                date: Date(),
                activeEnergyBurned: activeEnergy,
                exerciseMinutes: exerciseMinutes,
                standHours: standHours,
                steps: steps,
                distance: distance,
                flightsClimbed: flightsClimbed
            )
            
            DispatchQueue.main.async {
                completion(summary)
            }
        }
    }
    
    /// Fetch recent workouts from HealthKit
    func fetchRecentWorkouts(limit: Int = 10, completion: @escaping ([HealthData.WorkoutSession]) -> Void) {
        Task {
            let workouts = await healthKitService.fetchRecentWorkouts(limit: limit)
            DispatchQueue.main.async {
                completion(workouts)
            }
        }
    }
    
    /// Fetch last night's sleep data
    func fetchLastNightSleep(completion: @escaping (HealthData.SleepData?) -> Void) {
        Task {
            let sleepData = await healthKitService.fetchLastNightSleep()
            DispatchQueue.main.async {
                completion(sleepData)
            }
        }
    }
    
    /// Fetch recent health metrics
    func fetchHealthMetrics(completion: @escaping (HealthData.HealthMetrics?) -> Void) {
        Task {
            // This would ideally come from the HealthKitService
            // For now, we'll return a placeholder
            let placeholder = HealthData.HealthMetrics.preview
            DispatchQueue.main.async {
                completion(placeholder)
            }
        }
    }
    
    /// Enable background updates for key health metrics
    func enableBackgroundUpdates() {
        Task {
            // Enable background delivery for important metrics
            _ = await healthKitService.enableBackgroundDelivery(for: .heartRate, frequency: .hourly)
            _ = await healthKitService.enableBackgroundDelivery(for: .stepCount, frequency: .immediate)
            _ = await healthKitService.enableBackgroundDelivery(for: .activeEnergyBurned, frequency: .hourly)
            
            // Set up observers for key data types
            healthKitService.startObserving(quantityTypeIdentifier: .heartRate) {
                // Handle new heart rate data
                // This would typically dispatch a notification or update a view model
                NotificationCenter.default.post(name: .newHealthDataAvailable, object: nil)
            }
            
            healthKitService.startObserving(quantityTypeIdentifier: .stepCount) {
                // Handle new step count data
                NotificationCenter.default.post(name: .newHealthDataAvailable, object: nil)
            }
        }
    }
    
    /// Cleanup when app is terminating or going to background for extended period
    func cleanup() {
        healthKitService.stopAllBackgroundDelivery()
    }
}

// MARK: - Notification names
extension Notification.Name {
    static let newHealthDataAvailable = Notification.Name("newHealthDataAvailable")
}
