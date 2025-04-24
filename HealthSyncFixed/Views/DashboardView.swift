import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = HealthSyncViewModel()
    
    var body: some View {
        TabView {
            HomeView(viewModel: viewModel)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            TrackingView(viewModel: viewModel)
                .tabItem {
                    Label("Track", systemImage: "chart.bar.fill")
                }
            
            InsightsView(viewModel: viewModel)
                .tabItem {
                    Label("Insights", systemImage: "brain.head.profile")
                }
            
            SettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .accentColor(.blue)
    }
}

struct HomeView: View {
    @ObservedObject var viewModel: HealthSyncViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // User Profile Header
                    if let profile = viewModel.userProfile {
                        UserProfileHeader(profile: profile)
                    }
                    
                    // Summary Stats
                    StatsSummaryCard(viewModel: viewModel)
                    
                    // Recovery & Strain Card
                    RecoveryCard(whoopMetrics: viewModel.whoopMetrics)
                    
                    // Fasting Timer
                    FastingTimerCard(
                        fastingWindow: viewModel.currentFastingWindow,
                        timeRemaining: viewModel.fastingTimeRemaining,
                        progress: viewModel.fastingProgress,
                        startFasting: viewModel.startFasting,
                        endFasting: viewModel.endFasting
                    )
                    
                    // Today's Plan
                    TodayPlanCard(
                        supplements: viewModel.todaySupplements,
                        insights: viewModel.aiInsights
                    )
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .navigationBarItems(trailing: notificationsButton)
            .background(colorScheme == .dark ? Color.black.opacity(0.9) : Color.gray.opacity(0.1))
        }
    }
    
    private var notificationsButton: some View {
        Button(action: {
            // Handle notifications
        }) {
            Image(systemName: "bell")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.blue)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color(.systemBackground)))
                .shadow(radius: 2)
        }
    }
}

struct UserProfileHeader: View {
    let profile: HealthData.UserProfile
    
    var body: some View {
        HStack(spacing: 15) {
            // Profile Image
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Text(initials)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Hello, \(profile.name)")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Age: \(profile.age)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                // Action to edit profile
            }) {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Circle().fill(Color.blue))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var initials: String {
        let components = profile.name.components(separatedBy: " ")
        if components.count > 1, 
           let first = components.first?.first, 
           let last = components.last?.first {
            return "\(first)\(last)"
        } else if let first = components.first?.first {
            return "\(first)"
        }
        return "?"
    }
}

struct StatsSummaryCard: View {
    @ObservedObject var viewModel: HealthSyncViewModel
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Today's Summary")
                .font(.headline)
            
            HStack(spacing: 20) {
                StatItem(
                    value: viewModel.whoopMetrics?.recovery.formatted(.number.precision(.fractionLength(0))) ?? "-",
                    label: "Recovery",
                    icon: "heart.fill",
                    color: .green
                )
                
                Divider().frame(height: 40)
                
                StatItem(
                    value: viewModel.whoopMetrics?.sleepPerformance.formatted(.number.precision(.fractionLength(0))) ?? "-",
                    label: "Sleep",
                    icon: "bed.double.fill",
                    color: .blue
                )
                
                Divider().frame(height: 40)
                
                StatItem(
                    value: viewModel.whoopMetrics?.strain.formatted(.number.precision(.fractionLength(1))) ?? "-",
                    label: "Strain",
                    icon: "figure.walk",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RecoveryCard: View {
    let whoopMetrics: HealthData.WhoopMetrics?
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Recovery & Strain")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    // Action to view details
                }) {
                    Label("Details", systemImage: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if let metrics = whoopMetrics {
                HStack(spacing: 30) {
                    // Recovery gauge
                    VStack {
                        ZStack {
                            Circle()
                                .stroke(lineWidth: 8)
                                .opacity(0.2)
                                .foregroundColor(recoveryColor(metrics.recovery))
                            
                            Circle()
                                .trim(from: 0.0, to: CGFloat(min(metrics.recovery / 100, 1.0)))
                                .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                                .foregroundColor(recoveryColor(metrics.recovery))
                                .rotationEffect(Angle(degrees: 270.0))
                                .animation(.linear, value: metrics.recovery)
                            
                            VStack(spacing: 2) {
                                Text("\(Int(metrics.recovery))%")
                                    .font(.system(size: 24, weight: .bold))
                                
                                Text("Recovery")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 100, height: 100)
                        
                        // Additional recovery metrics
                        HStack(spacing: 12) {
                            VStack {
                                Text("\(Int(metrics.hrv))")
                                    .font(.system(size: 15, weight: .medium))
                                Text("HRV")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                Text("\(Int(metrics.restingHeartRate))")
                                    .font(.system(size: 15, weight: .medium))
                                Text("RHR")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 8)
                    }
                    
                    // Strain gauge
                    VStack {
                        ZStack {
                            Circle()
                                .stroke(lineWidth: 8)
                                .opacity(0.2)
                                .foregroundColor(.blue)
                            
                            Circle()
                                .trim(from: 0.0, to: CGFloat(min(metrics.strain / 21, 1.0)))
                                .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                                .foregroundColor(.blue)
                                .rotationEffect(Angle(degrees: 270.0))
                                .animation(.linear, value: metrics.strain)
                            
                            VStack(spacing: 2) {
                                Text(String(format: "%.1f", metrics.strain))
                                    .font(.system(size: 24, weight: .bold))
                                
                                Text("Strain")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 100, height: 100)
                        
                        // Strain progress
                        Text(strainDescription(metrics.strain))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Loading metrics...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 3)
    }
    
    private func recoveryColor(_ recovery: Double) -> Color {
        switch recovery {
        case 0..<33: return .red
        case 33..<66: return .orange
        default: return .green
        }
    }
    
    private func strainDescription(_ strain: Double) -> String {
        switch strain {
        case 0..<8: return "Light Activity"
        case 8..<14: return "Moderate Effort"
        case 14..<18: return "Strenuous"
        default: return "All Out"
        }
    }
}

struct FastingTimerCard: View {
    let fastingWindow: HealthData.FastingWindow?
    let timeRemaining: String
    let progress: Double
    let startFasting: () -> Void
    let endFasting: () -> Void
    @State private var showOptionsSheet = false
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Fasting Timer")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    showOptionsSheet = true
                }) {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                }
                .sheet(isPresented: $showOptionsSheet) {
                    FastingOptionsView(isPresented: $showOptionsSheet)
                }
            }
            
            if let window = fastingWindow {
                VStack(spacing: 15) {
                    // Timer display
                    ZStack {
                        Circle()
                            .stroke(lineWidth: 12)
                            .opacity(0.1)
                            .foregroundColor(.blue)
                        
                        Circle()
                            .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                            .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                            .foregroundColor(progressColor(progress))
                            .rotationEffect(Angle(degrees: 270.0))
                            .animation(.linear, value: progress)
                        
                        VStack {
                            Text(timeRemaining)
                                .font(.system(size: 36, weight: .bold))
                                .monospacedDigit()
                            
                            Text("Until \(isInFastingWindow(window) ? "Eating Window" : "Fasting Window")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(height: 160)
                    .padding(.vertical)
                    
                    // Fasting period details
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Started")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatTime(window.startTime))
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Ends")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatTime(window.endTime))
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Control button
                    Button(action: {
                        if isInFastingWindow(window) && !window.completed {
                            endFasting()
                        } else {
                            startFasting()
                        }
                    }) {
                        Text(isInFastingWindow(window) && !window.completed ? "End Fast" : "Start Fast")
                            .fontWeight(.medium)
                            .frame(minWidth: 140)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background(isInFastingWindow(window) && !window.completed ? Color.red : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(25)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 10)
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "timer")
                        .font(.system(size: 50))
                        .foregroundColor(.blue.opacity(0.6))
                    
                    Text("No Active Fast")
                        .font(.system(size: 24))
                    
                    Text("Start a fasting window to begin tracking your progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: startFasting) {
                        Text("Start Fast")
                            .fontWeight(.medium)
                            .frame(minWidth: 140)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(25)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 10)
                }
                .padding()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 3)
    }
    
    private func isInFastingWindow(_ window: HealthData.FastingWindow) -> Bool {
        guard !window.completed else { return false }
        
        let now = Date()
        return now >= window.startTime && now <= window.endTime
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func progressColor(_ progress: Double) -> Color {
        if progress < 0.3 {
            return .red
        } else if progress < 0.7 {
            return .orange
        } else {
            return .green
        }
    }
}

struct FastingOptionsView: View {
    @Binding var isPresented: Bool
    
    let fastingProtocols = [
        ("16:8 Intermittent", "16 hours fasting, 8 hours eating"),
        ("18:6 Intermittent", "18 hours fasting, 6 hours eating"),
        ("20:4 Warrior Diet", "20 hours fasting, 4 hours eating"),
        ("5:2 Diet", "5 days normal eating, 2 days restricted"),
        ("OMAD", "One meal a day in a 1-hour window")
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Fasting Protocols")) {
                    ForEach(fastingProtocols, id: \.0) { protocol in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(protocol.0)
                                .font(.headline)
                            Text(protocol.1)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("Custom Fasting")) {
                    Button(action: {
                        // Custom fasting option
                        isPresented = false
                    }) {
                        Text("Set Custom Hours")
                            .foregroundColor(.blue)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Fasting Options")
            .navigationBarItems(trailing: Button("Done") {
                isPresented = false
            })
        }
    }
}

struct TodayPlanCard: View {
    let supplements: [HealthData.SupplementLog]
    let insights: [HealthData.CoachingInsight]
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Today's Plan")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    // View all plan details
                }) {
                    Text("View All")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // Tab selector
            Picker("Plan Type", selection: $selectedTab) {
                Text("Supplements").tag(0)
                Text("Insights").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.vertical, 5)
            
            if selectedTab == 0 {
                supplementsView
            } else {
                insightsView
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 3)
    }
    
    private var supplementsView: some View {
        VStack(spacing: 10) {
            if supplements.isEmpty {
                emptyStateView(
                    icon: "pills",
                    title: "No Supplements",
                    description: "You don't have any supplements scheduled for today"
                )
            } else {
                ForEach(supplements, id: \.timeToTake) { supplement in
                    HStack(spacing: 15) {
                        // Time indicator
                        ZStack {
                            Circle()
                                .fill(supplement.taken ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                                .frame(width: 40, height: 40)
                            
                            Text(timeString(supplement.timeToTake))
                                .font(.caption2)
                                .foregroundColor(supplement.taken ? .green : .blue)
                        }
                        
                        // Supplement details
                        VStack(alignment: .leading, spacing: 2) {
                            Text(supplement.name)
                                .fontWeight(.medium)
                            
                            Text(supplement.dosage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Taken/not taken indicator
                        Image(systemName: supplement.taken ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(supplement.taken ? .green : .gray)
                            .font(.system(size: 22))
                    }
                    .padding(.vertical, 6)
                    
                    if supplement != supplements.last {
                        Divider()
                    }
                }
            }
        }
    }
    
    private var insightsView: some View {
        VStack(spacing: 12) {
            if insights.isEmpty {
                emptyStateView(
                    icon: "brain",
                    title: "No Insights Yet",
                    description: "As you use the app, personalized insights will appear here"
                )
            } else {
                ForEach(insights, id: \.date) { insight in
                    HStack(alignment: .top, spacing: 15) {
                        // Icon
                        Image(systemName: insightIcon(for: insight.type))
                            .font(.system(size: 16))
                            .foregroundColor(insightColor(for: insight.type))
                            .frame(width: 32, height: 32)
                            .background(insightColor(for: insight.type).opacity(0.2))
                            .clipShape(Circle())
                        
                        // Content
                        VStack(alignment: .leading, spacing: 5) {
                            Text(insightTitle(for: insight.type))
                                .font(.system(size: 15, weight: .semibold))
                            
                            Text(insight.message)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            if insight.actionRequired {
                                Button(action: {
                                    // Handle action
                                }) {
                                    Text("Take Action")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(insightColor(for: insight.type))
                                        .cornerRadius(12)
                                }
                                .padding(.top, 5)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    
                    if insight.date != insights.last?.date {
                        Divider()
                    }
                }
            }
        }
    }
    
    private func emptyStateView(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.7))
                .padding(.bottom, 5)
            
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
    
    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func insightIcon(for type: String) -> String {
        switch type {
        case "recovery": return "heart.fill"
        case "sleep": return "bed.double.fill"
        case "nutrition": return "fork.knife"
        case "workout": return "figure.walk"
        default: return "lightbulb.fill"
        }
    }
    
    private func insightColor(for type: String) -> Color {
        switch type {
        case "recovery": return .red
        case "sleep": return .blue
        case "nutrition": return .green
        case "workout": return .orange
        default: return .yellow
        }
    }
    
    private func insightTitle(for type: String) -> String {
        switch type {
        case "recovery": return "Recovery Insight"
        case "sleep": return "Sleep Recommendation"
        case "nutrition": return "Nutrition Tip"
        case "workout": return "Workout Suggestion"
        default: return "Health Insight"
        }
    }
}

// These are placeholder views that we'll implement in Sprint 2
struct TrackingView: View {
    @ObservedObject var viewModel: HealthSyncViewModel
    
    var body: some View {
        NavigationView {
            Text("Tracking View - Coming soon")
                .navigationTitle("Track")
        }
    }
}

struct InsightsView: View {
    @ObservedObject var viewModel: HealthSyncViewModel
    
    var body: some View {
        NavigationView {
            Text("Insights View - Coming soon")
                .navigationTitle("Insights")
        }
    }
}

// SettingsView is now in a separate file: SettingsView.swift

// Preview Provider
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}