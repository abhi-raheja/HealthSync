import SwiftUI

/// Example view for testing the WHOOP authentication flow
struct WhoopAuthExample: View {
    @State private var whoopService = WhoopService.shared
    @State private var isAuthenticated = false
    @State private var showAuthView = false
    @State private var status = "Not connected"
    @State private var recoveryScore: Double? = nil
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Connection status
                connectionStatusView
                
                Divider()
                
                // Actions
                actionButtonsView
                
                Divider()
                
                // Data display
                dataView
                
                Spacer()
                
                // Instructions
                instructionsView
            }
            .padding()
            .navigationTitle("WHOOP Auth Test")
            .sheet(isPresented: $showAuthView) {
                WhoopAuthView()
            }
            .onAppear {
                updateStatus()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var connectionStatusView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection Status")
                .font(.headline)
            
            HStack(spacing: 12) {
                Circle()
                    .fill(isAuthenticated ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(status)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 16) {
            if isAuthenticated {
                Button(action: {
                    disconnect()
                }) {
                    Text("Disconnect from WHOOP")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    fetchData()
                }) {
                    HStack {
                        Text("Fetch Recovery Data")
                        
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isLoading)
            } else {
                Button(action: {
                    showAuthView = true
                }) {
                    Text("Connect to WHOOP")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
    }
    
    private var dataView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recovery Data")
                .font(.headline)
            
            if let recoveryScore = recoveryScore {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(lineWidth: 8)
                            .opacity(0.3)
                            .foregroundColor(.blue)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(recoveryScore / 100))
                            .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                            .foregroundColor(recoveryColor(for: recoveryScore))
                            .rotationEffect(Angle(degrees: 270.0))
                        
                        Text("\(Int(recoveryScore))%")
                            .font(.title2)
                            .bold()
                    }
                    .frame(width: 80, height: 80)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recovery Score")
                            .font(.headline)
                        
                        Text(recoveryDescription(for: recoveryScore))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                Text("Connect to WHOOP and fetch data to see your recovery score")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var instructionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Instructions")
                .font(.headline)
            
            Text("1. Connect to WHOOP using the button above")
            Text("2. Authenticate in the web browser")
            Text("3. After successful authentication, fetch your recovery data")
            Text("4. You can disconnect at any time")
        }
        .font(.footnote)
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func updateStatus() {
        self.isAuthenticated = whoopService.isConnected
        
        switch whoopService.connectionStatus {
        case .connected:
            status = "Connected to WHOOP"
        case .connecting:
            status = "Connecting..."
        case .disconnected:
            status = "Not connected"
        case .error(let message):
            status = "Error: \(message)"
        }
    }
    
    private func disconnect() {
        whoopService.disconnect()
        updateStatus()
        recoveryScore = nil
    }
    
    private func fetchData() {
        isLoading = true
        
        Task {
            do {
                let metrics = try await whoopService.fetchDailyMetrics()
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.recoveryScore = metrics.recovery
                    self.isLoading = false
                }
            } catch {
                // Handle error
                DispatchQueue.main.async {
                    self.status = "Error fetching data: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func recoveryColor(for score: Double) -> Color {
        switch score {
        case 0..<33:
            return .red
        case 33..<66:
            return .orange
        default:
            return .green
        }
    }
    
    private func recoveryDescription(for score: Double) -> String {
        switch score {
        case 0..<33:
            return "Poor recovery. Focus on rest today."
        case 33..<66:
            return "Moderate recovery. Approach training with caution."
        default:
            return "Good recovery. Your body is ready for performance."
        }
    }
}

// MARK: - Preview
struct WhoopAuthExample_Previews: PreviewProvider {
    static var previews: some View {
        WhoopAuthExample()
    }
} 