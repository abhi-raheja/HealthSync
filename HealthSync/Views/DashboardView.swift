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
                    FastingTimerCard(fastingWindow: viewModel.currentFastingWindow)
                    
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
                        Text("Recovery")
                            .font(.caption)
                    }
                    
                    Divider()
                    
                    VStack {
                        Text("\(Int(metrics.strain))")
                            .font(.system(size: 36, weight: .bold))
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
}

struct FastingTimerCard: View {
    let fastingWindow: HealthData.FastingWindow?
    
    var body: some View {
        VStack {
            Text("Fasting Timer")
                .font(.headline)
            
            if let window = fastingWindow {
                VStack {
                    Text(timeRemaining(window))
                        .font(.system(size: 48, weight: .bold))
                    
                    Text("Until \(isInFastingWindow(window) ? "Eating Window" : "Fasting Window")")
                        .font(.caption)
                }
            } else {
                Text("Set up fasting window")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
    
    private func timeRemaining(_ window: HealthData.FastingWindow) -> String {
        // Implementation for calculating time remaining
        return "16:00:00"
    }
    
    private func isInFastingWindow(_ window: HealthData.FastingWindow) -> Bool {
        // Implementation for checking if currently in fasting window
        return true
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
                    Text("\(supplement.name) - \(supplement.dosage)")
                    Spacer()
                    Text(formatTime(supplement.timeToTake))
                        .font(.caption)
                }
            }
            
            Divider()
            
            // AI Insights
            ForEach(insights, id: \.date) { insight in
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text(insight.message)
                        .font(.subheadline)
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

// Preview Provider
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
