import SwiftUI
import SafariServices
import AuthenticationServices

struct WhoopAuthView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var whoopService = WhoopService.shared
    @State private var isAuthenticating = false
    @State private var errorMessage: String? = nil
    @State private var showError = false
    @State private var showSettingsAlert = false
    @State private var showAuthWebView = false
    @State private var authURL: URL? = nil
    @State private var authorizationCode: String = ""
    @State private var showAuthCodeInput = false
    @State private var stateValue: String = UUID().uuidString
    @State private var showSuccessAlert = false
    @State private var authSession: ASWebAuthenticationSession?
    
    private let redirectURI = "https://abhiraheja.com"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerView
                    
                    Divider()
                    
                    // Connection status
                    connectionStatusView
                    
                    Spacer(minLength: 20)
                    
                    // Authorization code input (if applicable)
                    if showAuthCodeInput {
                        authCodeInputView
                    }
                    
                    // Actions
                    actionButtonsView
                    
                    Spacer(minLength: 40)
                    
                    // Info
                    infoView
                }
                .padding()
                .alert(isPresented: $showError) {
                    Alert(
                        title: Text("Authentication Error"),
                        message: Text(errorMessage ?? "Unknown error occurred"),
                        dismissButton: .default(Text("OK"))
                    )
                }
                .alert(isPresented: $showSettingsAlert) {
                    Alert(
                        title: Text("API Credentials Missing"),
                        message: Text("Please set your WHOOP API client ID and client secret in Config.swift"),
                        primaryButton: .default(Text("How to Get Credentials")) {
                            // Open URL to documentation
                            openURL("https://developer.whoop.com/docs")
                        },
                        secondaryButton: .cancel(Text("Cancel"))
                    )
                }
                .alert(isPresented: $showSuccessAlert) {
                    Alert(
                        title: Text("Authentication Successful"),
                        message: Text("You have successfully connected your WHOOP account."),
                        dismissButton: .default(Text("OK"))
                    )
                }
                .sheet(isPresented: $showAuthWebView, onDismiss: {
                    // If we're not using ASWebAuthenticationSession, show manual input
                    if !ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"].flatMap(Bool.init) ?? false {
                        showAuthCodeInput = true
                    }
                }) {
                    if let url = authURL {
                        SafariView(url: url)
                    } else {
                        Text("Error: Unable to generate authorization URL")
                    }
                }
            }
            .navigationTitle("WHOOP Connection")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    // MARK: - Component Views
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Connect your WHOOP account")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Connect HealthSync to your WHOOP account to sync your recovery, strain, sleep, and workout data.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }
    
    private var connectionStatusView: some View {
        HStack(spacing: 15) {
            // Status icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 20))
                    .foregroundColor(statusColor)
            }
            
            // Status text
            VStack(alignment: .leading, spacing: 2) {
                Text("Connection Status")
                    .font(.headline)
                
                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var authCodeInputView: some View {
        VStack(spacing: 10) {
            Text("Enter Authorization Code")
                .font(.headline)
            
            Text("After authorizing in the browser, copy the code from the URL and paste it below.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Look for a URL like: \(redirectURI)?code=YOUR_CODE")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 5)
            
            TextField("Authorization Code", text: $authorizationCode)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            
            Button("Submit Code") {
                connectWithCode()
            }
            .disabled(authorizationCode.isEmpty || isAuthenticating)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(authorizationCode.isEmpty ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Try Again") {
                showAuthCodeInput = false
                connect()
            }
            .padding(.top, 10)
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 15) {
            if whoopService.isConnected {
                // Disconnect button
                Button(action: disconnect) {
                    HStack {
                        Spacer()
                        Text("Disconnect")
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                // Refresh data button
                Button(action: refreshData) {
                    HStack {
                        Spacer()
                        Text("Refresh Data")
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isAuthenticating)
            } else {
                // Connect button
                Button(action: connect) {
                    HStack {
                        Spacer()
                        
                        if isAuthenticating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 10)
                        }
                        
                        Text(isAuthenticating ? "Connecting..." : "Connect to WHOOP")
                            .fontWeight(.medium)
                        
                        Spacer()
                    }
                    .padding()
                    .background(isAuthenticating ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isAuthenticating)
            }
        }
    }
    
    private var infoView: some View {
        VStack(spacing: 15) {
            Text("How it Works")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 10) {
                infoRow(
                    icon: "key.fill",
                    color: .blue,
                    title: "Secure Access",
                    description: "HealthSync uses OAuth2 to securely connect to your WHOOP account."
                )
                
                infoRow(
                    icon: "lock.fill",
                    color: .green,
                    title: "Privacy",
                    description: "Your credentials are never stored. Only access tokens are securely saved."
                )
                
                infoRow(
                    icon: "arrow.triangle.2.circlepath",
                    color: .orange,
                    title: "Data Sync",
                    description: "Your WHOOP data is synced periodically to provide up-to-date insights."
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
    }
    
    private func infoRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    // MARK: - Helper properties
    
    private var statusColor: Color {
        switch whoopService.connectionStatus {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .error:
            return .red
        case .disconnected:
            return .gray
        }
    }
    
    private var statusIcon: String {
        switch whoopService.connectionStatus {
        case .connected:
            return "checkmark.circle.fill"
        case .connecting:
            return "arrow.clockwise"
        case .error:
            return "exclamationmark.triangle.fill"
        case .disconnected:
            return "xmark.circle.fill"
        }
    }
    
    private var statusText: String {
        switch whoopService.connectionStatus {
        case .connected:
            return "Connected to WHOOP"
        case .connecting:
            return "Connecting to WHOOP..."
        case .error(let message):
            return "Error: \(message)"
        case .disconnected:
            return "Not connected"
        }
    }
    
    // MARK: - Actions
    
    private func connect() {
        // Check if API credentials are set
        if Config.Whoop.clientId.isEmpty || Config.Whoop.clientSecret.isEmpty ||
           Config.Whoop.clientId == "YOUR_CLIENT_ID" || Config.Whoop.clientSecret == "YOUR_CLIENT_SECRET" {
            showSettingsAlert = true
            return
        }
        
        stateValue = UUID().uuidString
        
        // Generate authorization URL
        authURL = whoopService.generateAuthorizationURL(redirectURI: redirectURI, state: stateValue)
        
        if let authURL = authURL {
            if !ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"].flatMap(Bool.init) ?? false {
                // Use ASWebAuthenticationSession for better OAuth flow handling
                authSession = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: URL(string: redirectURI)?.scheme
                ) { callbackURL, error in
                    if let error = error {
                        self.errorMessage = "Authentication failed: \(error.localizedDescription)"
                        self.showError = true
                        return
                    }
                    
                    guard let callbackURL = callbackURL else {
                        self.errorMessage = "No callback URL received"
                        self.showError = true
                        return
                    }
                    
                    // Extract the code from the URL
                    guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: true),
                          let queryItems = components.queryItems else {
                        self.errorMessage = "Invalid callback URL"
                        self.showError = true
                        return
                    }
                    
                    // Get authorization code and state
                    if let codeItem = queryItems.first(where: { $0.name == "code" }),
                       let code = codeItem.value,
                       let stateItem = queryItems.first(where: { $0.name == "state" }),
                       let state = stateItem.value {
                        
                        // Verify state to prevent CSRF attacks
                        if state != self.stateValue {
                            self.errorMessage = "Invalid state parameter"
                            self.showError = true
                            return
                        }
                        
                        // Use the code
                        self.authorizationCode = code
                        self.connectWithCode()
                    } else {
                        self.errorMessage = "No authorization code found in callback URL"
                        self.showError = true
                    }
                }
                
                authSession?.presentationContextProvider = ASPresentationAnchor()
                authSession?.prefersEphemeralWebBrowserSession = true
                authSession?.start()
            } else {
                // Fallback to SafariView for SwiftUI previews
                showAuthWebView = true
            }
        } else {
            errorMessage = "Failed to generate authorization URL"
            showError = true
        }
    }
    
    private func connectWithCode() {
        guard !authorizationCode.isEmpty else { return }
        
        isAuthenticating = true
        errorMessage = nil
        
        Task {
            do {
                let success = try await whoopService.connect(withCode: authorizationCode, redirectURI: redirectURI)
                DispatchQueue.main.async {
                    isAuthenticating = false
                    showAuthCodeInput = false
                    if success {
                        showSuccessAlert = true
                    } else {
                        errorMessage = "Authentication failed"
                        showError = true
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isAuthenticating = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func disconnect() {
        whoopService.disconnect()
    }
    
    private func refreshData() {
        // Fetch latest data from WHOOP
        Task {
            isAuthenticating = true
            
            do {
                // Example: Fetch recovery data
                let metrics = try await whoopService.fetchDailyMetrics()
                print("Successfully fetched updated WHOOP data")
                
                DispatchQueue.main.async {
                    isAuthenticating = false
                }
            } catch {
                DispatchQueue.main.async {
                    isAuthenticating = false
                    errorMessage = "Failed to refresh data: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #endif
    }
}

// Safari view for authorization
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {
        // Nothing to do here
    }
}

// Helper for ASWebAuthenticationSession
class ASPresentationAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
} 