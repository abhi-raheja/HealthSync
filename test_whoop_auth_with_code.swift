import Foundation

// Copy of the Config struct
struct Config {
    struct Whoop {
        static let clientId = "6f4b671e-14fc-4049-ad68-a69e2da525c4"
        static let clientSecret = "2540c0ef238d56912e8115b89e84db622f4ba0ad7d6d37fc31e1814be9c97ad1"
    }
}

// Simple auth service for testing with authorization code
class WhoopAuthTesterWithCode {
    private let tokenURL = "https://api.prod.whoop.com/oauth/oauth2/token"
    private let redirectURI = "https://abhiraheja.com"
    
    func testAuth(code: String) async {
        print("Testing WHOOP authentication with authorization code...")
        print("Client ID: \(Config.Whoop.clientId)")
        print("Client Secret: \(String(Config.Whoop.clientSecret.prefix(5)))...")
        print("Authorization Code: \(code)")
        
        do {
            let success = try await authenticate(code: code)
            print("Authentication result: \(success ? "SUCCESS" : "FAILED")")
        } catch {
            print("Authentication error: \(error.localizedDescription)")
        }
    }
    
    private func authenticate(code: String) async throws -> Bool {
        print("Starting authorization code authentication process...")
        
        guard let url = URL(string: tokenURL) else {
            print("Invalid URL")
            throw NSError(domain: "WhoopAuthTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        print("Preparing request to \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Body parameters for authorization code flow
        let bodyParams = [
            "client_id": Config.Whoop.clientId,
            "client_secret": Config.Whoop.clientSecret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ]
        
        // Create form-encoded body
        let bodyString = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        print("Sending request...")
        
        // Perform request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Invalid response type")
            throw NSError(domain: "WhoopAuthTest", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        print("HTTP Status Code: \(httpResponse.statusCode)")
        
        if (200...299).contains(httpResponse.statusCode) {
            // Try to parse the response
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("Response keys: \(Array(jsonObject.keys))")
                
                // Print access token details (but not the full token for security)
                if let accessToken = jsonObject["access_token"] as? String {
                    print("✅ Received access token (first 5 chars): \(String(accessToken.prefix(5)))...")
                }
                
                if let expiresIn = jsonObject["expires_in"] as? Int {
                    print("✅ Token expires in: \(expiresIn) seconds")
                }
                
                if let refreshToken = jsonObject["refresh_token"] as? String {
                    print("✅ Received refresh token (first 5 chars): \(String(refreshToken.prefix(5)))...")
                }
                
                return true
            } else {
                print("❌ Received valid status code but could not parse response")
                if let text = String(data: data, encoding: .utf8) {
                    print("Raw response: \(text)")
                }
                return false
            }
        } else {
            // Try to print the error response
            if let errorText = String(data: data, encoding: .utf8) {
                print("❌ Error response: \(errorText)")
            }
            return false
        }
    }
}

print("""
==========================================================
WHOOP Authentication Test With Authorization Code
==========================================================

This script will test authenticating with WHOOP using an authorization code.

To get an authorization code:
1. Run the test_whoop_auth_redirect.swift script
2. Open the generated URL in a browser
3. Login to WHOOP and authorize the app
4. Copy the code from the redirect URL (after ?code= and before &state=)

Enter the authorization code below:
""")

// Read the code from the command line
print("> ", terminator: "")
guard let code = readLine(), !code.isEmpty else {
    print("No code provided. Exiting.")
    exit(1)
}

// Create a simple runloop-based execution environment for async code
let tester = WhoopAuthTesterWithCode()
let semaphore = DispatchSemaphore(value: 0)

Task {
    await tester.testAuth(code: code)
    print("\nTest completed.")
    semaphore.signal()
}

// Wait for the task to complete
semaphore.wait() 