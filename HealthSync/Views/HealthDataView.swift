import SwiftUI

struct HealthDataView: View {
    @EnvironmentObject private var viewModel: HealthSyncViewModel
    @State private var isRefreshing = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                headerView
                
                // Activity summary
                activitySummaryView
                
                // Recent workouts
                workoutsView
                
                // Sleep data
                sleepDataView
                
                // Health metrics
                healthMetricsView
            }
            .padding()
        }
        .navigationTitle("Health Data")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: refreshData) {
                    if isRefreshing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(isRefreshing)
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            if viewModel.isHealthKitAuthorized {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("HealthKit Connected")
                        .font(.headline)
                }
                
                Text("Your health data is synced and up to date")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("HealthKit Not Authorized")
                        .font(.headline)
                }
                
                Text("Grant access to your health data in Settings")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button("Request Access") {
                    requestHealthKitAccess()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var activitySummaryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Activity")
                .font(.headline)
            
            if let activity = viewModel.todayActivity {
                HStack(spacing: 20) {
                    activityMetricView(
                        icon: "flame.fill",
                        color: .orange,
                        value: "\(Int(activity.activeEnergyBurned))",
                        unit: "kcal"
                    )
                    
                    activityMetricView(
                        icon: "figure.walk",
                        color: .green,
                        value: "\(activity.steps)",
                        unit: "steps"
                    )
                    
                    activityMetricView(
                        icon: "clock",
                        color: .blue,
                        value: "\(activity.exerciseMinutes)",
                        unit: "min"
                    )
                }
                .padding(.vertical, 8)
            } else {
                Text("No activity data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func activityMetricView(icon: String, color: Color, value: String, unit: String) -> some View {
        VStack {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var workoutsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Workouts")
                .font(.headline)
            
            if viewModel.recentWorkouts.isEmpty {
                Text("No recent workouts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.recentWorkouts.prefix(3), id: \.startTime) { workout in
                    workoutRowView(workout: workout)
                }
                
                if viewModel.recentWorkouts.count > 3 {
                    Button(action: {
                        // Navigate to detailed workout list
                    }) {
                        Text("See all workouts")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func workoutRowView(workout: HealthData.WorkoutSession) -> some View {
        HStack {
            // Workout type icon
            Image(systemName: workoutIcon(for: workout.type))
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            // Workout details
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.type)
                    .font(.headline)
                
                Text(formatDate(workout.startTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Workout stats
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(workout.caloriesBurned)) kcal")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(formatDuration(from: workout.startTime, to: workout.endTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var sleepDataView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Night's Sleep")
                .font(.headline)
            
            if let sleep = viewModel.lastNightSleep {
                // Sleep summary
                HStack(spacing: 20) {
                    sleepMetricView(
                        value: formatTimeInterval(sleep.duration),
                        label: "Duration"
                    )
                    
                    sleepMetricView(
                        value: "\(Int(sleep.quality))%",
                        label: "Quality"
                    )
                    
                    sleepMetricView(
                        value: formatTimeInterval(sleep.stages.deep),
                        label: "Deep"
                    )
                }
                
                // Sleep stages chart
                sleepStagesView(stages: sleep.stages)
            } else {
                Text("No sleep data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func sleepMetricView(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func sleepStagesView(stages: HealthData.SleepStages) -> some View {
        HStack(spacing: 0) {
            // Simplified bar chart showing sleep stages
            sleepStageBar(width: stages.deepPercentage, color: .indigo, label: "Deep")
            sleepStageBar(width: stages.remPercentage, color: .blue, label: "REM")
            sleepStageBar(width: stages.lightPercentage, color: .teal, label: "Light")
            sleepStageBar(width: stages.awakePercentage, color: .gray, label: "Awake")
        }
        .frame(height: 30)
        .cornerRadius(6)
        .padding(.top, 8)
    }
    
    private func sleepStageBar(width: Double, color: Color, label: String) -> some View {
        VStack(alignment: .center) {
            Rectangle()
                .fill(color)
                .frame(width: max(width, 0.1) * 3, height: 20) // Scale by 3 for visibility
            
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
    }
    
    private var healthMetricsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Metrics")
                .font(.headline)
            
            // WHOOP metrics
            if let metrics = viewModel.whoopMetrics {
                HStack(spacing: 12) {
                    healthMetricView(
                        icon: "heart.fill",
                        color: .red,
                        value: "\(Int(metrics.restingHeartRate))",
                        unit: "bpm",
                        label: "Resting HR"
                    )
                    
                    healthMetricView(
                        icon: "waveform.path.ecg",
                        color: .green,
                        value: "\(Int(metrics.hrv))",
                        unit: "ms",
                        label: "HRV"
                    )
                }
                
                HStack(spacing: 12) {
                    healthMetricView(
                        icon: "chart.bar.fill",
                        color: .orange,
                        value: String(format: "%.1f", metrics.strain),
                        unit: "",
                        label: "Strain"
                    )
                    
                    healthMetricView(
                        icon: "battery.100",
                        color: .blue,
                        value: "\(Int(metrics.recovery))",
                        unit: "%",
                        label: "Recovery"
                    )
                }
            } else {
                Text("No health metrics available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func healthMetricView(icon: String, color: Color, value: String, unit: String, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Methods
    
    private func refreshData() {
        isRefreshing = true
        
        viewModel.refreshHealthData()
        
        // Simulate delay for UI feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isRefreshing = false
        }
    }
    
    private func requestHealthKitAccess() {
        // Request HealthKit authorization
        viewModel.setupHealthKitAuthorization()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(from start: Date, to end: Date) -> String {
        let duration = end.timeIntervalSince(start)
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func workoutIcon(for workoutType: String) -> String {
        switch workoutType.lowercased() {
        case "running":
            return "figure.run"
        case "cycling":
            return "figure.outdoor.cycle"
        case "swimming":
            return "figure.pool.swim"
        case "walking":
            return "figure.walk"
        case "hiking":
            return "figure.hiking"
        case "strength training", "weight training":
            return "dumbbell"
        case "yoga":
            return "figure.mind.and.body"
        case "hiit", "functional training":
            return "figure.highintensity.intervaltraining"
        default:
            return "figure.mixed.cardio"
        }
    }
}

struct HealthDataView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HealthDataView()
                .environmentObject(previewViewModel())
        }
    }
    
    static func previewViewModel() -> HealthSyncViewModel {
        let viewModel = HealthSyncViewModel()
        
        // Mock data for preview
        viewModel.todayActivity = HealthData.ActivitySummary.preview
        viewModel.lastNightSleep = HealthData.SleepData.preview
        viewModel.whoopMetrics = HealthData.WhoopMetrics.preview
        viewModel.recentWorkouts = [
            HealthData.WorkoutSession.preview
        ]
        
        return viewModel
    }
} 