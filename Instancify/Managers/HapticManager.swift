import Foundation
import UIKit
import SwiftUI

@MainActor
class HapticManager: ObservableObject {
    static let shared = HapticManager()
    
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    
    private init() {}
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard hapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    func selection() {
        guard hapticsEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    var isEnabled: Bool {
        get { hapticsEnabled }
        set { hapticsEnabled = newValue }
    }
}

// Extension to provide static access for convenience
extension HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        shared.impact(style)
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        shared.notification(type)
    }
    
    static func selection() {
        shared.selection()
    }
} 