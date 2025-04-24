import Foundation

class WhoopService {
    static let shared = WhoopService()
    private let baseURL = "https://api.prod.whoop.com/developer/v1"
    private let authService = WhoopAuthService.shared
    
    // MARK: - Initialization
    private init() {
        // Listen for auth state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthStateChanged),
            name: WhoopAuthService.authStateChangedNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleAuthStateChanged() {
        // This could trigger additional logic when auth state changes
        // For example, refreshing data if authenticated or clearing cache if not
    }
    
    // MARK: - Connection Status
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    @Published private(set) var connectionStatus: ConnectionStatus = .disconnected
    
    var isConnected: Bool {
        return authService.isAuthenticated
    }
    
    // MARK: - Authentication
    func connect() async throws -> Bool {
        updateConnectionStatus(.connecting)
        
        do {
            // For testing purposes, using client credentials flow
            // In production, this should use authorization code flow
            try await authService.authenticateWithClientCredentials()
            updateConnectionStatus(.connected)
            return true
        } catch {
            let errorMessage = handleAuthError(error)
            updateConnectionStatus(.error(errorMessage))
            throw error
        }
    }
    
    func disconnect() {
        authService.clearTokens()
        updateConnectionStatus(.disconnected)
    }
    
    private func handleAuthError(_ error: Error) -> String {
        if let authError = error as? WhoopAuthService.AuthError {
            switch authError {
            case .invalidCredentials:
                return "Invalid WHOOP API credentials. Please check your settings."
            case .notAuthenticated:
                return "Not authenticated with WHOOP. Please connect your account."
            case .serverError:
                return "WHOOP server error. Please try again later."
            case .noRefreshToken:
                return "Authentication session expired. Please reconnect your account."
            case .networkError:
                return "Network error. Please check your internet connection."
            }
        }
        return "Unknown error: \(error.localizedDescription)"
    }
    
    private func updateConnectionStatus(_ status: ConnectionStatus) {
        DispatchQueue.main.async {
            self.connectionStatus = status
        }
    }
    
    // MARK: - Data Fetching
    func fetchDailyMetrics() async throws -> HealthData.WhoopMetrics {
        // Ensure we're authenticated before making the request
        guard authService.isAuthenticated else {
            throw APIError.authenticationRequired
        }
        
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
        
        // Fetch sleep data for additional metrics
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let (sleepDuration, sleepQuality) = try await fetchSleepData(date: yesterday)
        
        return HealthData.WhoopMetrics(
            strain: cycleScore.strain,
            recovery: recoveryScore.recovery_score,
            hrv: recoveryScore.hrv_rmssd_milli,
            restingHeartRate: recoveryScore.resting_heart_rate,
            sleepPerformance: sleepQuality,
            respiratoryRate: recoveryScore.spo2_percentage ?? 0
        )
    }
    
    func fetchWorkouts(from: Date, to: Date) async throws -> [HealthData.WorkoutSession] {
        // Ensure we're authenticated before making the request
        guard authService.isAuthenticated else {
            throw APIError.authenticationRequired
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let fromString = dateFormatter.string(from: from)
        let toString = dateFormatter.string(from: to)
        
        let workouts: PaginatedWorkoutResponse = try await performRequest(
            "/activity/workout?start=\(fromString)&end=\(toString)&limit=25"
        )
        
        return workouts.records.compactMap { workout in
            guard let score = workout.score else { return nil }
            
            return HealthData.WorkoutSession(
                type: mapSportIdToName(workout.sport_id),
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
        // Ensure we're authenticated before making the request
        guard authService.isAuthenticated else {
            throw APIError.authenticationRequired
        }
        
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
    
    // MARK: - Helper Methods
    private func mapSportIdToName(_ sportId: Int) -> String {
        // Map WHOOP sport IDs to readable names
        // This is a simplified mapping - a real implementation would be more comprehensive
        switch sportId {
        case 0: return "Running"
        case 1: return "Cycling"
        case 2: return "Swimming"
        case 3: return "Weightlifting"
        case 4: return "Functional Fitness"
        case 5: return "HIIT"
        case 6: return "Yoga"
        case 7: return "Pilates"
        default: return "Activity \(sportId)"
        }
    }
    
    // MARK: - Data Processing
    func analyzeRecoveryTrends(days: Int) async throws -> [String: Any] {
        // Ensure we're authenticated before making the request
        guard authService.isAuthenticated else {
            throw APIError.authenticationRequired
        }
        
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
        
        // Ensure we have an access token
        guard let accessToken = authService.accessToken else {
            throw APIError.authenticationRequired
        }
        
        // Check if token needs to be refreshed
        if authService.isTokenExpired {
            // Try to refresh the token
            try await authService.refreshAccessToken()
            
            // Check again after refresh attempt
            guard let refreshedToken = authService.accessToken else {
                throw APIError.authenticationRequired
            }
            
            // Use the refreshed token
            var request = createAuthenticatedRequest(url: url, token: refreshedToken)
            return try await performNetworkRequest(request: request)
        } else {
            // Use the existing token
            var request = createAuthenticatedRequest(url: url, token: accessToken)
            return try await performNetworkRequest(request: request)
        }
    }
    
    private func createAuthenticatedRequest(url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
    
    private func performNetworkRequest<T: Codable>(request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if httpResponse.statusCode == 401 {
                // Token may be invalid, clear auth state
                authService.clearTokens()
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