import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            // App Info Section
            Section {
                appInfoContent
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            .listSectionSeparator(.hidden)
            
            // Legal & Privacy Section
            Section {
                legalContent
            } header: {
                Text("Legal")
            }
            .listRowBackground(Color(.systemBackground))
            .listSectionSeparator(.visible)
            
            // Contact Section
            Section {
                contactContent
            } header: {
                Text("Contact")
            }
            .listRowBackground(Color(.systemBackground))
            .listSectionSeparator(.visible)
            
            // Donate Section
            Section {
                donateContent
            } header: {
                Text("Support Development")
            }
            .listRowBackground(Color(.systemBackground))
            .listSectionSeparator(.visible)
            
            // Credits Section
            Section {
                creditsContent
                    .listRowBackground(Color.clear)
            }
            .listSectionSeparator(.hidden)
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .listStyle(.plain)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var appInfoContent: some View {
        VStack(alignment: .center, spacing: 12) {
            AppIconView()
            
            Text("Instancify")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Version \(Bundle.main.appVersionString)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
    
    private var legalContent: some View {
        Group {
            NavigationLink {
                PrivacyPolicyView()
            } label: {
                ListItemView(
                    icon: "lock.shield.fill",
                    iconColor: .blue,
                    title: "Privacy & Data Usage",
                    subtitle: "View our privacy policy and data handling"
                )
            }
            
            NavigationLink {
                TermsView()
            } label: {
                ListItemView(
                    icon: "doc.text.fill",
                    iconColor: .purple,
                    title: "Terms of Service",
                    subtitle: "View our terms and conditions"
                )
            }
        }
    }
    
    private var contactContent: some View {
        Link(destination: URL(string: "mailto:saitejaswar84@gmail.com")!) {
            ListItemView(
                icon: "envelope.fill",
                iconColor: .orange,
                title: "Contact Us",
                subtitle: "Get in touch with solo dev"
            )
        }
    }
    
    private var donateContent: some View {
        Link(destination: URL(string: "https://paypal.me/SaiTejaswarReddy")!) {
            ListItemView(
                icon: "creditcard.fill",
                iconColor: .green,
                title: "Support Development",
                subtitle: "Make a donation via PayPal"
            )
        }
    }
    
    private var creditsContent: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("Made with ❤️ by")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("LowCode/NoCode Dev")
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Reusable Components
struct AppIconView: View {
    var body: some View {
        Image(systemName: "square.grid.2x2.fill")
            .font(.system(size: 60))
            .foregroundColor(.accentColor)
            .frame(width: 100, height: 100)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(22)
            .shadow(radius: 10)
    }
}

struct ListItemView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 20))
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
    }
}

// MARK: - Terms View
struct TermsView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                // Agreement
                TermsSection(title: "Agreement", systemImage: "checkmark.circle.fill") {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("By using Instancify, you agree to these terms. Please read them carefully.")
                            .font(.subheadline)
                        
                        TermsSubsection(title: "Acceptance", systemImage: "hand.raised.fill") {
                            BulletPoint("These terms apply to all users")
                            BulletPoint("Terms may be updated periodically")
                            BulletPoint("Continued use implies acceptance")
                            BulletPoint("Users will be notified of major changes")
                        }
                    }
                }
                
                // AWS Integration
                TermsSection(title: "AWS Integration", systemImage: "cloud.fill") {
                    VStack(alignment: .leading, spacing: 16) {
                        TermsSubsection(title: "Your AWS Account", systemImage: "person.badge.key.fill") {
                            BulletPoint("You must have valid AWS credentials")
                            BulletPoint("You are responsible for AWS costs")
                            BulletPoint("We don't store your AWS keys on our servers")
                            BulletPoint("You control all AWS actions")
                        }
                        
                        TermsSubsection(title: "Permissions", systemImage: "lock.shield.fill") {
                            BulletPoint("Limited to EC2 instance management")
                            BulletPoint("Start, stop, and monitor instances")
                            BulletPoint("View cost and usage metrics")
                            BulletPoint("Manage runtime alerts")
                        }
                    }
                }
                
                // User Responsibilities
                TermsSection(title: "User Responsibilities", systemImage: "person.2.fill") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("Maintain AWS account security")
                        BulletPoint("Keep app credentials secure")
                        BulletPoint("Use the app responsibly")
                        BulletPoint("Report security concerns promptly")
                        BulletPoint("Comply with AWS service terms")
                        BulletPoint("Monitor instance costs")
                    }
                }
                
                // Limitations
                TermsSection(title: "Limitations", systemImage: "exclamationmark.triangle.fill") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("App provided 'as is'")
                        BulletPoint("No guarantee of service availability")
                        BulletPoint("Not responsible for AWS costs")
                        BulletPoint("May have service interruptions")
                        BulletPoint("Features may change over time")
                    }
                }
                
                // Termination
                TermsSection(title: "Termination", systemImage: "xmark.circle.fill") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("You can stop using anytime")
                        BulletPoint("We may terminate for misuse")
                        BulletPoint("AWS access remains yours")
                        BulletPoint("Data deleted on termination")
                    }
                }
                
                // Support
                TermsSection(title: "Support", systemImage: "lifepreserver.fill") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("In-app support available")
                        BulletPoint("Email support provided")
                        BulletPoint("Response within 48 hours")
                        BulletPoint("AWS issues handled by AWS")
                    }
                }
                
                // Updates
                TermsSection(title: "Updates", systemImage: "arrow.triangle.2.circlepath") {
                    VStack(alignment: .leading, spacing: 8) {
                        BulletPoint("App updates through App Store")
                        BulletPoint("Terms may be updated")
                        BulletPoint("Users notified of changes")
                        BulletPoint("Continued use accepts updates")
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Helper Views
struct TermsSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content
    
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

struct TermsSubsection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content
    
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

// MARK: - Extensions
extension Bundle {
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationView {
        AboutView()
    }
} 