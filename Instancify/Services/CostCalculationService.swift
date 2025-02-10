import Foundation

class CostCalculationService {
    static let shared = CostCalculationService()
    
    // Standard hourly rates for EC2 instances (in USD)
    private let hourlyRates: [String: Double] = [
        "t2.nano": 0.0058,
        "t2.micro": 0.0116,
        "t2.small": 0.023,
        "t2.medium": 0.0464,
        "t2.large": 0.0928,
        "t2.xlarge": 0.1856,
        "t2.2xlarge": 0.3712,
        "t3.nano": 0.0052,
        "t3.micro": 0.0104,
        "t3.small": 0.0208,
        "t3.medium": 0.0416,
        "t3.large": 0.0832,
        "t3.xlarge": 0.1664,
        "t3.2xlarge": 0.3328,
        "t3a.nano": 0.0047,
        "t3a.micro": 0.0094,
        "t3a.small": 0.0188,
        "t3a.medium": 0.0376,
        "t3a.large": 0.0752,
        "t3a.xlarge": 0.1504,
        "t3a.2xlarge": 0.3008
    ]
    
    func getHourlyRate(for instanceType: String) -> Double {
        return hourlyRates[instanceType] ?? 0.0116 // Default to t2.micro rate if unknown
    }
    
    func calculateCosts(for instance: EC2Instance) -> (today: Double, thisMonth: Double, projected: Double) {
        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        let hourlyRate = hourlyRates[instance.instanceType] ?? 0.0116
        
        // Calculate today's cost
        let todayCost: Double
        if instance.state == .running || instance.stateTransitionTime?.timeIntervalSince(startOfToday) ?? 0 > 0 {
            let endTime = instance.state == .running ? now : (instance.stateTransitionTime ?? now)
            let startTime = max(startOfToday, instance.launchTime ?? startOfToday)
            let runtime = endTime.timeIntervalSince(startTime)
            todayCost = hourlyRate * (runtime / 3600)
        } else {
            todayCost = 0
        }
        
        // Calculate this month's cost
        let monthCost: Double
        if let launchTime = instance.launchTime {
            let endTime = instance.state == .running ? now : (instance.stateTransitionTime ?? now)
            let startTime = max(startOfMonth, launchTime)
            let runtime = endTime.timeIntervalSince(startTime)
            monthCost = hourlyRate * (runtime / 3600)
        } else {
            monthCost = 0
        }
        
        // Calculate projected cost
        var projectedCost = monthCost // Start with actual cost so far
        
        // Add projected cost for remaining days if instance is running
        if instance.state == .running {
            let remainingHours = endOfMonth.timeIntervalSince(now) / 3600
            projectedCost += hourlyRate * remainingHours
        }
        
        return (
            today: (todayCost * 100).rounded() / 100,
            thisMonth: (monthCost * 100).rounded() / 100,
            projected: (projectedCost * 100).rounded() / 100
        )
    }
    
    func calculateInstanceCost(for instance: EC2Instance, from startDate: Date, to endDate: Date) -> Double {
        let hourlyRate = hourlyRates[instance.instanceType] ?? 0.0116
        let runningHours = max(0, endDate.timeIntervalSince(startDate) / 3600)
        return (runningHours * hourlyRate * 100).rounded() / 100
    }
} 