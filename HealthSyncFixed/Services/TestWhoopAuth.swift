import Foundation
import SwiftUI

// This is a simple test view to check if WHOOP authentication works
struct TestWhoopAuthView: View {
    @State private var authStatus = "Not tested"
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("WHOOP Auth Test")
                .font(.title)
            
            Text("Status: \(authStatus)")
                .foregroundColor(statusColor)
            
            if isLoading {
                ProgressView()
            }
            
            Button("Test Authentication") {
                testWhoopAuth()
            }
            .disabled(isLoading)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
    
    private var statusColor: Color {
        switch authStatus {
        case "Success":
            return .green
        case "Failed":
            return .red
        default:
            return .gray
        }
    }
    
    private func testWhoopAuth() {
        isLoading = true
        authStatus = "Testing..."
        
        Task {
            do {
                let success = try await WhoopService.shared.connect()
                DispatchQueue.main.async {
                    authStatus = success ? "Success" : "Failed"
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    authStatus = "Failed: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    TestWhoopAuthView()
} 