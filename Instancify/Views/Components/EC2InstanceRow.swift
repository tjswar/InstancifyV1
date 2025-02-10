import SwiftUI
import AWSEC2

struct EC2InstanceRow: View {
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
                }
            }
            
            Spacer()
            
            StatusBadge(state: instance.state)
        }
        .padding(.vertical, 8)
    }
} 