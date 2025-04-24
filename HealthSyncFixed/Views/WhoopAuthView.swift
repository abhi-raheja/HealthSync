import SwiftUI

struct WhoopAuthView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var whoopService = WhoopService.shared
    @State private var isAuthenticating = false
    @State private var errorMessage: String? = nil
    @State private var showError = false
    @State private var showSettingsAlert = false
    
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
        if Config.Whoop.clientId == "YOUR_CLIENT_ID" || Config.Whoop.clientSecret == "YOUR_CLIENT_SECRET" {
            showSettingsAlert = true
            return
        }
        
        isAuthenticating = true
        errorMessage = nil
        
        Task {
            do {
                let success = try await whoopService.connect()
                DispatchQueue.main.async {
                    isAuthenticating = false
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
        // This would trigger a refresh of WHOOP data
        // For now it's just a placeholder
    }
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #endif
    }
} 