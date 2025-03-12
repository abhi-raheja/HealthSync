import SwiftUI

struct WatchDashboardView: View {
    @StateObject private var viewModel = WatchViewModel()
    
    var body: some View {
        TabView {
            // Quick Stats View
            FastingTimerView(viewModel: viewModel)
            
            // Quick Log View
            QuickLogView(viewModel: viewModel)
            
            // Metrics View
            MetricsView(viewModel: viewModel)
        }
        .tabViewStyle(PageTabViewStyle())
    }
}

struct FastingTimerView: View {
    @ObservedObject var viewModel: WatchViewModel
    
    var body: some View {
        VStack {
            Text(viewModel.fastingTimeRemaining)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(viewModel.isInFastingWindow ? .green : .orange)
            
            Text(viewModel.isInFastingWindow ? "Fasting" : "Eating Window")
                .font(.caption2)
            
            Button(action: viewModel.toggleFastingState) {
                Text(viewModel.isInFastingWindow ? "End Fast" : "Start Fast")
                    .font(.caption)
                    .padding(.vertical, 8)
            }
        }
    }
}

struct QuickLogView: View {
    @ObservedObject var viewModel: WatchViewModel
    
    var body: some View {
        List {
            Section(header: Text("Quick Log")) {
                Button(action: { viewModel.logMeal() }) {
                    Label("Log Meal", systemImage: "fork.knife")
                }
                
                Button(action: { viewModel.logSupplements() }) {
                    Label("Log Supplements", systemImage: "pills")
                }
                
                Button(action: { viewModel.startWorkout() }) {
                    Label("Start Workout", systemImage: "figure.walk")
                }
            }
        }
    }
}

struct MetricsView: View {
    @ObservedObject var viewModel: WatchViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                MetricCard(
                    title: "Recovery",
                    value: "\(Int(viewModel.recovery))%",
                    color: recoveryColor
                )
                
                MetricCard(
                    title: "Strain",
                    value: String(format: "%.1f", viewModel.strain),
                    color: .blue
                )
                
                MetricCard(
                    title: "HRV",
                    value: "\(Int(viewModel.hrv)) ms",
                    color: .purple
                )
            }
            .padding()
        }
    }
    
    private var recoveryColor: Color {
        switch viewModel.recovery {
        case 0..<33: return .red
        case 33..<66: return .yellow
        default: return .green
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption2)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }
}

class WatchViewModel: ObservableObject {
    @Published var fastingTimeRemaining: String = "--:--:--"
    @Published var isInFastingWindow: Bool = false
    @Published var recovery: Double = 0
    @Published var strain: Double = 0
    @Published var hrv: Double = 0
    
    // MARK: - Actions
    func toggleFastingState() {
        isInFastingWindow.toggle()
        // Implement fasting state toggle logic
    }
    
    func logMeal() {
        // Implement meal logging
    }
    
    func logSupplements() {
        // Implement supplement logging
    }
    
    func startWorkout() {
        // Implement workout start
    }
    
    // MARK: - Data Sync
    private func syncWithPhone() {
        // Implement WCSession sync
    }
}
