import SwiftUI

struct InstanceCostCard: View {
    let instance: EC2Instance
    @State private var showingCostInfo = false
    @EnvironmentObject private var appearanceViewModel: AppearanceSettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Cost Information")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Hourly Rate")
                    Spacer()
                    Text(String(format: "$%.4f", instance.hourlyRate))
                }
                
                Link(destination: URL(string: "https://aws.amazon.com/ec2/pricing/")!) {
                    HStack {
                        Text("View EC2 Pricing")
                            .foregroundColor(appearanceViewModel.currentAccentColor)
                        Image(systemName: "link")
                            .foregroundColor(appearanceViewModel.currentAccentColor)
                    }
                }
                
                HStack {
                    Text("Current Cost")
                    Spacer()
                    Text(String(format: "$%.2f", instance.currentCost))
                        .foregroundColor(instance.state == .running ? appearanceViewModel.currentAccentColor : .secondary)
                    Button {
                        showingCostInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Projected Daily")
                    Spacer()
                    Text(String(format: "$%.2f", instance.projectedDailyCost))
                        .foregroundColor(instance.state == .running ? appearanceViewModel.currentAccentColor : .secondary)
                }
            }
            .animation(.easeInOut, value: instance.currentCost)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .alert("Cost Information", isPresented: $showingCostInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Cost is calculated based on the instance's running time today. Projected cost assumes the instance runs for 24 hours.")
        }
    }
}

#if DEBUG
struct InstanceCostCard_Previews: PreviewProvider {
    static var previews: some View {
        InstanceCostCard(instance: EC2Instance(
            id: "i-123456789",
            instanceType: "t2.micro",
            state: .running,
            name: "Preview Instance",
            launchTime: Date(),
            publicIP: "54.123.45.67",
            privateIP: "172.16.0.100",
            autoStopEnabled: false,
            countdown: nil,
            stateTransitionTime: nil,
            hourlyRate: 0.0116,
            runtime: 0,
            currentCost: 0,
            projectedDailyCost: 0,
            region: "us-east-1"
        ))
        .environmentObject(AppearanceSettingsViewModel.shared)
    }
}
#endif 