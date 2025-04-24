import Foundation

// Copy of the Config struct
struct Config {
    struct Whoop {
        static let clientId = "6f4b671e-14fc-4049-ad68-a69e2da525c4"
        static let clientSecret = "2540c0ef238d56912e8115b89e84db622f4ba0ad7d6d37fc31e1814be9c97ad1"
    }
}

// Simple auth service for testing
class WhoopAuthTester {
    private let tokenURL = "https://api.prod.whoop.com/oauth/oauth2/token"
    
    func testAuth() async {
        print("Testing WHOOP authentication with provided credentials...")
        print("Client ID: \(Config.Whoop.clientId)")
        print("Client Secret: \(String(Config.Whoop.clientSecret.prefix(5)))...") // Only print first 5 chars for security
        
        do {
            let success = try await authenticate()
            print("Authentication result: \(success ? "SUCCESS" : "FAILED")")
        } catch {
            print("Authentication error: \(error.localizedDescription)")
        }
    }
    
    private func authenticate() async throws -> Bool {
        print("Starting authentication process...")
        
        guard let url = URL(string: tokenURL) else {
            print("Invalid URL")
            throw NSError(domain: "WhoopAuthTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        print("Preparing request to \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Body parameters
        let bodyParams = [
            "client_id": Config.Whoop.clientId,
            "client_secret": Config.Whoop.clientSecret,
            "grant_type": "client_credentials"
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
                let keys = Array(jsonObject.keys)
                print("Response contains keys: \(keys)")
                return true
            } else {
                print("Received valid status code but could not parse response")
                return false
            }
        } else {
            // Try to print the error response
            if let errorText = String(data: data, encoding: .utf8) {
                print("Error response: \(errorText)")
            }
            return false
        }
    }
}

// Create a simple runloop-based execution environment for async code
print("Starting WHOOP auth test...")

let tester = WhoopAuthTester()
let semaphore = DispatchSemaphore(value: 0)

Task {
    await tester.testAuth()
    print("Test completed.")
    semaphore.signal()
}

// Wait for the task to complete
semaphore.wait() 