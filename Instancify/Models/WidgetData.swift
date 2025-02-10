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
            return
        }
        
        // Clear old data for the region
        let key = SharedConfig.widgetDataKeyPrefix + region
        sharedDefaults.removeObject(forKey: key)
        
        // Save new data if we have any
        if !data.isEmpty {
            if let encoded = try? JSONEncoder().encode(data) {
                sharedDefaults.set(encoded, forKey: key)
            }
        }
        
        sharedDefaults.synchronize()
    }
    
    public static func load(for region: String) -> [WidgetData]? {
        guard let sharedDefaults = UserDefaults(suiteName: SharedConfig.userDefaultsSuite) else {
            return nil
        }
        
        let key = SharedConfig.widgetDataKeyPrefix + region
        guard let data = sharedDefaults.data(forKey: key),
              let widgetDataArray = try? JSONDecoder().decode([WidgetData].self, from: data) else {
            return nil
        }
        
        // Filter out stale data
        let validData = widgetDataArray.filter { !$0.isStale }
        
        // If no valid data remains, clear the stored data
        if validData.isEmpty {
            sharedDefaults.removeObject(forKey: key)
            sharedDefaults.synchronize()
            return nil
        }
        
        return validData
    }
    
    public static func clearData(for region: String) {
        let sharedDefaults = UserDefaults(suiteName: SharedConfig.userDefaultsSuite)
        let key = SharedConfig.widgetDataKeyPrefix + region
        sharedDefaults?.removeObject(forKey: key)
        sharedDefaults?.synchronize()
    }
} 