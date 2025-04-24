import Foundation
import CoreData

class CoreDataManager {
    // MARK: - Singleton
    static let shared = CoreDataManager()
    
    // MARK: - Core Data Stack
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "HealthSyncData")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        return container
    }()
    
    private lazy var context: NSManagedObjectContext = {
        return persistentContainer.viewContext
    }()
    
    private init() {}
    
    // MARK: - Core Data Saving
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
                print("CoreData context saved successfully")
            } catch {
                let nserror = error as NSError
                print("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    // MARK: - User Profile Operations
    func saveUserProfile(profile: HealthData.UserProfile) -> UserProfileEntity? {
        let entity = UserProfileEntity(context: context)
        entity.id = UUID()
        entity.name = profile.name
        entity.age = Int16(profile.age)
        entity.testDate = profile.testDate
        
        saveContext()
        return entity
    }
    
    func getUserProfile() -> HealthData.UserProfile? {
        let fetchRequest: NSFetchRequest<UserProfileEntity> = UserProfileEntity.fetchRequest()
        
        do {
            let results = try context.fetch(fetchRequest)
            if let entity = results.first {
                return HealthData.UserProfile(
                    name: entity.name ?? "",
                    age: Int(entity.age),
                    testDate: entity.testDate ?? Date()
                )
            }
        } catch {
            print("Error fetching user profile: \(error)")
        }
        
        return nil
    }
    
    func updateUserProfile(profile: HealthData.UserProfile) {
        let fetchRequest: NSFetchRequest<UserProfileEntity> = UserProfileEntity.fetchRequest()
        
        do {
            let results = try context.fetch(fetchRequest)
            if let entity = results.first {
                entity.name = profile.name
                entity.age = Int16(profile.age)
                entity.testDate = profile.testDate
                saveContext()
            } else {
                _ = saveUserProfile(profile: profile)
            }
        } catch {
            print("Error updating user profile: \(error)")
        }
    }
    
    // MARK: - WHOOP Metrics Operations
    func saveWhoopMetrics(metrics: HealthData.WhoopMetrics, date: Date = Date()) -> WhoopMetricsEntity? {
        let entity = WhoopMetricsEntity(context: context)
        entity.id = UUID()
        entity.date = date
        entity.strain = metrics.strain
        entity.recovery = metrics.recovery
        entity.hrv = metrics.hrv
        entity.restingHeartRate = metrics.restingHeartRate
        entity.sleepPerformance = metrics.sleepPerformance
        entity.respiratoryRate = metrics.respiratoryRate
        
        // Link to user profile if available
        if let userProfileEntity = fetchFirstUserProfileEntity() {
            entity.userProfile = userProfileEntity
        }
        
        saveContext()
        return entity
    }
    
    func getLatestWhoopMetrics() -> HealthData.WhoopMetrics? {
        let fetchRequest: NSFetchRequest<WhoopMetricsEntity> = WhoopMetricsEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            if let entity = results.first {
                return HealthData.WhoopMetrics(
                    strain: entity.strain,
                    recovery: entity.recovery,
                    hrv: entity.hrv,
                    restingHeartRate: entity.restingHeartRate,
                    sleepPerformance: entity.sleepPerformance,
                    respiratoryRate: entity.respiratoryRate
                )
            }
        } catch {
            print("Error fetching WHOOP metrics: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Fasting Window Operations
    func saveFastingWindow(window: HealthData.FastingWindow) -> FastingWindowEntity? {
        let entity = FastingWindowEntity(context: context)
        entity.id = UUID()
        entity.startTime = window.startTime
        entity.endTime = window.endTime
        entity.targetDuration = window.targetDuration
        entity.actualDuration = window.actualDuration ?? 0
        entity.completed = window.completed
        
        // Link to user profile if available
        if let userProfileEntity = fetchFirstUserProfileEntity() {
            entity.userProfile = userProfileEntity
        }
        
        saveContext()
        return entity
    }
    
    func getCurrentFastingWindow() -> HealthData.FastingWindow? {
        let fetchRequest: NSFetchRequest<FastingWindowEntity> = FastingWindowEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "completed == %@", NSNumber(value: false))
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            if let entity = results.first {
                return HealthData.FastingWindow(
                    startTime: entity.startTime ?? Date(),
                    endTime: entity.endTime ?? Date(),
                    targetDuration: entity.targetDuration,
                    actualDuration: entity.actualDuration > 0 ? entity.actualDuration : nil,
                    completed: entity.completed
                )
            }
        } catch {
            print("Error fetching current fasting window: \(error)")
        }
        
        return nil
    }
    
    func updateFastingWindow(window: HealthData.FastingWindow) {
        let fetchRequest: NSFetchRequest<FastingWindowEntity> = FastingWindowEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "completed == %@", NSNumber(value: false))
        
        do {
            let results = try context.fetch(fetchRequest)
            if let entity = results.first {
                entity.startTime = window.startTime
                entity.endTime = window.endTime
                entity.targetDuration = window.targetDuration
                entity.actualDuration = window.actualDuration ?? 0
                entity.completed = window.completed
                saveContext()
            } else {
                _ = saveFastingWindow(window: window)
            }
        } catch {
            print("Error updating fasting window: \(error)")
        }
    }
    
    // MARK: - Supplement Log Operations
    func saveSupplementLogs(supplements: [HealthData.SupplementLog]) {
        // First clear today's supplements
        clearTodaySupplements()
        
        // Then save new ones
        for supplement in supplements {
            let entity = SupplementLogEntity(context: context)
            entity.id = UUID()
            entity.name = supplement.name
            entity.dosage = supplement.dosage
            entity.timeToTake = supplement.timeToTake
            entity.taken = supplement.taken
            entity.notes = supplement.notes
            
            // Link to user profile if available
            if let userProfileEntity = fetchFirstUserProfileEntity() {
                entity.userProfile = userProfileEntity
            }
        }
        
        saveContext()
    }
    
    func getTodaySupplements() -> [HealthData.SupplementLog] {
        let fetchRequest: NSFetchRequest<SupplementLogEntity> = SupplementLogEntity.fetchRequest()
        
        // Create calendar components for today's date range
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        fetchRequest.predicate = NSPredicate(format: "timeToTake >= %@ AND timeToTake < %@", startOfDay as NSDate, endOfDay as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timeToTake", ascending: true)]
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.map { entity in
                HealthData.SupplementLog(
                    name: entity.name ?? "",
                    dosage: entity.dosage ?? "",
                    timeToTake: entity.timeToTake ?? Date(),
                    taken: entity.taken,
                    notes: entity.notes
                )
            }
        } catch {
            print("Error fetching today's supplements: \(error)")
            return []
        }
    }
    
    private func clearTodaySupplements() {
        let fetchRequest: NSFetchRequest<SupplementLogEntity> = SupplementLogEntity.fetchRequest()
        
        // Create calendar components for today's date range
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        fetchRequest.predicate = NSPredicate(format: "timeToTake >= %@ AND timeToTake < %@", startOfDay as NSDate, endOfDay as NSDate)
        
        do {
            let results = try context.fetch(fetchRequest)
            for entity in results {
                context.delete(entity)
            }
            saveContext()
        } catch {
            print("Error clearing today's supplements: \(error)")
        }
    }
    
    // MARK: - Coaching Insights Operations
    func saveCoachingInsights(insights: [HealthData.CoachingInsight]) {
        // First clear existing insights
        clearInsights()
        
        // Then save new ones
        for insight in insights {
            let entity = CoachingInsightEntity(context: context)
            entity.id = UUID()
            entity.date = insight.date
            entity.type = insight.type
            entity.message = insight.message
            entity.actionRequired = insight.actionRequired
            entity.completed = insight.completed ?? false
            
            // Link to user profile if available
            if let userProfileEntity = fetchFirstUserProfileEntity() {
                entity.userProfile = userProfileEntity
            }
        }
        
        saveContext()
    }
    
    func getCoachingInsights() -> [HealthData.CoachingInsight] {
        let fetchRequest: NSFetchRequest<CoachingInsightEntity> = CoachingInsightEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.map { entity in
                HealthData.CoachingInsight(
                    date: entity.date ?? Date(),
                    type: entity.type ?? "general",
                    message: entity.message ?? "",
                    actionRequired: entity.actionRequired,
                    completed: entity.completed
                )
            }
        } catch {
            print("Error fetching coaching insights: \(error)")
            return []
        }
    }
    
    private func clearInsights() {
        let fetchRequest: NSFetchRequest<CoachingInsightEntity> = CoachingInsightEntity.fetchRequest()
        
        do {
            let results = try context.fetch(fetchRequest)
            for entity in results {
                context.delete(entity)
            }
            saveContext()
        } catch {
            print("Error clearing insights: \(error)")
        }
    }
    
    // MARK: - Workout Session Operations
    func saveWorkoutSession(workout: HealthData.WorkoutSession) -> WorkoutSessionEntity? {
        let entity = WorkoutSessionEntity(context: context)
        entity.id = UUID()
        entity.type = workout.type
        entity.startTime = workout.startTime
        entity.endTime = workout.endTime
        entity.strain = workout.strain
        entity.heartRateData = workout.heartRateData as NSObject
        entity.caloriesBurned = workout.caloriesBurned
        entity.notes = workout.notes
        
        // Link to user profile if available
        if let userProfileEntity = fetchFirstUserProfileEntity() {
            entity.userProfile = userProfileEntity
        }
        
        saveContext()
        return entity
    }
    
    func getRecentWorkouts(limit: Int = 10) -> [HealthData.WorkoutSession] {
        let fetchRequest: NSFetchRequest<WorkoutSessionEntity> = WorkoutSessionEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        fetchRequest.fetchLimit = limit
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.map { entity in
                HealthData.WorkoutSession(
                    type: entity.type ?? "Unknown",
                    startTime: entity.startTime ?? Date(),
                    endTime: entity.endTime ?? Date(),
                    strain: entity.strain,
                    heartRateData: (entity.heartRateData as? [Double]) ?? [],
                    caloriesBurned: entity.caloriesBurned,
                    notes: entity.notes
                )
            }
        } catch {
            print("Error fetching recent workouts: \(error)")
            return []
        }
    }
    
    // MARK: - Helper Methods
    private func fetchFirstUserProfileEntity() -> UserProfileEntity? {
        let fetchRequest: NSFetchRequest<UserProfileEntity> = UserProfileEntity.fetchRequest()
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            print("Error fetching user profile entity: \(error)")
            return nil
        }
    }
}

// MARK: - Migration from UserDefaults
extension CoreDataManager {
    func migrateFromUserDefaults() {
        migrateUserProfile()
        migrateFastingWindow()
    }
    
    private func migrateUserProfile() {
        // Check if we already have a user profile in CoreData
        let fetchRequest: NSFetchRequest<UserProfileEntity> = UserProfileEntity.fetchRequest()
        do {
            let count = try context.count(for: fetchRequest)
            if count > 0 {
                // Already migrated
                return
            }
        } catch {
            print("Error checking for existing user profile: \(error)")
        }
        
        // Try to load from JSON file (as done in the ViewModel)
        if let url = Bundle.main.url(forResource: "UserProfile", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            if let profile = try? decoder.decode(HealthData.UserProfile.self, from: data) {
                _ = saveUserProfile(profile: profile)
                print("User profile migrated from JSON file")
            }
        }
    }
    
    private func migrateFastingWindow() {
        // Check if we already have fasting data in CoreData
        let fetchRequest: NSFetchRequest<FastingWindowEntity> = FastingWindowEntity.fetchRequest()
        do {
            let count = try context.count(for: fetchRequest)
            if count > 0 {
                // Already migrated
                return
            }
        } catch {
            print("Error checking for existing fasting windows: \(error)")
        }
        
        // Get from UserDefaults via FastingManager
        if let window = FastingManager.shared.getCurrentFastingWindow() {
            _ = saveFastingWindow(window: window)
            print("Fasting window migrated from UserDefaults")
        }
    }
} 