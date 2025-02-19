import SwiftUI

// MARK: - Instance Stats Card
struct InstanceStatCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .foregroundColor(.secondary)
            }
            .font(.footnote)
             
            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Cost Card
struct CostCard: View {
    let title: String
    let amount: Double
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$")
                    .font(.caption)
                    .foregroundColor(color)
                Text(String(format: "%.2f", amount))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassEffect()
    }
}

// MARK: - Cost Overview Section
struct CostOverviewSection: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var localMetrics: CostMetrics?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cost Estimate")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 16) {
                CostCard(
                    title: "Today's Cost",
                    amount: localMetrics?.dailyCost ?? 0,
                    subtitle: "Based on actual usage",
                    color: .blue
                )
                
                CostCard(
                    title: "Month to Date",
                    amount: localMetrics?.monthlyCost ?? 0,
                    subtitle: "Total cost this month",
                    color: .purple
                )
            }
            
            CostCard(
                title: "Monthly Estimate",
                amount: localMetrics?.projectedCost ?? 0,
                subtitle: "Projected cost for this month",
                color: .orange
            )
        }
        .onChange(of: viewModel.costMetrics) { newMetrics in
            localMetrics = newMetrics
        }
    }
}

// MARK: - Stats Overview Section
struct DashboardStatsView: View {
    let runningCount: Int
    let stoppedCount: Int
    let totalInstances: Int
    
    var body: some View {
        HStack(spacing: 16) {
            InstanceStatCard(
                title: "Running",
                count: runningCount,
                icon: "play.circle.fill",
                color: .green
            )
            
            InstanceStatCard(
                title: "Stopped",
                count: stoppedCount,
                icon: "stop.circle.fill",
                color: .red
            )
            
            InstanceStatCard(
                title: "Total",
                count: totalInstances,
                icon: "server.rack",
                color: .blue
            )
        }
        .padding(.horizontal)
    }
}

// MARK: - Supporting Types
enum CostTrend {
    case up, down, neutral
    
    var icon: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .neutral: return "arrow.right"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return .red
        case .down: return .green
        case .neutral: return .orange
        }
    }
    
    var text: String {
        switch self {
        case .up: return "12% vs last week"
        case .down: return "8% vs last month"
        case .neutral: return "Based on usage"
        }
    }
} 