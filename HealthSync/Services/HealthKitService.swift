import Foundation
import HealthKit
import Combine

/// Service for interacting with HealthKit data
class HealthKitService {
    // MARK: - Singleton
    static let shared = HealthKitService()
    
    // MARK: - Properties
    private let healthStore = HKHealthStore()
    private let healthKitManager = HealthKitManager.shared
    
    // For background updates
    private var updateTimers = [String: Timer]()
    private var backgroundDeliveryTasks = [String: HKObserverQuery]()
    
    // Combine publishers
    @Published private(set) var isAuthorized = false
    @Published private(set) var todaySteps: Int = 0
    @Published private(set) var todayActiveEnergy: Double = 0
    @Published private(set) var recentWorkouts: [HealthData.WorkoutSession] = []
    @Published private(set) var heartRateData: [Double] = []
    @Published private(set) var sleepData: HealthData.SleepData?
    @Published private(set) var lastError: Error?
    
    // MARK: - Initialization
    private init() {
        checkAuthorization()
    }
    
    // MARK: - Authorization
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            self.isAuthorized = false
            return false
        }
        
        // Define the types we want to read
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.workoutType(),
            // Additional types for comprehensive health tracking
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!
        ]
        
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            
            self.isAuthorized = true
            return true
        } catch {
            self.lastError = error
            self.isAuthorized = false
            return false
        }
    }
    
    private func checkAuthorization() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let authorizationStatus = healthStore.authorizationStatus(for: heartRateType)
        
        self.isAuthorized = (authorizationStatus == .sharingAuthorized)
    }
    
    // MARK: - Data Fetching
    
    /// Fetches all health data from HealthKit
    func fetchAllHealthData() async {
        guard isAuthorized else {
            let authorized = await requestAuthorization()
            guard authorized else { return }
        }
        
        // Fetch all data in parallel
        async let stepsTask = fetchTodaySteps()
        async let activeEnergyTask = fetchTodayActiveEnergy()
        async let workoutsTask = fetchRecentWorkouts()
        async let heartRateTask = fetchRecentHeartRateData()
        async let sleepTask = fetchLastNightSleep()
        
        // Wait for all tasks to complete
        let (steps, activeEnergy, workouts, heartRate, sleep) = await (
            stepsTask,
            activeEnergyTask,
            workoutsTask,
            heartRateTask,
            sleepTask
        )
        
        // Update published properties on main thread
        DispatchQueue.main.async {
            self.todaySteps = steps
            self.todayActiveEnergy = activeEnergy
            self.recentWorkouts = workouts
            self.heartRateData = heartRate
            self.sleepData = sleep
        }
    }
    
    /// Fetches steps count for today
    func fetchTodaySteps() async -> Int {
        let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        do {
            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                let query = HKSampleQuery(
                    sampleType: stepsType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples ?? [])
                    }
                }
                
                healthStore.execute(query)
            }
            
            let quantitySamples = samples.compactMap { $0 as? HKQuantitySample }
            let totalSteps = quantitySamples.reduce(0) { $0 + $1.quantity.doubleValue(for: HKUnit.count()) }
            
            return Int(totalSteps)
        } catch {
            self.lastError = error
            return 0
        }
    }
    
    /// Fetches active energy burned for today
    func fetchTodayActiveEnergy() async -> Double {
        let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        do {
            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                let query = HKSampleQuery(
                    sampleType: activeEnergyType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples ?? [])
                    }
                }
                
                healthStore.execute(query)
            }
            
            let quantitySamples = samples.compactMap { $0 as? HKQuantitySample }
            let totalCalories = quantitySamples.reduce(0) { $0 + $1.quantity.doubleValue(for: HKUnit.kilocalorie()) }
            
            return totalCalories
        } catch {
            self.lastError = error
            return 0
        }
    }
    
    /// Fetches recent workouts
    func fetchRecentWorkouts(limit: Int = 10) async -> [HealthData.WorkoutSession] {
        let workoutType = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        do {
            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                let query = HKSampleQuery(
                    sampleType: workoutType,
                    predicate: nil,
                    limit: limit,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples ?? [])
                    }
                }
                
                healthStore.execute(query)
            }
            
            var workouts: [HealthData.WorkoutSession] = []
            
            for sample in samples {
                guard let workout = sample as? HKWorkout else { continue }
                
                // Get heart rate for this workout (simplified)
                let avgHeartRate = await fetchAverageHeartRate(for: workout)
                let maxHeartRate = await fetchMaxHeartRate(for: workout)
                
                let workoutSession = HealthData.WorkoutSession(
                    type: workout.workoutActivityType.name,
                    startTime: workout.startDate,
                    endTime: workout.endDate,
                    strain: calculateStrainFromWorkout(workout),
                    heartRateData: [Int(avgHeartRate), Int(maxHeartRate)],
                    caloriesBurned: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
                    notes: nil
                )
                
                workouts.append(workoutSession)
            }
            
            return workouts
        } catch {
            self.lastError = error
            return []
        }
    }
    
    /// Fetches recent heart rate data for the past day
    func fetchRecentHeartRateData() async -> [Double] {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        do {
            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                let query = HKSampleQuery(
                    sampleType: heartRateType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples ?? [])
                    }
                }
                
                healthStore.execute(query)
            }
            
            let heartRates = samples.compactMap { sample -> Double? in
                guard let heartRateSample = sample as? HKQuantitySample else { return nil }
                return heartRateSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
            }
            
            return heartRates
        } catch {
            self.lastError = error
            return []
        }
    }
    
    /// Fetches sleep data for the last night
    func fetchLastNightSleep() async -> HealthData.SleepData? {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        do {
            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
                let query = HKSampleQuery(
                    sampleType: sleepType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples ?? [])
                    }
                }
                
                healthStore.execute(query)
            }
            
            // Get sleep stages
            var asleepTime: TimeInterval = 0
            var deepSleepTime: TimeInterval = 0
            var remSleepTime: TimeInterval = 0
            var lightSleepTime: TimeInterval = 0
            var awakeDuringTime: TimeInterval = 0
            
            for sample in samples {
                guard let categorySample = sample as? HKCategorySample else { continue }
                let duration = categorySample.endDate.timeIntervalSince(categorySample.startDate)
                
                if #available(iOS 16.0, *) {
                    switch categorySample.value {
                    case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                        asleepTime += duration
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        deepSleepTime += duration
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        remSleepTime += duration
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                        lightSleepTime += duration
                    case HKCategoryValueSleepAnalysis.awake.rawValue:
                        awakeDuringTime += duration
                    default:
                        break
                    }
                } else {
                    // Older iOS versions have less detailed sleep stages
                    if categorySample.value == HKCategoryValueSleepAnalysis.asleep.rawValue {
                        asleepTime += duration
                    } else if categorySample.value == HKCategoryValueSleepAnalysis.awake.rawValue {
                        awakeDuringTime += duration
                    }
                }
            }
            
            // Handle older iOS versions where we don't have detailed sleep stages
            if deepSleepTime == 0 && remSleepTime == 0 && lightSleepTime == 0 {
                // Approximate sleep stages based on typical percentages
                deepSleepTime = asleepTime * 0.2  // ~20% deep sleep
                remSleepTime = asleepTime * 0.25  // ~25% REM sleep
                lightSleepTime = asleepTime * 0.55 // ~55% light sleep
            }
            
            // Get heart rate during sleep
            let heartRates = await fetchHeartRateDuringSleep(
                startDate: samples.first?.startDate ?? yesterday,
                endDate: samples.last?.endDate ?? now
            )
            
            let avgHeartRate = heartRates.isEmpty ? 0 : heartRates.reduce(0, +) / Double(heartRates.count)
            let minHeartRate = heartRates.min() ?? 0
            let maxHeartRate = heartRates.max() ?? 0
            
            // Get respiratory rate during sleep
            let respiratoryRate = await fetchRespiratoryRateDuringSleep(
                startDate: samples.first?.startDate ?? yesterday,
                endDate: samples.last?.endDate ?? now
            )
            
            // Calculate sleep quality (simplified model)
            let totalSleepTime = deepSleepTime + remSleepTime + lightSleepTime
            let quality = calculateSleepQuality(
                deepSleepPercentage: deepSleepTime / totalSleepTime,
                remSleepPercentage: remSleepTime / totalSleepTime,
                awakeTime: awakeDuringTime,
                totalTime: totalSleepTime + awakeDuringTime
            )
            
            return HealthData.SleepData(
                date: samples.first?.startDate ?? yesterday,
                duration: totalSleepTime,
                quality: quality,
                stages: HealthData.SleepStages(
                    deep: deepSleepTime,
                    rem: remSleepTime,
                    light: lightSleepTime,
                    awake: awakeDuringTime
                ),
                heartRate: [minHeartRate, avgHeartRate, maxHeartRate],
                respiratoryRate: respiratoryRate
            )
        } catch {
            self.lastError = error
            return nil
        }
    }
    
    // MARK: - Helper Methods
    private func fetchAverageHeartRate(for workout: HKWorkout) async -> Double {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        
        do {
            let heartRates = try await fetchQuantitySamples(for: heartRateType, predicate: predicate)
            let values = heartRates.map { $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())) }
            return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        } catch {
            return 0
        }
    }
    
    private func fetchMaxHeartRate(for workout: HKWorkout) async -> Double {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        
        do {
            let heartRates = try await fetchQuantitySamples(for: heartRateType, predicate: predicate)
            let values = heartRates.map { $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())) }
            return values.max() ?? 0
        } catch {
            return 0
        }
    }
    
    private func fetchHeartRateDuringSleep(startDate: Date, endDate: Date) async -> [Double] {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        do {
            let heartRates = try await fetchQuantitySamples(for: heartRateType, predicate: predicate)
            return heartRates.map { $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())) }
        } catch {
            return []
        }
    }
    
    private func fetchRespiratoryRateDuringSleep(startDate: Date, endDate: Date) async -> Double {
        let respiratoryRateType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        do {
            let samples = try await fetchQuantitySamples(for: respiratoryRateType, predicate: predicate)
            let values = samples.map { $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())) }
            return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        } catch {
            return 0
        }
    }
    
    private func fetchQuantitySamples(for quantityType: HKQuantityType, predicate: NSPredicate) async throws -> [HKQuantitySample] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let quantitySamples = samples?.compactMap { $0 as? HKQuantitySample } ?? []
                    continuation.resume(returning: quantitySamples)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func calculateStrainFromWorkout(_ workout: HKWorkout) -> Double {
        // Simplified strain calculation based on duration and calories
        // In a real app, this would be more sophisticated
        let durationMinutes = workout.endDate.timeIntervalSince(workout.startDate) / 60
        let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
        
        // Basic formula: higher values for longer/more intense workouts
        let strain = (durationMinutes * 0.1) + (calories * 0.02)
        
        // Cap strain between 0 and 21 (WHOOP-like scale)
        return min(max(strain, 0), 21)
    }
    
    private func calculateSleepQuality(
        deepSleepPercentage: Double,
        remSleepPercentage: Double,
        awakeTime: TimeInterval,
        totalTime: TimeInterval
    ) -> Double {
        // Simplified sleep quality score (0-100%)
        // Ideal: 20-25% deep sleep, 20-25% REM sleep, minimal awake time
        
        let deepSleepScore = min(deepSleepPercentage / 0.25, 1.0) * 0.4 // 40% of score
        let remSleepScore = min(remSleepPercentage / 0.25, 1.0) * 0.4 // 40% of score
        let awakeTimeScore = (1.0 - min(awakeTime / totalTime, 0.3) / 0.3) * 0.2 // 20% of score
        
        let qualityScore = (deepSleepScore + remSleepScore + awakeTimeScore) * 100
        return min(max(qualityScore, 0), 100) // Ensure within 0-100 range
    }
    
    // MARK: - Background Updates
    
    /// Set up background delivery for a specific data type
    func enableBackgroundDelivery(for quantityTypeIdentifier: HKQuantityTypeIdentifier, frequency: HKUpdateFrequency) async -> Bool {
        let quantityType = HKObjectType.quantityType(forIdentifier: quantityTypeIdentifier)!
        
        do {
            try await healthStore.enableBackgroundDelivery(for: quantityType, frequency: frequency)
            return true
        } catch {
            self.lastError = error
            return false
        }
    }
    
    /// Set up an observer query that gets notified when new data is available
    func startObserving(quantityTypeIdentifier: HKQuantityTypeIdentifier, updateHandler: @escaping () -> Void) {
        let quantityType = HKObjectType.quantityType(forIdentifier: quantityTypeIdentifier)!
        
        // Create an observer query
        let query = HKObserverQuery(sampleType: quantityType, predicate: nil) { [weak self] query, completionHandler, error in
            if let error = error {
                self?.lastError = error
            } else {
                updateHandler()
            }
            
            // Complete the background task
            completionHandler()
        }
        
        // Execute the query
        healthStore.execute(query)
        
        // Store the query for later reference
        let queryId = quantityTypeIdentifier.rawValue
        backgroundDeliveryTasks[queryId] = query
    }
    
    /// Stop observing a specific data type
    func stopObserving(quantityTypeIdentifier: HKQuantityTypeIdentifier) {
        let queryId = quantityTypeIdentifier.rawValue
        
        if let query = backgroundDeliveryTasks[queryId] {
            healthStore.stop(query)
            backgroundDeliveryTasks.removeValue(forKey: queryId)
        }
    }
    
    // MARK: - Cleanup
    func stopAllBackgroundDelivery() {
        // Stop all background delivery tasks
        for (_, query) in backgroundDeliveryTasks {
            healthStore.stop(query)
        }
        backgroundDeliveryTasks.removeAll()
        
        // Cancel all timers
        for (_, timer) in updateTimers {
            timer.invalidate()
        }
        updateTimers.removeAll()
    }
}

// MARK: - Helper Extensions
extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running:
            return "Running"
        case .cycling:
            return "Cycling"
        case .walking:
            return "Walking"
        case .swimming:
            return "Swimming"
        case .yoga:
            return "Yoga"
        case .hiking:
            return "Hiking"
        case .strengthTraining:
            return "Strength Training"
        case .traditionalStrengthTraining:
            return "Weight Training"
        case .functionalStrengthTraining:
            return "Functional Training"
        case .highIntensityIntervalTraining:
            return "HIIT"
        case .dance:
            return "Dance"
        case .soccer:
            return "Soccer"
        case .basketball:
            return "Basketball"
        case .tennis:
            return "Tennis"
        // Add other workout types as needed
        default:
            return "Workout"
        }
    }
} 