import SwiftUI

struct InstanceActivityChart: View {
    let activities: [InstanceActivity]
    let hourlyRate: Double
    
    @State private var selectedActivity: InstanceActivity?
    @State private var showingRuntime = true // Toggle between runtime and cost
    
    private let runtimeGradient = [
        Color(hex: "#4158D0"),
        Color(hex: "#C850C0"),
        Color(hex: "#FFCC70")
    ]
    
    private let costGradient = [
        Color(hex: "#11998e"),
        Color(hex: "#38ef7d")
    ]
    
    private var groupedActivities: [(date: Date, runtime: TimeInterval, cost: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        return (0...6).map { daysAgo -> (Date, TimeInterval, Double) in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: startOfToday)!
            let nextDate = calendar.date(byAdding: .day, value: 1, to: date)!
            
            // Get activities that started on this day
            let dayActivities = activities.filter {
                let activityDate = calendar.startOfDay(for: $0.timestamp)
                return activityDate == date
            }
            
            // Sum up the runtime and cost for activities that started on this day
            let runtime = dayActivities.reduce(0) { $0 + $1.runtime }
            let cost = dayActivities.reduce(0) { $0 + ($1.cost ?? 0) }
            
            return (date, runtime, cost)
        }.reversed()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
                Button(action: { showingRuntime.toggle() }) {
                    Text(showingRuntime ? "Show Cost" : "Show Runtime")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            }
            
            // Bar Chart
            VStack(spacing: 24) {
                BarChartView(
                    data: groupedActivities,
                    showingRuntime: showingRuntime,
                    gradient: showingRuntime ? runtimeGradient : costGradient
                )
                .frame(height: 200)
                
                // Last 10 Runtime Records
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Runtime Records")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(activities.prefix(10)) { activity in
                        RuntimeRecordRow(activity: activity)
                    }
                }
            }
            
            // Summary
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Total Runtime:")
                    Text(formatRuntime(groupedActivities.reduce(0) { $0 + $1.runtime }))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Total Cost:")
                    Text(formatCost(groupedActivities.reduce(0) { $0 + $1.cost }))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Avg Daily:")
                    Text(formatRuntime(groupedActivities.reduce(0) { $0 + $1.runtime } / 7))
                        .foregroundColor(.secondary)
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
    
    private func formatRuntime(_ runtime: TimeInterval) -> String {
        let hours = runtime / 3600
        return String(format: "%.1f hours", hours)
    }
    
    private func formatCost(_ cost: Double) -> String {
        return String(format: "$%.2f", cost)
    }
}

private struct BarChartView: View {
    let data: [(date: Date, runtime: TimeInterval, cost: Double)]
    let showingRuntime: Bool
    let gradient: [Color]
    
    private var maxValue: Double {
        if showingRuntime {
            return data.map { $0.runtime / 3600.0 }.max() ?? 24
        } else {
            return data.map { $0.cost }.max() ?? 1.0
        }
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(data, id: \.date) { item in
                VStack(spacing: 4) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: gradient),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: getBarHeight(for: showingRuntime ? item.runtime / 3600.0 : item.cost))
                            .frame(width: 30)
                        
                        Text(showingRuntime ? 
                            String(format: "%.1fh", item.runtime / 3600.0) :
                            String(format: "$%.2f", item.cost)
                        )
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.bottom, 4)
                    }
                    
                    VStack(spacing: 2) {
                        Text(formatWeekday(item.date))
                            .font(.caption2)
                        Text(formatDate(item.date))
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxHeight: 200)
        .padding(.bottom, 8)
    }
    
    private func getBarHeight(for value: Double) -> CGFloat {
        let percentage = value / maxValue
        return max(30, 180 * percentage)
    }
    
    private func formatWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

private struct RuntimeRecordRow: View {
    let activity: InstanceActivity
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDate(activity.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.1f hours", activity.runtime / 3600.0))
                    .font(.subheadline)
            }
            
            Spacer()
            
            if case let .stateChange(from, to) = activity.type {
                Text("\(from) → \(to)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d h:mm a"
        return formatter.string(from: date)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#if DEBUG
extension InstanceActivityChart {
    static var previewData: [InstanceActivity] {
        let calendar = Calendar.current
        var date = calendar.startOfDay(for: Date())
        var activities: [InstanceActivity] = []
        
        // Create sample activities for the past week
        for i in 0..<7 {
            let runtime = Double([18000, 28800, 43200, 36000, 21600, 32400, 25200][i])
            let cost = (runtime / 3600.0) * 0.0116 // Using t2.micro hourly rate
            
            activities.append(
                InstanceActivity(
                    id: UUID().uuidString,
                    instanceId: "i-123456789",
                    timestamp: date,
                    type: .stateChange(from: "stopped", to: "running"),
                    details: "Instance state changed from stopped to running",
                    runtime: runtime,
                    cost: cost
                )
            )
            date = calendar.date(byAdding: .day, value: -1, to: date)!
        }
        
        return activities
    }
    
    static var previews: some View {
        InstanceActivityChart(activities: previewData, hourlyRate: 0.0116)
            .frame(height: 200)
            .padding()
    }
}
#endif 