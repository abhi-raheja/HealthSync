import SwiftUI

@main
struct HealthSyncApp: App {
    @State private var showTestAuth = true // Set to true to test WHOOP auth
    
    // Initialize CoreData Manager to ensure it's loaded at app startup
    init() {
        // Access CoreDataManager to ensure it's initialized
        _ = CoreDataManager.shared
        print("HealthSync App Initializing")
    }
    
    var body: some Scene {
        WindowGroup {
            if showTestAuth {
                TestWhoopAuthView()
                    .onDisappear {
                        showTestAuth = false
                    }
            } else {
                DashboardView()
            }
        }
    }
} 