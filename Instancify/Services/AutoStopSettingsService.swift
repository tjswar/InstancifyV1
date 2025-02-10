import Foundation
import UserNotifications

struct AutoStopSettings: Codable {
    var isEnabled: Bool
    var stopTime: Date?
}

class AutoStopSettingsService {
    static let shared = AutoStopSettingsService()
    private let defaults: UserDefaults
    private let settingsKey = "instanceAutoStopSettings"
    private let suiteName = "group.tech.md.Instancify"
    private var useAppGroup: Bool = false
    
    private init() {
        // Initialize UserDefaults with app group
        if let suiteDefaults = UserDefaults(suiteName: suiteName) {
            self.defaults = suiteDefaults
            self.useAppGroup = true
            print("✅ Initialized UserDefaults with suite name: \(suiteName)")
            
            // Ensure defaults are synchronized
            self.defaults.synchronize()
            
            // Log current settings
            let settings = getAllSettings()
            print("📊 Current auto-stop settings:")
            print("  • Number of settings: \(settings.count)")
            print("  • Using app group: \(useAppGroup)")
            for (instanceId, setting) in settings {
                print("  • Instance \(instanceId):")
                print("    - Enabled: \(setting.isEnabled)")
                print("    - Stop time: \(String(describing: setting.stopTime))")
            }
        } else {
            self.defaults = UserDefaults.standard
            self.useAppGroup = false
            print("⚠️ Failed to initialize UserDefaults with suite name, falling back to standard")
        }
    }
    
    func saveSettings(for instanceId: String, enabled: Bool, time: Date?) {
        print("\n📝 Saving auto-stop settings for instance \(instanceId)")
        print("  • Enabled: \(enabled)")
        print("  • Stop time: \(String(describing: time))")
        print("  • Using app group: \(useAppGroup)")
        
        // Validate inputs
        guard !instanceId.isEmpty else {
            print("  ❌ Invalid instance ID")
            return
        }
        
        // If a time is provided, ensure it's in the future
        if let stopTime = time {
            guard stopTime > Date() else {
                print("  ❌ Stop time must be in the future")
                return
            }
        }
        
        var settings = getAllSettings()
        settings[instanceId] = AutoStopSettings(isEnabled: enabled, stopTime: time)
        
        do {
            let encoded = try JSONEncoder().encode(settings)
            defaults.set(encoded, forKey: settingsKey)
            
            // Force synchronize and verify
            let success = defaults.synchronize()
            print("  ✅ Settings saved successfully (synchronized: \(success))")
            
            // Verify the settings were saved
            if let savedSettings = getSettings(for: instanceId) {
                print("  • Verified saved settings:")
                print("    - Enabled: \(savedSettings.isEnabled)")
                print("    - Stop time: \(String(describing: savedSettings.stopTime))")
                
                // Verify the saved settings match what we tried to save
                if savedSettings.isEnabled != enabled || savedSettings.stopTime != time {
                    print("  ⚠️ Warning: Saved settings don't match input")
                    print("    - Expected enabled: \(enabled), got: \(savedSettings.isEnabled)")
                    print("    - Expected time: \(String(describing: time)), got: \(String(describing: savedSettings.stopTime))")
                }
            } else {
                print("  ⚠️ Warning: Could not verify saved settings")
                
                // Try to diagnose the issue
                if let data = defaults.data(forKey: settingsKey) {
                    print("    - Data exists but couldn't be decoded")
                    print("    - Data size: \(data.count) bytes")
                } else {
                    print("    - No data found for key: \(settingsKey)")
                }
            }
        } catch {
            print("  ❌ Failed to encode settings: \(error)")
        }
        
        // Clear notifications if no time is set
        if time == nil {
            Task {
                let warningIntervals = [3600, 1800, 900, 300, 60]
                let warningIds = warningIntervals.map { "warning-\(instanceId)-\($0)" }
                let notificationIds = warningIds + ["final-\(instanceId)"]
                await UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIds)
                await UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: notificationIds)
            }
        }
    }
    
    func getSettings(for instanceId: String) -> AutoStopSettings? {
        print("\n🔍 Getting auto-stop settings for instance \(instanceId)")
        print("  • Using app group: \(useAppGroup)")
        
        let settings = getAllSettings()
        let result = settings[instanceId]
        
        print("  • Found settings: \(String(describing: result))")
        if result == nil {
            // Try to diagnose why settings weren't found
            if let data = defaults.data(forKey: settingsKey) {
                print("    - Settings data exists but instance not found")
                print("    - Data size: \(data.count) bytes")
                print("    - Available instance IDs: \(settings.keys.joined(separator: ", "))")
            } else {
                print("    - No settings data found")
            }
        }
        
        return result
    }
    
    func getAllSettings() -> [String: AutoStopSettings] {
        if let data = defaults.data(forKey: settingsKey) {
            do {
                let settings = try JSONDecoder().decode([String: AutoStopSettings].self, from: data)
                return settings
            } catch {
                print("  ❌ Failed to decode settings: \(error)")
                // Try to recover by removing corrupted data
                defaults.removeObject(forKey: settingsKey)
                defaults.synchronize()
                return [:]
            }
        } else {
            print("  ℹ️ No settings found")
            return [:]
        }
    }
    
    func clearSettings(for instanceId: String) {
        print("\n🗑️ Clearing auto-stop settings for instance \(instanceId)")
        print("  • Using app group: \(useAppGroup)")
        
        var settings = getAllSettings()
        settings.removeValue(forKey: instanceId)
        
        do {
            let encoded = try JSONEncoder().encode(settings)
            defaults.set(encoded, forKey: settingsKey)
            let success = defaults.synchronize()
            print("  ✅ Settings cleared successfully (synchronized: \(success))")
        } catch {
            print("  ❌ Failed to encode settings after clearing: \(error)")
        }
        
        // Clear all notifications
        Task {
            let warningIntervals = [3600, 1800, 900, 300, 60]
            let warningIds = warningIntervals.map { "warning-\(instanceId)-\($0)" }
            let notificationIds = warningIds + ["final-\(instanceId)", "autoStop-\(instanceId)"]
            
            await UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIds)
            await UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: notificationIds)
        }
    }
    
    func removeAllSettingsForInstance(_ instanceId: String) {
        clearSettings(for: instanceId)
    }
} 