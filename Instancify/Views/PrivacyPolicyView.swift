import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedSection: PrivacySection = .summary
    
    enum PrivacySection: String, CaseIterable {
        case summary = "Summary"
        case policy = "Privacy Policy"
        case dataUsage = "Data Usage"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Section Picker
                Picker("Section", selection: $selectedSection) {
                    ForEach(PrivacySection.allCases, id: \.self) { section in
                        Text(section.rawValue)
                            .tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedSection {
                        case .summary:
                            PrivacySummaryContent()
                        case .policy:
                            PrivacyPolicyContent()
                        case .dataUsage:
                            DataUsageContent()
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Privacy & Data Usage")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct PrivacySummaryContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // What We Collect
            PrivacySection(title: "What We Collect", systemImage: "doc.text.magnifyingglass") {
                VStack(alignment: .leading, spacing: 16) {
                    PrivacySubsection(title: "Essential Data", systemImage: "lock.shield") {
                        BulletPoint("AWS credentials (stored securely)")
                        BulletPoint("Instance information")
                        BulletPoint("Cost metrics")
                        BulletPoint("Device settings")
                    }
                    
                    PrivacySubsection(title: "Optional Data", systemImage: "switch.2") {
                        BulletPoint("Push notification preferences")
                        BulletPoint("Runtime monitoring settings")
                        BulletPoint("App usage statistics")
                        BulletPoint("Performance metrics")
                    }
                }
            }
            
            // How We Protect
            PrivacySection(title: "How We Protect Your Data", systemImage: "lock.shield.fill") {
                VStack(alignment: .leading, spacing: 8) {
                    BulletPoint("End-to-end encryption")
                    BulletPoint("Secure local storage")
                    BulletPoint("No third-party sharing")
                    BulletPoint("Regular security updates")
                }
            }
            
            // Your Control
            PrivacySection(title: "Your Control", systemImage: "person.fill.checkmark") {
                VStack(alignment: .leading, spacing: 8) {
                    BulletPoint("View your data")
                    BulletPoint("Delete your data")
                    BulletPoint("Export your data")
                    BulletPoint("Manage notifications")
                    BulletPoint("Control monitoring")
                    BulletPoint("Opt out of analytics")
                }
            }
            
            // Important Points
            PrivacySection(title: "Important Points", systemImage: "exclamationmark.shield.fill") {
                VStack(alignment: .leading, spacing: 8) {
                    BulletPoint("We don't track you across apps")
                    BulletPoint("We don't sell your data")
                    BulletPoint("We don't store AWS keys on our servers")
                    BulletPoint("You can delete all data at any time")
                    BulletPoint("Data is stored locally when possible")
                    BulletPoint("Cloud storage is encrypted")
                }
            }
            
            // Third-Party Services
            PrivacySection(title: "Third-Party Services", systemImage: "network") {
                VStack(alignment: .leading, spacing: 8) {
                    BulletPoint("AWS (for EC2 management)")
                    BulletPoint("Firebase (for notifications)")
                    BulletPoint("No advertising services")
                    BulletPoint("No analytics services")
                }
            }
        }
    }
}

struct PrivacyPolicyContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Overview
            PrivacySection(title: "Overview", systemImage: "doc.text.fill") {
                Text("Instancify is committed to protecting your privacy. This policy explains how we collect, use, and safeguard your information.")
                    .font(.subheadline)
            }
            
            // App Store Privacy Details
            PrivacySection(title: "App Store Privacy Details", systemImage: "apps.iphone") {
                VStack(alignment: .leading, spacing: 16) {
                    PrivacySubsection(title: "Data Used to Track You", systemImage: "location.slash.fill") {
                        Text("We do not track or share your data across other companies' apps or websites.")
                            .font(.subheadline)
                    }
                    
                    PrivacySubsection(title: "Data Linked to You", systemImage: "person.text.rectangle.fill") {
                        BulletPoint("AWS Account Information (stored securely)")
                        BulletPoint("Device Information")
                        BulletPoint("Usage Data")
                        BulletPoint("Performance Data")
                    }
                }
            }
            
            // Data Protection
            PrivacySection(title: "Data Protection", systemImage: "lock.shield.fill") {
                VStack(alignment: .leading, spacing: 16) {
                    PrivacySubsection(title: "Security Measures", systemImage: "checkmark.shield.fill") {
                        BulletPoint("Encryption of sensitive data")
                        BulletPoint("Secure storage of AWS credentials")
                        BulletPoint("Protected cloud database access")
                        BulletPoint("Authentication state management")
                    }
                    
                    PrivacySubsection(title: "Third-Party Services", systemImage: "network") {
                        BulletPoint("Firebase: Authentication & Notifications")
                        BulletPoint("AWS: EC2 & Cost Explorer API")
                    }
                }
            }
            
            // Your Rights
            PrivacySection(title: "Your Rights", systemImage: "person.fill.checkmark") {
                VStack(alignment: .leading, spacing: 8) {
                    BulletPoint("Access your personal data")
                    BulletPoint("Correct inaccurate data")
                    BulletPoint("Delete your data")
                    BulletPoint("Opt-out of notifications")
                    BulletPoint("Disable runtime monitoring")
                    BulletPoint("Remove AWS credentials")
                }
            }
            
            // Compliance
            PrivacySection(title: "Compliance", systemImage: "checkmark.seal.fill") {
                VStack(alignment: .leading, spacing: 8) {
                    BulletPoint("GDPR (General Data Protection Regulation)")
                    BulletPoint("CCPA (California Consumer Privacy Act)")
                    BulletPoint("Apple's App Store Privacy Guidelines")
                    BulletPoint("AWS Service Terms")
                    BulletPoint("Firebase Terms of Service")
                }
            }
        }
    }
}

struct DataUsageContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Data Collection
            PrivacySection(title: "Data Collection", systemImage: "doc.text.magnifyingglass") {
                VStack(alignment: .leading, spacing: 16) {
                    PrivacySubsection(title: "AWS Credentials", systemImage: "key.fill") {
                        BulletPoint("Stored securely in iOS Keychain")
                        BulletPoint("AES-256 encryption")
                        BulletPoint("Immediate removal on request")
                        BulletPoint("Not included in backups")
                    }
                    
                    PrivacySubsection(title: "Instance Monitoring", systemImage: "gauge.badge.plus") {
                        BulletPoint("15-minute background refresh")
                        BulletPoint("Local device storage")
                        BulletPoint("1-hour cache duration")
                        BulletPoint("Delta updates for efficiency")
                    }
                }
            }
            
            // Performance Impact
            PrivacySection(title: "Performance Impact", systemImage: "speedometer") {
                VStack(alignment: .leading, spacing: 16) {
                    PrivacySubsection(title: "Device Resources", systemImage: "cpu") {
                        BulletPoint("CPU Usage: < 10% average")
                        BulletPoint("Memory Usage: < 100MB active")
                        BulletPoint("Storage: < 500MB total")
                        BulletPoint("Battery Impact: Minimal")
                    }
                    
                    PrivacySubsection(title: "Network Usage", systemImage: "network") {
                        BulletPoint("Average Data: 5MB/day")
                        BulletPoint("Peak Usage: 20MB/day")
                        BulletPoint("Background: 1MB/hour")
                        BulletPoint("Compression: 70% ratio")
                    }
                }
            }
            
            // Data Deletion
            PrivacySection(title: "Data Deletion", systemImage: "trash.fill") {
                VStack(alignment: .leading, spacing: 16) {
                    PrivacySubsection(title: "User-Initiated", systemImage: "person.crop.circle.badge.minus") {
                        BulletPoint("AWS Credentials: Immediate")
                        BulletPoint("Cache: Immediate")
                        BulletPoint("Settings: Immediate")
                        BulletPoint("Notifications: 24h delay")
                    }
                    
                    PrivacySubsection(title: "Automatic", systemImage: "clock.arrow.circlepath") {
                        BulletPoint("Session Data: End of session")
                        BulletPoint("Cache: 7 days")
                        BulletPoint("Error Logs: 30 days")
                        BulletPoint("Analytics: 90 days")
                    }
                }
            }
        }
    }
}

struct PrivacySection<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content
    
    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
            }
            
            content
                .padding(.leading, 4)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct PrivacySubsection<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content
    
    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            content
                .padding(.leading, 4)
        }
    }
}

#Preview {
    PrivacyPolicyView()
} 