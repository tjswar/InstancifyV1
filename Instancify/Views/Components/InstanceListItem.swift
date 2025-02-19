import SwiftUI

struct InstanceListItem: View {
    let instance: EC2Instance
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(instance.name ?? "Unnamed Instance")
                    .font(.headline)
                
                Text(instance.instanceId)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                StatusIndicator(status: instance.state.displayString)
                
                if instance.state == .running {
                    HStack(spacing: 4) {
                        Text("$\(instance.currentCost, specifier: "%.2f")")
                        InfoButton(message: "Cost information updates hourly to optimize app performance")
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

#if DEBUG
struct InstanceListItem_Previews: PreviewProvider {
    static var previews: some View {
        InstanceListItem(instance: .preview())
            .padding()
            .background(Color(.systemGroupedBackground))
    }
}
#endif