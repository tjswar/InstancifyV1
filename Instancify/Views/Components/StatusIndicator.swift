import SwiftUI

struct StatusIndicator: View {
    let status: String
    
    var color: Color {
        switch status.lowercased() {
        case "running": return .green
        case "stopped": return .red
        case "pending": return .orange
        case "terminated": return .gray
        default: return .secondary
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(status.capitalized)
                .foregroundColor(color)
        }
        .font(.subheadline)
    }
} 