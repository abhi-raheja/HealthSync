import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: HealthSyncViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var showingProfileEditor = false
    @State private var showingAboutSheet = false
    @State private var showingWhoopAuthView = false
    @State private var notificationsEnabled = true
    @State private var syncFrequency = 2 // 0: 15min, 1: 30min, 2: 1hr, 3: 3hr
    @State private var useMetricSystem = true
    @State private var darkModeSelection = 0 // 0: System, 1: Light, 2: Dark
    @State private var isClearingCache = false
    
    var body: some View {
        NavigationView {
            List {
                // Profile Section
                Section(header: Text("Profile")) {
                    if let profile = viewModel.userProfile {
                        Button(action: {
                            showingProfileEditor = true
                        }) {
                            HStack {
                                // Profile Image
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                    
                                    Text(initials(from: profile.name))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name)
                                        .font(.headline)
                                    Text("Age: \(profile.age)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                        }
                        .sheet(isPresented: $showingProfileEditor) {
                            ProfileEditorView(profile: profile, isPresented: $showingProfileEditor)
                        }
                    } else {
                        Button("Create Profile") {
                            showingProfileEditor = true
                        }
                    }
                }
                
                // Connections Section
                Section(header: Text("Connections")) {
                    ConnectionRow(
                        title: "WHOOP",
                        icon: "heart.circle.fill",
                        iconColor: .red,
                        isConnected: WhoopService.shared.isConnected,
                        action: connectToWhoop
                    )
                    .sheet(isPresented: $showingWhoopAuthView) {
                        WhoopAuthView()
                    }
                    
                    ConnectionRow(
                        title: "Apple Health",
                        icon: "heart.text.square.fill",
                        iconColor: .green,
                        isConnected: true,
                        action: authorizeHealthKit
                    )
                    
                    ConnectionRow(
                        title: "Apple Watch",
                        icon: "applewatch",
                        iconColor: .blue,
                        isConnected: true,
                        action: {}
                    )
                }
                
                // Notifications Section
                Section(header: Text("Notifications")) {
                    Toggle("Push Notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { newValue in
                            requestNotificationPermission(enabled: newValue)
                        }
                    
                    if notificationsEnabled {
                        NavigationLink(destination: NotificationSettingsView()) {
                            Text("Customize Notifications")
                        }
                    }
                }
                
                // Appearance Section
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $darkModeSelection) {
                        Text("System").tag(0)
                        Text("Light").tag(1)
                        Text("Dark").tag(2)
                    }
                    
                    Toggle("Use Metric System", isOn: $useMetricSystem)
                }
                
                // Data & Sync Section
                Section(header: Text("Data & Sync")) {
                    Picker("Sync Frequency", selection: $syncFrequency) {
                        Text("15 minutes").tag(0)
                        Text("30 minutes").tag(1)
                        Text("1 hour").tag(2)
                        Text("3 hours").tag(3)
                    }
                    
                    Button(action: {
                        isClearingCache = true
                        // Simulate clearing cache
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isClearingCache = false
                        }
                    }) {
                        HStack {
                            Text("Clear Cache")
                            Spacer()
                            if isClearingCache {
                                ProgressView()
                            }
                        }
                    }
                    
                    NavigationLink(destination: DataExportView()) {
                        Text("Export Health Data")
                    }
                }
                
                // About & Help Section
                Section(header: Text("About & Help")) {
                    Button(action: {
                        showingAboutSheet = true
                    }) {
                        Label("About HealthSync", systemImage: "info.circle")
                    }
                    .sheet(isPresented: $showingAboutSheet) {
                        AboutView(isPresented: $showingAboutSheet)
                    }
                    
                    Link(destination: URL(string: "https://healthsync.app/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                    
                    Link(destination: URL(string: "https://healthsync.app/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text.fill")
                    }
                    
                    Link(destination: URL(string: "https://healthsync.app/support")!) {
                        Label("Help & Support", systemImage: "questionmark.circle.fill")
                    }
                }
                
                // Legal Section
                Section {
                    Text("Version 1.0 (Build 42)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Text("© 2023 HealthSync Inc. All rights reserved.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
        }
    }
    
    // Helper Methods
    
    private func initials(from name: String) -> String {
        let components = name.components(separatedBy: " ")
        if components.count > 1, 
           let first = components.first?.first, 
           let last = components.last?.first {
            return "\(first)\(last)"
        } else if let first = components.first?.first {
            return "\(first)"
        }
        return "?"
    }
    
    private func connectToWhoop() {
        showingWhoopAuthView = true
    }
    
    private func authorizeHealthKit() {
        // Implement HealthKit authorization flow
        print("Authorizing HealthKit...")
    }
    
    private func requestNotificationPermission(enabled: Bool) {
        if enabled {
            // Request notification permission
            print("Requesting notification permission...")
        } else {
            // Disable notifications
            print("Disabling notifications...")
        }
    }
}

// MARK: - Helper Views

struct ConnectionRow: View {
    let title: String
    let icon: String
    let iconColor: Color
    let isConnected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                    .frame(width: 30)
                
                Text(title)
                
                Spacer()
                
                HStack {
                    Circle()
                        .fill(isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    
                    Text(isConnected ? "Connected" : "Not Connected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Supplementary Views

struct ProfileEditorView: View {
    let profile: HealthData.UserProfile
    @Binding var isPresented: Bool
    @State private var name: String
    @State private var age: Int
    
    init(profile: HealthData.UserProfile, isPresented: Binding<Bool>) {
        self.profile = profile
        self._isPresented = isPresented
        self._name = State(initialValue: profile.name)
        self._age = State(initialValue: profile.age)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Information")) {
                    TextField("Name", text: $name)
                    
                    Stepper("Age: \(age)", value: $age, in: 18...100)
                }
                
                Section(header: Text("Health Metrics")) {
                    // Additional health metrics would go here
                    Text("Additional health metrics can be added here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button("Save Changes") {
                        // Save profile changes
                        isPresented = false
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Save") {
                    // Save profile changes
                    isPresented = false
                }
            )
        }
    }
}

struct NotificationSettingsView: View {
    @State private var fastingNotifications = true
    @State private var supplementReminders = true
    @State private var workoutReminders = true
    @State private var insightAlerts = true
    @State private var weeklyReports = true
    
    var body: some View {
        Form {
            Section(header: Text("Activity")) {
                Toggle("Fasting Notifications", isOn: $fastingNotifications)
                Toggle("Supplement Reminders", isOn: $supplementReminders)
                Toggle("Workout Reminders", isOn: $workoutReminders)
            }
            
            Section(header: Text("Insights & Reports")) {
                Toggle("Insight Alerts", isOn: $insightAlerts)
                Toggle("Weekly Reports", isOn: $weeklyReports)
            }
        }
        .navigationTitle("Notifications")
    }
}

struct DataExportView: View {
    @State private var exportFormat = 0 // 0: CSV, 1: JSON
    @State private var dateRange = 0 // 0: Last Week, 1: Last Month, 2: Last 3 Months, 3: All Time
    @State private var isExporting = false
    
    var body: some View {
        Form {
            Section(header: Text("Export Format")) {
                Picker("Format", selection: $exportFormat) {
                    Text("CSV").tag(0)
                    Text("JSON").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section(header: Text("Date Range")) {
                Picker("Time Period", selection: $dateRange) {
                    Text("Last Week").tag(0)
                    Text("Last Month").tag(1)
                    Text("Last 3 Months").tag(2)
                    Text("All Time").tag(3)
                }
            }
            
            Section {
                Button(action: {
                    isExporting = true
                    // Simulate export process
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isExporting = false
                    }
                }) {
                    HStack {
                        Spacer()
                        Group {
                            if isExporting {
                                ProgressView()
                                    .padding(.trailing, 10)
                                Text("Exporting...")
                            } else {
                                Text("Export Data")
                            }
                        }
                        Spacer()
                    }
                }
                .disabled(isExporting)
                
                Text("Your data will be exported as a file that you can download to your device.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Export Health Data")
    }
}

struct AboutView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(spacing: 20) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("HealthSync")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Version 1.0 (Build 42)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                
                Section(header: Text("About")) {
                    Text("HealthSync is an advanced health tracking application that integrates with WHOOP, Apple Health, and Apple Watch to provide personalized health insights and adaptive coaching.")
                        .font(.body)
                        .padding(.vertical, 8)
                }
                
                Section(header: Text("Features")) {
                    FeatureRow(icon: "arrow.triangle.2.circlepath", iconColor: .blue, title: "Data Integration", description: "Sync with WHOOP, Apple Health, and Apple Watch")
                    FeatureRow(icon: "timer", iconColor: .orange, title: "Fasting Tracker", description: "Track intermittent fasting windows and progress")
                    FeatureRow(icon: "pills", iconColor: .green, title: "Supplement Management", description: "Manage and track supplement schedules")
                    FeatureRow(icon: "brain", iconColor: .purple, title: "AI Coaching", description: "Receive personalized health insights and recommendations")
                }
                
                Section {
                    Button("Contact Support") {
                        // Open support contact
                    }
                    
                    Button("Rate the App") {
                        // Open App Store rating
                    }
                    
                    Button("Visit Website") {
                        // Open website
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("About")
            .navigationBarItems(trailing: Button("Done") {
                isPresented = false
            })
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(iconColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(viewModel: HealthSyncViewModel())
    }
} 