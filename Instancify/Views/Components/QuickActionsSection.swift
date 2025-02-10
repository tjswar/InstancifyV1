import SwiftUI

struct QuickActionsSection: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.title2)
                .fontWeight(.bold)
            
            Button {
                Task {
                    await viewModel.stopAllInstances()
                }
            } label: {
                HStack {
                    Image(systemName: "stop.circle.fill")
                        .foregroundColor(.red)
                    Text("Stop All Instances")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)
            }
            .disabled(viewModel.isLoading || viewModel.isPerformingAction)
            
            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .foregroundColor(.blue)
                    Text("Refresh Status")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }
            .disabled(viewModel.isLoading || viewModel.isPerformingAction)
        }
        .padding()
    }
}

struct QuickActionRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.footnote)
        }
    }
} 