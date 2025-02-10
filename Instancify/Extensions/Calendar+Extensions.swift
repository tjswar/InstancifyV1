import Foundation

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
    
    var numberOfHoursInCurrentMonth: Int {
        guard let range = range(of: .day, in: .month, for: Date()) else {
            return 720 // Default to 30 days if can't determine
        }
        return range.count * 24
    }
    
    static func formatRuntime(from date: Date?) -> String {
        guard let date = date else { return "N/A" }
        
        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: date, to: Date())
        
        if let days = components.day, days > 0 {
            return "\(days)d \(components.hour ?? 0)h"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h \(components.minute ?? 0)m"
        } else if let minutes = components.minute {
            return "\(minutes)m"
        }
        
        return "Just started"
    }
} 