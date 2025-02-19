import Foundation
import SwiftUI

public enum InstancifyWidgetConfig {
    public static let refreshInterval: TimeInterval = 15 * 60 // 15 minutes
    public static let userDefaultsSuite = "group.tech.md.Instancify"
    public static let widgetDataKeyPrefix = "widget-data-"
    
    public struct UI {
        public static let statusIndicatorSize: CGFloat = 6
        public static let defaultPadding: CGFloat = 16
        public static let largePadding: CGFloat = 20
        public static let defaultSpacing: CGFloat = 12
        public static let smallSpacing: CGFloat = 4
    }
    
    public struct Colors {
        public static let running = Color.green
        public static let stopped = Color.red
        public static let projected = Color.orange
    }
} 