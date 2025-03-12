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
    }
}

struct HomeView: View {
    @ObservedObject var viewModel: HealthSyncViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
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
        }
    }
}

struct RecoveryCard: View {
    let whoopMetrics: HealthData.WhoopMetrics?
    
    var body: some View {
        VStack {
            Text("Recovery & Strain")
                .font(.headline)
            
            if let metrics = whoopMetrics {
                HStack {
                    VStack {
                        Text("\(Int(metrics.recovery))%")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(recoveryColor(metrics.recovery))
                        Text("Recovery")
                            .font(.caption)
                    }
                    
                    Divider()
                    
                    VStack {
                        Text("\(Int(metrics.strain))")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.blue)
                        Text("Day Strain")
                            .font(.caption)
                    }
                }
            } else {
                Text("Loading metrics...")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
    
    private func recoveryColor(_ recovery: Double) -> Color {
        switch recovery {
        case 0..<33: return .red
        case 33..<66: return .yellow
        default: return .green
        }
    }
}

struct FastingTimerCard: View {
    let fastingWindow: HealthData.FastingWindow?
    let timeRemaining: String
    let progress: Double
    let startFasting: () -> Void
    let endFasting: () -> Void
    
    var body: some View {
        VStack {
            Text("Fasting Timer")
                .font(.headline)
            
            if let window = fastingWindow {
                VStack(spacing: 15) {
                    Text(timeRemaining)
                        .font(.system(size: 48, weight: .bold))
                    
                    Text("Until \(isInFastingWindow(window) ? "Eating Window" : "Fasting Window")")
                        .font(.caption)
                    
                    // Progress bar
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
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
                            .frame(minWidth: 120)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            } else {
                VStack(spacing: 15) {
                    Text("No Active Fast")
                        .font(.system(size: 24))
                    
                    Button(action: startFasting) {
                        Text("Start Fast")
                            .fontWeight(.medium)
                            .frame(minWidth: 120)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
    
    private func isInFastingWindow(_ window: HealthData.FastingWindow) -> Bool {
        guard !window.completed else { return false }
        
        let now = Date()
        return now >= window.startTime && now <= window.endTime
    }
}

struct TodayPlanCard: View {
    let supplements: [HealthData.SupplementLog]
    let insights: [HealthData.CoachingInsight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Today's Plan")
                .font(.headline)
            
            // Supplements
            ForEach(supplements, id: \.timeToTake) { supplement in
                HStack {
                    Image(systemName: supplement.taken ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(supplement.taken ? .green : .gray)
                    Text("\(supplement.name) - \(supplement.dosage)")
                    Spacer()
                    Text(formatTime(supplement.timeToTake))
                        .font(.caption)
                }
            }
            
            Divider()
            
            // AI Insights
            if insights.isEmpty {
                Text("No insights available yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(insights, id: \.date) { insight in
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text(insight.message)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
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

struct SettingsView: View {
    @ObservedObject var viewModel: HealthSyncViewModel
    
    var body: some View {
        NavigationView {
            Text("Settings View - Coming soon")
                .navigationTitle("Settings")
        }
    }
}

// Preview Provider
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}