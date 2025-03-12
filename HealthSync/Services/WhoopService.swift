import Foundation

class WhoopService {
    static let shared = WhoopService()
    private let baseURL = "https://api.prod.whoop.com/developer/v1"
    private var authToken: String?
    private let tokenURL = "https://api.prod.whoop.com/oauth/oauth2/token"
    
    // MARK: - Authentication
    func authenticate(clientId: String, clientSecret: String) async throws -> Bool {
        let url = URL(string: tokenURL)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "grant_type": "client_credentials"
        ]
        
        let bodyString = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }
            
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            self.authToken = authResponse.access_token
            
            // Store refresh token securely (in a real app, you'd want to use Keychain)
            UserDefaults.standard.set(authResponse.refresh_token, forKey: "whoop_refresh_token")
            
            return true
        } catch {
            print("Authentication error: \(error)")
            throw APIError.authenticationRequired
        }
    }
    
    // MARK: - Data Fetching
    func fetchDailyMetrics() async throws -> HealthData.WhoopMetrics {
        // Get the latest cycle data
        let cycles: PaginatedCycleResponse = try await performRequest("/cycle?limit=1")
        
        guard let latestCycle = cycles.records.first,
              let cycleScore = latestCycle.score else {
            throw APIError.dataNotAvailable
        }
        
        // Get recovery data for this cycle
        let recovery: Recovery = try await performRequest("/cycle/\(latestCycle.id)/recovery")
        
        guard let recoveryScore = recovery.score else {
            throw APIError.dataNotAvailable
        }
        
        return HealthData.WhoopMetrics(
            strain: cycleScore.strain,
            recovery: recoveryScore.recovery_score,
            hrv: recoveryScore.hrv_rmssd_milli,
            restingHeartRate: recoveryScore.resting_heart_rate,
            sleepPerformance: 0, // We'll get this from sleep data
            respiratoryRate: 0   // We'll get this from sleep data
        )
    }
    
    func fetchWorkouts(from: Date, to: Date) async throws -> [HealthData.WorkoutSession] {
        let dateFormatter = ISO8601DateFormatter()
        let fromString = dateFormatter.string(from: from)
        let toString = dateFormatter.string(from: to)
        
        let workouts: PaginatedWorkoutResponse = try await performRequest(
            "/activity/workout?start=\(fromString)&end=\(toString)&limit=25"
        )
        
        return workouts.records.compactMap { workout in
            guard let score = workout.score else { return nil }
            
            return HealthData.WorkoutSession(
                type: "Workout \(workout.sport_id)", // We would need to map sport_id to names
                startTime: workout.start,
                endTime: workout.end,
                strain: score.strain,
                heartRateData: [score.average_heart_rate, score.max_heart_rate], // Simplified
                caloriesBurned: score.kilojoule / 4.184, // Convert kJ to kcal
                notes: nil
            )
        }
    }
    
    func fetchSleepData(date: Date) async throws -> (duration: TimeInterval, quality: Double) {
        let dateFormatter = ISO8601DateFormatter()
        let dateString = dateFormatter.string(from: date)
        let nextDayString = dateFormatter.string(from: date.addingTimeInterval(86400)) // Next day
        
        let sleeps: PaginatedSleepResponse = try await performRequest(
            "/activity/sleep?start=\(dateString)&end=\(nextDayString)&limit=1"
        )
        
        guard let latestSleep = sleeps.records.first,
              let score = latestSleep.score else {
            throw APIError.dataNotAvailable
        }
        
        let totalSleepMillis = score.stage_summary.total_light_sleep_time_milli +
                               score.stage_summary.total_rem_sleep_time_milli +
                               score.stage_summary.total_slow_wave_sleep_time_milli
        
        let duration = TimeInterval(totalSleepMillis) / 1000 // Convert to seconds
        let quality = score.sleep_performance_percentage ?? 0
        
        return (duration: duration, quality: quality)
    }
    
    // MARK: - Data Processing
    func analyzeRecoveryTrends(days: Int) async throws -> [String: Any] {
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: now)!
        
        let dateFormatter = ISO8601DateFormatter()
        let fromString = dateFormatter.string(from: startDate)
        let toString = dateFormatter.string(from: now)
        
        let recoveries: PaginatedRecoveryResponse = try await performRequest(
            "/recovery?start=\(fromString)&end=\(toString)&limit=25"
        )
        
        var recoveryScores: [Double] = []
        var hrvValues: [Double] = []
        var restingHRValues: [Double] = []
        var dates: [Date] = []
        
        for recovery in recoveries.records {
            guard let score = recovery.score else { continue }
            
            recoveryScores.append(score.recovery_score)
            hrvValues.append(score.hrv_rmssd_milli)
            restingHRValues.append(score.resting_heart_rate)
            if let sleepId = recovery.sleep_id {
                dates.append(recovery.created_at) // Using created_at as a proxy for date
            }
        }
        
        // Calculate trends and averages
        let avgRecovery = recoveryScores.reduce(0, +) / Double(recoveryScores.count)
        let avgHRV = hrvValues.reduce(0, +) / Double(hrvValues.count)
        let avgRestingHR = restingHRValues.reduce(0, +) / Double(restingHRValues.count)
        
        // Calculate trend (positive or negative)
        let recoveryTrend = calculateTrend(values: recoveryScores)
        let hrvTrend = calculateTrend(values: hrvValues)
        let restingHRTrend = calculateTrend(values: restingHRValues) * -1 // Inverse for HR (lower is better)
        
        return [
            "avgRecovery": avgRecovery,
            "avgHRV": avgHRV,
            "avgRestingHR": avgRestingHR,
            "recoveryTrend": recoveryTrend,
            "hrvTrend": hrvTrend,
            "restingHRTrend": restingHRTrend,
            "dates": dates,
            "recoveryScores": recoveryScores,
            "hrvValues": hrvValues,
            "restingHRValues": restingHRValues
        ]
    }
    
    private func calculateTrend(values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        
        // Simple linear regression
        let n = Double(values.count)
        let indices = Array(0..<values.count).map(Double.init)
        
        let sumX = indices.reduce(0, +)
        let sumY = values.reduce(0, +)
        let sumXY = zip(indices, values).map(*).reduce(0, +)
        let sumX2 = indices.map { $0 * $0 }.reduce(0, +)
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        return slope
    }
    
    func calculateStrainImpact(workout: HealthData.WorkoutSession) -> Double {
        return workout.strain
    }
}

// MARK: - API Response Models
extension WhoopService {
    // Authentication models
    struct AuthResponse: Codable {
        let access_token: String
        let refresh_token: String
        let expires_in: Int
        let token_type: String
    }
    
    // API models based on the OpenAPI documentation
    struct PaginatedCycleResponse: Codable {
        let records: [Cycle]
        let next_token: String?
    }
    
    struct Cycle: Codable {
        let id: Int64
        let user_id: Int64
        let created_at: Date
        let updated_at: Date
        let start: Date
        let end: Date?
        let timezone_offset: String
        let score_state: String
        let score: CycleScore?
    }
    
    struct CycleScore: Codable {
        let strain: Double
        let kilojoule: Double
        let average_heart_rate: Int
        let max_heart_rate: Int
    }
    
    struct PaginatedRecoveryResponse: Codable {
        let records: [Recovery]
        let next_token: String?
    }
    
    struct Recovery: Codable {
        let cycle_id: Int64
        let sleep_id: Int64?
        let user_id: Int64
        let created_at: Date
        let updated_at: Date
        let score_state: String
        let score: RecoveryScore?
    }
    
    struct RecoveryScore: Codable {
        let user_calibrating: Bool
        let recovery_score: Double
        let resting_heart_rate: Double
        let hrv_rmssd_milli: Double
        let spo2_percentage: Double?
        let skin_temp_celsius: Double?
    }
    
    struct PaginatedSleepResponse: Codable {
        let records: [Sleep]
        let next_token: String?
    }
    
    struct Sleep: Codable {
        let id: Int64
        let user_id: Int64
        let created_at: Date
        let updated_at: Date
        let start: Date
        let end: Date
        let timezone_offset: String
        let nap: Bool
        let score_state: String
        let score: SleepScore?
    }
    
    struct SleepScore: Codable {
        let stage_summary: SleepStageSummary
        let sleep_needed: SleepNeeded
        let respiratory_rate: Double?
        let sleep_performance_percentage: Double?
        let sleep_consistency_percentage: Double?
        let sleep_efficiency_percentage: Double?
    }
    
    struct SleepStageSummary: Codable {
        let total_in_bed_time_milli: Int
        let total_awake_time_milli: Int
        let total_no_data_time_milli: Int
        let total_light_sleep_time_milli: Int
        let total_slow_wave_sleep_time_milli: Int
        let total_rem_sleep_time_milli: Int
        let sleep_cycle_count: Int
        let disturbance_count: Int
    }
    
    struct SleepNeeded: Codable {
        let baseline_milli: Int64
        let need_from_sleep_debt_milli: Int64
        let need_from_recent_strain_milli: Int64
        let need_from_recent_nap_milli: Int64
    }
    
    struct PaginatedWorkoutResponse: Codable {
        let records: [Workout]
        let next_token: String?
    }
    
    struct Workout: Codable {
        let id: Int64
        let user_id: Int64
        let created_at: Date
        let updated_at: Date
        let start: Date
        let end: Date
        let timezone_offset: String
        let sport_id: Int
        let score_state: String
        let score: WorkoutScore?
    }
    
    struct WorkoutScore: Codable {
        let strain: Double
        let average_heart_rate: Int
        let max_heart_rate: Int
        let kilojoule: Double
        let percent_recorded: Double
        let distance_meter: Double?
        let altitude_gain_meter: Double?
        let altitude_change_meter: Double?
        let zone_duration: ZoneDuration
    }
    
    struct ZoneDuration: Codable {
        let zone_zero_milli: Int?
        let zone_one_milli: Int?
        let zone_two_milli: Int?
        let zone_three_milli: Int?
        let zone_four_milli: Int?
        let zone_five_milli: Int?
    }
}

// MARK: - Networking
extension WhoopService {
    enum APIError: Error {
        case invalidURL
        case invalidResponse
        case authenticationRequired
        case dataNotAvailable
        case networkError(Error)
    }
    
    private func performRequest<T: Codable>(_ endpoint: String) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        guard let authToken = authToken else {
            throw APIError.authenticationRequired
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if httpResponse.statusCode == 401 {
                throw APIError.authenticationRequired
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            return try decoder.decode(T.self, from: data)
        } catch let decodingError as DecodingError {
            print("Decoding error: \(decodingError)")
            throw APIError.invalidResponse
        } catch let urlError as URLError {
            print("URL error: \(urlError)")
            throw APIError.networkError(urlError)
        } catch {
            print("Unknown error: \(error)")
            throw APIError.networkError(error)
        }
    }
}