import Foundation

extension Bundle {
    var releaseVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var versionString: String {
        return "\(releaseVersion) (\(buildNumber))"
    }
} 