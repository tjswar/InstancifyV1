import SwiftUI

enum InstanceAction: Identifiable {
    case start, stop, reboot, terminate
    
    var id: String { String(describing: self) }
    
    var title: String {
        switch self {
        case .start: return "Start"
        case .stop: return "Stop"
        case .reboot: return "Reboot"
        case .terminate: return "Terminate"
        }
    }
    
    var icon: String {
        switch self {
        case .start: return "play.circle.fill"
        case .stop: return "stop.circle.fill"
        case .reboot: return "arrow.clockwise.circle.fill"
        case .terminate: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .start: return .green
        case .stop: return .orange
        case .reboot: return .blue
        case .terminate: return .red
        }
    }
    
    var confirmationText: String {
        switch self {
        case .start: return "Start Instance"
        case .stop: return "Stop Instance"
        case .reboot: return "Reboot Instance"
        case .terminate: return "Terminate Instance"
        }
    }
    
    var confirmationMessage: String {
        switch self {
        case .start:
            return "Are you sure you want to start this instance? You will be charged for usage."
        case .stop:
            return "Are you sure you want to stop this instance? You can restart it later."
        case .reboot:
            return "Are you sure you want to reboot this instance? This may take a few minutes."
        case .terminate:
            return "Are you sure you want to terminate this instance? This action cannot be undone."
        }
    }
    
    var isEnabled: (InstanceState) -> Bool {
        switch self {
        case .start:
            return { $0 == .stopped }
        case .stop:
            return { $0 == .running }
        case .reboot:
            return { $0 == .running }
        case .terminate:
            return { $0 != .terminated }
        }
    }
} 