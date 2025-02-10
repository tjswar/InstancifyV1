import SwiftUI
import AWSEC2

struct InstanceRow: View {
    let instance: EC2Instance
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(instance.name ?? "Unnamed Instance")
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text(instance.id)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(instance.instanceType)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if instance.state == .running {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text(Calendar.formatRuntime(from: instance.launchTime))
                                .font(.caption)
                        }
                        .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            StatusBadge(state: instance.state)
        }
        .padding(.vertical, 8)
    }
}

#if DEBUG
struct InstanceRow_Previews: PreviewProvider {
    static var previews: some View {
        InstanceRow(instance: EC2Instance(
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
    }
}
#endif 