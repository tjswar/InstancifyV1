import SwiftUI

struct DetailRow: View {
    let title: String
    let value: String
    let icon: String
    var iconColor: Color = .accentColor
    
    var body: some View {
        HStack {
            Label {
                Text(title)
                    .foregroundColor(.secondary)
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
            }
            
            Spacer()
            
            Text(value)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
    }
}

struct RuntimeDetailRow: View {
    let instance: EC2Instance
    
    var body: some View {
        if instance.state == .running {
            DetailRow(
                title: "Runtime",
                value: Calendar.formatRuntime(from: instance.launchTime),
                icon: "clock",
                iconColor: .green
            )
        }
    }
}

#Preview {
    VStack {
        DetailRow(title: "Instance ID", value: "i-1234567890abcdef0", icon: "server.rack")
    }
    .padding()
} 