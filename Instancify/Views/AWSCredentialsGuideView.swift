import SwiftUI

struct AWSCredentialsGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appearanceViewModel: AppearanceSettingsViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Introduction
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Getting Started with AWS Credentials")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Follow this guide to set up your AWS credentials securely and configure the necessary permissions for Instancify.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Required Permissions Section
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Required Permissions", systemImage: "checklist")
                            .font(.headline)
                            .foregroundStyle(appearanceViewModel.currentAccentColor)
                        
                        Text("Instancify requires **EC2 Full Access** (AmazonEC2FullAccess policy) for the following reasons:")
                            .font(.subheadline)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            permissionReason(icon: "power", text: "Start and stop EC2 instances")
                            permissionReason(icon: "clock", text: "Configure auto-stop timers")
                            permissionReason(icon: "list.bullet", text: "List and describe instances")
                            permissionReason(icon: "tag", text: "Manage instance tags")
                            permissionReason(icon: "chart.line.uptrend.xyaxis", text: "Monitor instance metrics")
                            permissionReason(icon: "dollarsign.circle", text: "Access cost information")
                        }
                        .padding(.leading)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    // Step by Step Guide
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Step-by-Step Guide", systemImage: "list.number")
                            .font(.headline)
                            .foregroundStyle(appearanceViewModel.currentAccentColor)
                        
                        VStack(alignment: .leading, spacing: 20) {
                            guideStep(
                                number: "1",
                                title: "Sign in to AWS Console",
                                description: "Go to aws.amazon.com and sign in to the AWS Management Console."
                            )
                            
                            guideStep(
                                number: "2",
                                title: "Navigate to IAM",
                                description: "Search for 'IAM' in the services search bar and click on it."
                            )
                            
                            guideStep(
                                number: "3",
                                title: "Create or Select User",
                                description: "Create a new IAM user or select an existing one. For new users, click 'Add users' and follow the setup process."
                            )
                            
                            guideStep(
                                number: "4",
                                title: "Attach EC2 Policy",
                                description: "In the user's permissions, click 'Add permissions' → 'Attach policies directly' → Search for and select 'AmazonEC2FullAccess'."
                            )
                            
                            guideStep(
                                number: "5",
                                title: "Create Access Key",
                                description: "Go to the 'Security credentials' tab → 'Create access key' → Select 'Application running outside AWS' → Create key."
                            )
                            
                            guideStep(
                                number: "6",
                                title: "Save Credentials",
                                description: "Save both the Access Key ID and Secret Access Key securely. You won't be able to see the Secret Access Key again!"
                            )
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    // Additional Resources
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Additional Resources", systemImage: "link")
                            .font(.headline)
                            .foregroundStyle(appearanceViewModel.currentAccentColor)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Link(destination: URL(string: "https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html")!) {
                                Label("AWS Access Keys Documentation", systemImage: "doc.text")
                                    .font(.subheadline)
                            }
                            
                            Link(destination: URL(string: "https://aws.amazon.com/free/")!) {
                                Label("AWS Free Tier Information", systemImage: "gift")
                                    .font(.subheadline)
                            }
                            
                            Link(destination: URL(string: "https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-security-groups.html")!) {
                                Label("EC2 Security Best Practices", systemImage: "shield")
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemGroupedBackground).opacity(0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("AWS Credentials Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func permissionReason(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(appearanceViewModel.currentAccentColor)
            Text(text)
                .font(.subheadline)
        }
    }
    
    private func guideStep(number: String, title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(appearanceViewModel.currentAccentColor)
                    .clipShape(Circle())
                
                Text(title)
                    .font(.headline)
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.leading, 36)
        }
    }
} 