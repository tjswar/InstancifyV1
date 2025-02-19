import Foundation
import WidgetKit

class WidgetService {
    static let shared = WidgetService()
    private let defaults: UserDefaults
    
    private init() {
        if let bundleId = Bundle.main.bundleIdentifier,
           let defaults = UserDefaults(suiteName: SharedConfig.userDefaultsSuite) {
            self.defaults = defaults
        } else {
            self.defaults = UserDefaults.standard
        }
    }
    
    func updateWidgetData(for instance: EC2Instance) {
        var instances = getWidgetData(for: instance.region) ?? []
        
        let data = WidgetData(
            instanceId: instance.id,
            instanceName: instance.name ?? instance.id,
            state: instance.state.rawValue,
            runtime: instance.runtime,
            lastUpdated: Date(),
            region: instance.region
        )
        
        if let index = instances.firstIndex(where: { $0.instanceId == instance.id }) {
            instances[index] = data
        } else {
            instances.append(data)
        }
        
        instances.sort { ($0.instanceName) < ($1.instanceName) }
        
        WidgetData.save(instances, for: instance.region)
        
        defaults.set(instance.region, forKey: SharedConfig.currentRegionKey)
        defaults.synchronize()
        
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func updateWidgetDataBatch(_ instances: [EC2Instance], for region: String) {
        let widgetData = instances.map { instance in
            WidgetData(
                instanceId: instance.id,
                instanceName: instance.name ?? instance.id,
                state: instance.state.rawValue,
                runtime: instance.runtime,
                lastUpdated: Date(),
                region: instance.region
            )
        }.sorted { $0.instanceName < $1.instanceName }
        
        WidgetData.save(widgetData, for: region)
        
        defaults.set(region, forKey: SharedConfig.currentRegionKey)
        defaults.synchronize()
        
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func getWidgetData(for region: String) -> [WidgetData]? {
        return WidgetData.load(for: region)
    }
    
    func clearWidgetData(for region: String) {
        WidgetData.clearData(for: region)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func updateCurrentRegion(_ region: String) {
        defaults.set(region, forKey: SharedConfig.currentRegionKey)
        defaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
    }
}