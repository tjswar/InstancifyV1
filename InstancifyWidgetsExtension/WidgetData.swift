import Foundation

public struct WidgetData: Codable {
    public let instanceId: String
    public let instanceName: String
    public let state: String
    public let runtime: Int
    public let lastUpdated: Date
    public let region: String
    
    public init(instanceId: String, instanceName: String, state: String, runtime: Int, lastUpdated: Date, region: String) {
        self.instanceId = instanceId
        self.instanceName = instanceName
        self.state = state
        self.runtime = runtime
        self.lastUpdated = lastUpdated
        self.region = region
    }
    
    public var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > SharedConfig.refreshInterval
    }
    
    public static func save(_ data: [WidgetData], for region: String) {
        guard let sharedDefaults = UserDefaults(suiteName: SharedConfig.userDefaultsSuite) else {
            print("❌ Widget Data: Failed to access shared defaults")
            return
        }
        
        // Clear old data for the region
        let key = SharedConfig.widgetDataKeyPrefix + region
        sharedDefaults.removeObject(forKey: key)
        
        // Save new data if we have any
        if !data.isEmpty {
            if let encoded = try? JSONEncoder().encode(data) {
                sharedDefaults.set(encoded, forKey: key)
                print("✅ Widget Data: Saved \(data.count) instances for region: \(region)")
            } else {
                print("❌ Widget Data: Failed to encode data for region: \(region)")
            }
        } else {
            print("ℹ️ Widget Data: No instances to save for region: \(region)")
        }
        
        sharedDefaults.synchronize()
    }
    
    public static func load(for region: String) -> [WidgetData]? {
        guard let sharedDefaults = UserDefaults(suiteName: SharedConfig.userDefaultsSuite) else {
            print("❌ Widget Data: Failed to access shared defaults")
            return nil
        }
        
        let key = SharedConfig.widgetDataKeyPrefix + region
        print("🔍 Widget Data: Loading data for key: \(key)")
        
        guard let data = sharedDefaults.data(forKey: key) else {
            print("ℹ️ Widget Data: No data found for region: \(region)")
            return nil
        }
        
        guard let widgetDataArray = try? JSONDecoder().decode([WidgetData].self, from: data) else {
            print("❌ Widget Data: Failed to decode data for region: \(region)")
            sharedDefaults.removeObject(forKey: key)
            sharedDefaults.synchronize()
            return nil
        }
        
        print("✅ Widget Data: Loaded \(widgetDataArray.count) instances for region: \(region)")
        
        // Filter out stale data
        let validData = widgetDataArray.filter { !$0.isStale }
        if widgetDataArray.count != validData.count {
            print("ℹ️ Widget Data: \(widgetDataArray.count - validData.count) stale instances removed")
        }
        
        // If no valid data remains, clear the stored data
        if validData.isEmpty {
            print("ℹ️ Widget Data: No valid instances remain, clearing data")
            sharedDefaults.removeObject(forKey: key)
            sharedDefaults.synchronize()
            return nil
        }
        
        // Log instance details for debugging
        for instance in validData {
            print("📱 Widget Data: Instance \(instance.instanceId) - Name: \(instance.instanceName) - State: \(instance.state)")
        }
        
        return validData
    }
    
    public static func clearData(for region: String) {
        let sharedDefaults = UserDefaults(suiteName: SharedConfig.userDefaultsSuite)
        let key = SharedConfig.widgetDataKeyPrefix + region
        sharedDefaults?.removeObject(forKey: key)
        sharedDefaults?.synchronize()
        print("🗑️ Widget Data: Cleared data for region: \(region)")
    }
} 