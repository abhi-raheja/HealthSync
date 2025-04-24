import Foundation
import Security

class WhoopAuthService {
    // MARK: - Singleton
    static let shared = WhoopAuthService()
    
    // MARK: - Properties
    private let tokenURL = "https://api.prod.whoop.com/oauth/oauth2/token"
    private let authorizationURL = "https://api.prod.whoop.com/oauth/oauth2/auth"
    private let userInfoURL = "https://api.prod.whoop.com/developer/v1/user/profile"
    
    // Keys for Keychain
    private let accessTokenKey = "whoop_access_token"
    private let refreshTokenKey = "whoop_refresh_token"
    private let tokenExpiryKey = "whoop_token_expiry"
    
    // Notification
    static let authStateChangedNotification = Notification.Name("WhoopAuthStateChanged")
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Auth State
    enum AuthState {
        case notAuthenticated
        case authenticating
        case authenticated
        case failed(Error)
    }
    
    @Published private(set) var authState: AuthState = .notAuthenticated
    
    // MARK: - Token Management
    
    // Access Token
    var accessToken: String? {
        get {
            return getKeychainValue(for: accessTokenKey)
        }
        set {
            if let newValue = newValue {
                saveKeychainValue(newValue, for: accessTokenKey)
            } else {
                deleteKeychainValue(for: accessTokenKey)
            }
        }
    }
    
    // Refresh Token
    var refreshToken: String? {
        get {
            return getKeychainValue(for: refreshTokenKey)
        }
        set {
            if let newValue = newValue {
                saveKeychainValue(newValue, for: refreshTokenKey)
            } else {
                deleteKeychainValue(for: refreshTokenKey)
            }
        }
    }
    
    // Token Expiry Date
    var tokenExpiryDate: Date? {
        get {
            guard let timestampString = UserDefaults.standard.string(for: tokenExpiryKey),
                  let timestamp = Double(timestampString) else {
                return nil
            }
            return Date(timeIntervalSince1970: timestamp)
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(String(date.timeIntervalSince1970), forKey: tokenExpiryKey)
            } else {
                UserDefaults.standard.removeObject(forKey: tokenExpiryKey)
            }
        }
    }
    
    // Check if token is expired
    var isTokenExpired: Bool {
        guard let expiryDate = tokenExpiryDate else {
            return true
        }
        
        // Consider token expired if less than 5 minutes until expiration
        let expirationBuffer: TimeInterval = 300 // 5 minutes
        return Date().addingTimeInterval(expirationBuffer) > expiryDate
    }
    
    // Check if authenticated
    var isAuthenticated: Bool {
        return accessToken != nil && !isTokenExpired
    }
    
    // MARK: - Authentication Methods
    
    // Client Credentials Flow (for testing)
    func authenticateWithClientCredentials() async throws {
        guard let clientId = Config.Whoop.clientId, 
              let clientSecret = Config.Whoop.clientSecret,
              !clientId.isEmpty && !clientSecret.isEmpty && 
              clientId != "YOUR_CLIENT_ID" && clientSecret != "YOUR_CLIENT_SECRET" else {
            throw AuthError.invalidCredentials
        }
        
        // Update auth state
        updateAuthState(.authenticating)
        
        do {
            // Create request
            let url = URL(string: tokenURL)!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            // Body parameters
            let bodyParams = [
                "client_id": clientId,
                "client_secret": clientSecret,
                "grant_type": "client_credentials"
            ]
            
            // Create form-encoded body
            let bodyString = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            request.httpBody = bodyString.data(using: .utf8)
            
            // Perform request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check response
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                updateAuthState(.failed(AuthError.serverError))
                throw AuthError.serverError
            }
            
            // Decode and process the response
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            processAuthResponse(authResponse)
            
            // Update auth state
            updateAuthState(.authenticated)
            
            return
        } catch {
            updateAuthState(.failed(error))
            throw error
        }
    }
    
    // Authorization Code Flow (for production)
    func authenticateWithAuthorizationCode(code: String, redirectURI: String) async throws {
        guard let clientId = Config.Whoop.clientId, 
              let clientSecret = Config.Whoop.clientSecret,
              !clientId.isEmpty && !clientSecret.isEmpty && 
              clientId != "YOUR_CLIENT_ID" && clientSecret != "YOUR_CLIENT_SECRET" else {
            throw AuthError.invalidCredentials
        }
        
        // Update auth state
        updateAuthState(.authenticating)
        
        do {
            // Create request
            let url = URL(string: tokenURL)!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            // Body parameters
            let bodyParams = [
                "client_id": clientId,
                "client_secret": clientSecret,
                "code": code,
                "grant_type": "authorization_code",
                "redirect_uri": redirectURI
            ]
            
            // Create form-encoded body
            let bodyString = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            request.httpBody = bodyString.data(using: .utf8)
            
            // Perform request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check response
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                updateAuthState(.failed(AuthError.serverError))
                throw AuthError.serverError
            }
            
            // Decode and process the response
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            processAuthResponse(authResponse)
            
            // Update auth state
            updateAuthState(.authenticated)
            
            return
        } catch {
            updateAuthState(.failed(error))
            throw error
        }
    }
    
    // Refresh Token
    func refreshAccessToken() async throws {
        guard let refreshToken = refreshToken else {
            updateAuthState(.notAuthenticated)
            throw AuthError.noRefreshToken
        }
        
        guard let clientId = Config.Whoop.clientId, 
              let clientSecret = Config.Whoop.clientSecret,
              !clientId.isEmpty && !clientSecret.isEmpty && 
              clientId != "YOUR_CLIENT_ID" && clientSecret != "YOUR_CLIENT_SECRET" else {
            throw AuthError.invalidCredentials
        }
        
        do {
            // Create request
            let url = URL(string: tokenURL)!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            // Body parameters
            let bodyParams = [
                "client_id": clientId,
                "client_secret": clientSecret,
                "refresh_token": refreshToken,
                "grant_type": "refresh_token"
            ]
            
            // Create form-encoded body
            let bodyString = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            request.httpBody = bodyString.data(using: .utf8)
            
            // Perform request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check response
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                updateAuthState(.notAuthenticated)
                throw AuthError.serverError
            }
            
            // Decode and process the response
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            processAuthResponse(authResponse)
            
            return
        } catch {
            // If refresh fails, clear tokens and update state
            clearTokens()
            updateAuthState(.notAuthenticated)
            throw error
        }
    }
    
    // MARK: - Auth URL Generation
    
    func generateAuthorizationURL(redirectURI: String, state: String) -> URL? {
        guard let clientId = Config.Whoop.clientId, !clientId.isEmpty, clientId != "YOUR_CLIENT_ID" else {
            return nil
        }
        
        var components = URLComponents(string: authorizationURL)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "read:profile read:recovery read:cycles read:workout read:sleep"),
            URLQueryItem(name: "state", value: state)
        ]
        
        return components?.url
    }
    
    // MARK: - Helper Methods
    
    private func processAuthResponse(_ response: AuthResponse) {
        // Save tokens
        accessToken = response.access_token
        refreshToken = response.refresh_token
        
        // Calculate expiry date
        let expiryDate = Date().addingTimeInterval(Double(response.expires_in))
        tokenExpiryDate = expiryDate
        
        // Update auth state
        updateAuthState(.authenticated)
    }
    
    private func updateAuthState(_ newState: AuthState) {
        authState = newState
        NotificationCenter.default.post(name: WhoopAuthService.authStateChangedNotification, object: nil)
    }
    
    func clearTokens() {
        accessToken = nil
        refreshToken = nil
        tokenExpiryDate = nil
        updateAuthState(.notAuthenticated)
    }
    
    // MARK: - User Info
    
    func fetchUserInfo() async throws -> WhoopUserProfile {
        guard let token = accessToken else {
            throw AuthError.notAuthenticated
        }
        
        // Check if token is expired and refresh if needed
        if isTokenExpired {
            try await refreshAccessToken()
        }
        
        // Create request
        let url = URL(string: userInfoURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Perform request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.serverError
        }
        
        // Decode the user profile
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(WhoopUserProfile.self, from: data)
    }
    
    // MARK: - Keychain Operations
    
    private func saveKeychainValue(_ value: String, for key: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Error saving to Keychain: \(status)")
        }
    }
    
    private func getKeychainValue(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        } else {
            return nil
        }
    }
    
    private func deleteKeychainValue(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Types

extension WhoopAuthService {
    struct AuthResponse: Codable {
        let access_token: String
        let refresh_token: String
        let expires_in: Int
        let token_type: String
    }
    
    struct WhoopUserProfile: Codable {
        let id: Int64
        let email: String?
        let first_name: String
        let last_name: String
        let profile_picture_url: String?
    }
    
    enum AuthError: Error {
        case invalidCredentials
        case notAuthenticated
        case serverError
        case noRefreshToken
        case networkError
    }
}

// MARK: - UserDefaults extension
extension UserDefaults {
    func string(for key: String) -> String? {
        return string(forKey: key)
    }
} 