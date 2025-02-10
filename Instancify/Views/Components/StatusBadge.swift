import SwiftUI

struct StatusBadge: View {
    let state: InstanceState
    
    var color: Color {
        switch state {
        case .running: return .green
        case .stopped: return .red
        case .pending, .stopping: return .orange
        case .shuttingDown: return .orange
        case .terminated: return .gray
        case .unknown: return .gray
        }
    }
    
    var body: some View {
        Text(state.displayString)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(6)
    }
} 