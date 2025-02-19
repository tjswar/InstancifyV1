import Foundation
import AWSCloudWatch
import AWSCore
import AWSEC2

@MainActor
class CloudWatchService {
    static let shared = CloudWatchService()
    private let cloudWatchClient = AWSCloudWatch.default()
    
    private init() {}
    
    func getInstanceMetrics(instanceId: String) async throws -> InstanceMetrics {
        let endTime = Date()
        let startTime = Calendar.current.date(byAdding: .minute, value: -5, to: endTime)!
        
        guard let cpuRequest = AWSCloudWatchGetMetricStatisticsInput(),
              let dimension = AWSCloudWatchDimension() else {
            throw NSError(domain: "CloudWatchService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])
        }
        
        cpuRequest.namespace = "AWS/EC2"
        cpuRequest.metricName = "CPUUtilization"
        
        dimension.name = "InstanceId"
        dimension.value = instanceId
        
        cpuRequest.dimensions = [dimension]
        cpuRequest.startTime = startTime
        cpuRequest.endTime = endTime
        cpuRequest.period = NSNumber(value: 300) // 5 minutes
        cpuRequest.statistics = ["Average"]
        
        return try await withCheckedThrowingContinuation { continuation in
            cloudWatchClient.getMetricStatistics(cpuRequest) { response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let cpuUtilization = response?.datapoints?.first?.average?.doubleValue ?? 0.0
                
                let metrics = InstanceMetrics(
                    cpuUtilization: cpuUtilization,
                    memoryUsage: 0.0,
                    networkIn: 0.0,
                    networkOut: 0.0,
                    diskReadOps: 0.0,
                    diskWriteOps: 0.0
                )
                
                continuation.resume(returning: metrics)
            }
        }
    }
    
    func fetchCostMetrics(for instances: [EC2Instance]) async throws -> CostMetrics {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        // Calculate daily cost (cost for today only)
        let dailyCost = instances.reduce(0.0) { total, instance in
            if instance.state == .running || instance.stateTransitionTime?.timeIntervalSince(startOfDay) ?? 0 > 0 {
                let endTime = instance.state == .running ? now : (instance.stateTransitionTime ?? now)
                let startTime = max(startOfDay, instance.launchTime ?? startOfDay)
                let runtime = endTime.timeIntervalSince(startTime)
                return total + (instance.hourlyRate * (runtime / 3600))
            }
            return total
        }
        
        // Calculate monthly cost (based on actual runtime this month)
        let monthlyCost = instances.reduce(0.0) { total, instance in
            if let launchTime = instance.launchTime {
                let endTime = instance.state == .running ? now : (instance.stateTransitionTime ?? now)
                let startTime = max(startOfMonth, launchTime)
                let runtime = endTime.timeIntervalSince(startTime)
                return total + (instance.hourlyRate * (runtime / 3600))
            }
            return total
        }
        
        // Calculate projected monthly cost
        let projectedCost = instances.reduce(0.0) { total, instance in
            var cost = 0.0
            
            // Add cost for time already elapsed
            if let launchTime = instance.launchTime {
                let endTime = instance.state == .running ? now : (instance.stateTransitionTime ?? now)
                let startTime = max(startOfMonth, launchTime)
                let runtime = endTime.timeIntervalSince(startTime)
                cost += instance.hourlyRate * (runtime / 3600)
            }
            
            // Add projected cost for remaining days if instance is running
            if instance.state == .running {
                let remainingHours = endOfMonth.timeIntervalSince(now) / 3600
                cost += instance.hourlyRate * remainingHours
            }
            
            return total + cost
        }
        
        // Round to 2 decimal places
        return CostMetrics(
            dailyCost: (dailyCost * 100).rounded() / 100,
            monthlyCost: (monthlyCost * 100).rounded() / 100,
            projectedCost: (projectedCost * 100).rounded() / 100
        )
    }
} 