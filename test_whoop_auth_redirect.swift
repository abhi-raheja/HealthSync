import Foundation

// Copy of the Config struct
struct Config {
    struct Whoop {
        static let clientId = "6f4b671e-14fc-4049-ad68-a69e2da525c4"
        static let clientSecret = "2540c0ef238d56912e8115b89e84db622f4ba0ad7d6d37fc31e1814be9c97ad1"
    }
}

// Instructions for authorization code flow
print("""
WHOOP Authentication Instructions
================================

The test revealed that your WHOOP API client is configured to use the authorization code flow, 
not the client credentials flow. This means you need to:

1. Generate an authorization URL with your client ID
2. Open that URL in a browser to authenticate with WHOOP
3. WHOOP will redirect to your redirect URI with an authorization code
4. Your app must capture that code and exchange it for an access token

Here's the authorization URL to open in your browser:

""")

// Generate the authorization URL
let authURL = "https://api.prod.whoop.com/oauth/oauth2/auth"
let redirectURI = "https://abhiraheja.com" // Use the redirect URI you configured in the WHOOP developer portal
let state = UUID().uuidString // Random state for security

let urlComponents = NSURLComponents(string: authURL)!
urlComponents.queryItems = [
    URLQueryItem(name: "client_id", value: Config.Whoop.clientId),
    URLQueryItem(name: "redirect_uri", value: redirectURI),
    URLQueryItem(name: "response_type", value: "code"),
    URLQueryItem(name: "scope", value: "read:profile read:recovery read:cycles read:workout read:sleep"),
    URLQueryItem(name: "state", value: state)
]

print(urlComponents.url!.absoluteString)

print("""

After authentication, WHOOP will redirect to your redirect URI with a code parameter.
The URL will look something like:

\(redirectURI)?code=AUTHORIZATION_CODE&state=\(state)

Once you have the authorization code, update the WhoopAuthService.swift file to use 
the authorization code flow:

try await authService.authenticateWithAuthorizationCode(code: "YOUR_CODE", redirectURI: "\(redirectURI)")

Make sure to update the connect() method in WhoopService.swift to use 
authenticateWithAuthorizationCode instead of authenticateWithClientCredentials.

Example update for WhoopService.swift:

func connect(withCode code: String? = nil) async throws -> Bool {
    updateConnectionStatus(.connecting)
    
    do {
        if let code = code {
            // Use authorization code flow with the provided code
            try await authService.authenticateWithAuthorizationCode(
                code: code, 
                redirectURI: "https://abhiraheja.com"
            )
        } else {
            // For testing only - this will fail with your current WHOOP configuration
            try await authService.authenticateWithClientCredentials()
        }
        updateConnectionStatus(.connected)
        return true
    } catch {
        let errorMessage = handleAuthError(error)
        updateConnectionStatus(.error(errorMessage))
        throw error
    }
}

Then in your UI, you'll need to capture the authorization code from the redirect 
and pass it to the connect method.
""") 