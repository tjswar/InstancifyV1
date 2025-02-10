import Foundation
import SwiftUI
import Combine

struct RegionRuntimeAlert: Codable, Identifiable {
    let id: String
    var enabled: Bool
    var hours: Int
    var minutes: Int
    var regions: Set<String>
}

@MainActor
class NotificationSettingsViewModel: ObservableObject {
    private static let _shared = NotificationSettingsViewModel()
    
    static var shared: NotificationSettingsViewModel {
        return _shared
    }
    
    @AppStorage("runtimeAlertsEnabled") var runtimeAlertsEnabled = false {
        didSet {
            NotificationCenter.default.post(name: NSNotification.Name("RuntimeAlertsChanged"), object: nil)
            // When disabling runtime alerts, disable all alerts
            if !runtimeAlertsEnabled {
                runtimeAlerts.removeAll()
                saveAlerts()
            }
        }
    }
    @AppStorage("warningsEnabled") private var warningsEnabled = true
    @AppStorage("countdownEnabled") private var countdownEnabled = true
    @Published private(set) var warningIntervals: [Int] = []
    @Published var runtimeAlerts: [RegionRuntimeAlert] = [] {
        didSet {
            saveAlerts()
            NotificationCenter.default.post(name: NSNotification.Name("RuntimeAlertsChanged"), object: nil)
        }
    }
    
    var autoStopWarningsEnabled: Bool {
        get { warningsEnabled }
        set { warningsEnabled = newValue }
    }
    
    var autoStopCountdownEnabled: Bool {
        get { countdownEnabled }
        set { countdownEnabled = newValue }
    }
    
    var selectedWarningIntervals: Set<Int> {
        get { Set(warningIntervals) }
        set { 
            warningIntervals = Array(newValue).sorted(by: >)
            saveWarningIntervals()
        }
    }
    
    let availableWarningIntervals: [(Int, String)] = [
        (7200, "2 hours"),
        (3600, "1 hour"),
        (1800, "30 minutes"),
        (900, "15 minutes"),
        (600, "10 minutes"),
        (300, "5 minutes"),
        (120, "2 minutes"),
        (60, "1 minute")
    ]
    
    private let defaults: UserDefaults?
    private let runtimeAlertsKey = "RuntimeAlerts"
    
    private init() {
        if let bundleId = Bundle.main.bundleIdentifier {
            let appGroupId = "group.\(bundleId)"
            defaults = UserDefaults(suiteName: appGroupId)
        } else {
            defaults = nil
        }
        
        // Ensure runtime alerts are disabled by default
        if !UserDefaults.standard.bool(forKey: "hasInitializedDefaults") {
            runtimeAlertsEnabled = false
            runtimeAlerts = []
            saveAlerts()
            UserDefaults.standard.set(true, forKey: "hasInitializedDefaults")
        }
        
        loadSettings()
        loadWarningIntervals()
        loadAlerts()
    }
    
    private func loadSettings() {
        // Runtime alerts should be disabled by default
        runtimeAlertsEnabled = defaults?.bool(forKey: "runtimeAlertsEnabled") ?? false
        
        if let data = defaults?.data(forKey: runtimeAlertsKey),
           let decoded = try? JSONDecoder().decode([RegionRuntimeAlert].self, from: data) {
            runtimeAlerts = decoded
        } else {
            runtimeAlerts = []
        }
    }
    
    private func saveSettings() {
        defaults?.set(runtimeAlertsEnabled, forKey: "runtimeAlertsEnabled")
        saveAlerts()
    }
    
    func addNewAlert(hours: Int = 0, minutes: Int = 0, regions: Set<String>) {
        let newThreshold = hours * 60 + minutes
        let existingThresholds = runtimeAlerts.map { $0.hours * 60 + $0.minutes }
        
        if existingThresholds.contains(newThreshold) {
            return
        }
        
        let newAlert = RegionRuntimeAlert(
            id: UUID().uuidString,
            enabled: true,
            hours: hours,
            minutes: minutes,
            regions: regions
        )
        
        var insertIndex = 0
        for (index, alert) in runtimeAlerts.enumerated() {
            let alertThreshold = alert.hours * 60 + alert.minutes
            if newThreshold < alertThreshold {
                insertIndex = index
                break
            }
            if index == runtimeAlerts.count - 1 {
                insertIndex = runtimeAlerts.count
            }
        }
        
        runtimeAlerts.insert(newAlert, at: insertIndex)
        saveAlerts()
    }
    
    func deleteAlert(at offsets: IndexSet) {
        guard !runtimeAlerts.isEmpty else { return }
        runtimeAlerts.remove(atOffsets: offsets)
        saveAlerts()
    }
    
    func updateAlert(id: String, enabled: Bool? = nil, hours: Int? = nil, minutes: Int? = nil, regions: Set<String>? = nil) {
        guard let index = runtimeAlerts.firstIndex(where: { $0.id == id }) else { return }
        var alert = runtimeAlerts[index]
        
        if let enabled = enabled {
            alert.enabled = enabled
        }
        if let hours = hours {
            alert.hours = hours
        }
        if let minutes = minutes {
            alert.minutes = minutes
        }
        if let regions = regions {
            alert.regions = regions
        }
        
        runtimeAlerts[index] = alert
        saveAlerts()
        NotificationCenter.default.post(name: NSNotification.Name("RuntimeAlertsChanged"), object: nil)
    }
    
    func toggleWarningInterval(_ interval: Int) {
        if selectedWarningIntervals.contains(interval) {
            selectedWarningIntervals.remove(interval)
        } else {
            selectedWarningIntervals.insert(interval)
        }
    }
    
    private func loadWarningIntervals() {
        if let data = UserDefaults.standard.array(forKey: "warningIntervals") as? [Int] {
            warningIntervals = data
        } else {
            warningIntervals = [3600, 1800, 900, 300, 120, 60]
            saveWarningIntervals()
        }
    }
    
    private func saveWarningIntervals() {
        UserDefaults.standard.set(warningIntervals, forKey: "warningIntervals")
    }
    
    private func loadAlerts() {
        if let data = defaults?.data(forKey: runtimeAlertsKey),
           let alerts = try? JSONDecoder().decode([RegionRuntimeAlert].self, from: data) {
            runtimeAlerts = alerts
        } else {
            runtimeAlerts = []
            saveAlerts()
        }
    }
    
    private func saveAlerts() {
        if let encoded = try? JSONEncoder().encode(runtimeAlerts) {
            defaults?.set(encoded, forKey: runtimeAlertsKey)
        }
    }
    
    // Helper function to get alerts for a specific region
    func getAlertsForRegion(_ region: String) -> [RegionRuntimeAlert] {
        return runtimeAlerts.filter { $0.enabled && $0.regions.contains(region) }
    }
} 