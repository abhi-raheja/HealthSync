import Foundation
import HealthKit
import CoreData

struct HealthData: Codable {
    // User Profile
    struct UserProfile: Codable {
        var name: String
        var age: Int
        var testDate: Date
    }
    
    // Blood Markers
    struct BloodMarkers: Codable {
        var fastingGlucose: Double
        var hba1c: Double
        var insulinFasting: Double
        var insulinPostPrandial: Double
        var triglycerides: Double
        var vldl: Double
        var nonHdlCholesterol: Double
    }
    
    // WHOOP Data
    struct WhoopMetrics: Codable {
        var strain: Double
        var recovery: Double
        var hrv: Double
        var restingHeartRate: Double
        var sleepPerformance: Double
        var respiratoryRate: Double
    }
    
    // Fasting Data
    struct FastingWindow: Codable {
        var startTime: Date
        var endTime: Date
        var targetDuration: TimeInterval
        var actualDuration: TimeInterval?
        var completed: Bool
    }
    
    // Workout Data
    struct WorkoutSession: Codable {
        var type: String
        var startTime: Date
        var endTime: Date
        var strain: Double
        var heartRateData: [Double]
        var caloriesBurned: Double
        var notes: String?
    }
    
    // Supplement Tracking
    struct SupplementLog: Codable {
        var name: String
        var dosage: String
        var timeToTake: Date
        var taken: Bool
        var notes: String?
    }
    
    // AI Coaching
    struct CoachingInsight: Codable {
        var date: Date
        var type: String
        var message: String
        var actionRequired: Bool
        var completed: Bool?
    }
}

// MARK: - HealthKit Authorization
class HealthKitManager {
    static let shared = HealthKitManager()
    let healthStore = HKHealthStore()
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, nil)
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.workoutType()
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            completion(success, error)
        }
    }
}
