import SwiftUI

struct ResourceCard: View {
    let title: String
    let value: String
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
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ComputeSection: View {
    let cpuUsage: Double
    let memoryUsage: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Compute Resources")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 16) {
                ResourceCard(
                    title: "CPU Usage",
                    value: "\(Int(cpuUsage))%",
                    icon: "cpu",
                    color: .blue
                )
                
                ResourceCard(
                    title: "Memory",
                    value: "\(Int(memoryUsage))%",
                    icon: "memorychip",
                    color: .purple
                )
            }
        }
        .padding(.horizontal)
    }
} 