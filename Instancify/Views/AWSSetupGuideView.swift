import SwiftUI

struct AWSSetupGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingIAMInstructions = false
    @StateObject private var hapticManager = HapticManager.shared
    
    let iamPolicyJSON = """
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:DescribeInstances",
                    "ec2:StartInstances",
                    "ec2:StopInstances",
                    "ec2:RebootInstances",
                    "ec2:DescribeRegions",
                    "ec2:DescribeInstanceStatus",
                    "ec2:DescribeTags",
                    "ec2:CreateTags",
                    "ec2:DeleteTags"
                ],
                "Resource": "*"
            }
        ]
    }
    """
    
    var body: some View {
        NavigationView {
            List {
                // Welcome Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "key.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                            Text("AWS Credentials Setup")
                                .font(.headline)
                        }
                        .padding(.bottom, 4)
                        
                        Text("To use Instancify, you'll need to create an IAM user in your AWS account with the appropriate permissions. Follow these steps to get started.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                // Quick Setup Steps
                Section(header: Text("Quick Setup")) {
                    VStack(alignment: .leading, spacing: 12) {
                        StepView(number: 1, text: "Go to AWS IAM Console")
                        StepView(number: 2, text: "Create a new IAM User")
                        StepView(number: 3, text: "Attach the policy below")
                        StepView(number: 4, text: "Copy Access Keys")
                    }
                    .padding(.vertical, 8)
                }
                
                // IAM Policy Section
                GuideSection(title: "Required IAM Policy", systemImage: "key.fill") {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Create a new IAM policy with these permissions:")
                            .font(.subheadline)
                        
                        CodeBlock("""
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:StartInstances",
                "ec2:StopInstances",
                "ec2:RebootInstances",
                "ec2:DescribeRegions",
                "ec2:DescribeInstanceStatus",
                "ec2:DescribeTags",
                "ec2:CreateTags",
                "ec2:DeleteTags"
            ],
            "Resource": "*"
        }
    ]
}
""")
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Important Notes:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            BulletPoint("This policy provides minimum required permissions")
                            BulletPoint("Allows instance control and monitoring")
                            BulletPoint("Enables region switching")
                            BulletPoint("Supports instance tagging")
                        }
                        
                        Text("Alternative: You can also use the AWS-managed 'AmazonEC2FullAccess' policy, but it grants more permissions than needed.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Help Section
                Section {
                    Button {
                        showingIAMInstructions = true
                    } label: {
                        Label("Detailed Instructions", systemImage: "book.fill")
                    }
                    
                    Link(destination: URL(string: "https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-started.html")!) {
                        Label("AWS Documentation", systemImage: "link")
                    }
                }
            }
            .navigationTitle("AWS Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingIAMInstructions) {
                IAMInstructionsView()
            }
        }
    }
}

struct StepView: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
        }
    }
}

struct IAMInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        
                        Text("Step-by-Step Guide")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Follow these instructions to set up your AWS credentials")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Steps
                    VStack(alignment: .leading, spacing: 24) {
                        DetailedStep(
                            number: 1,
                            title: "Open AWS Console",
                            description: "Sign in to the AWS Management Console and navigate to the IAM service",
                            icon: "globe"
                        )
                        
                        DetailedStep(
                            number: 2,
                            title: "Create IAM User",
                            description: "Click 'Users' in the left sidebar, then 'Add user'. Name it 'Instancify' and select 'Access key - Programmatic access'",
                            icon: "person.fill.badge.plus"
                        )
                        
                        DetailedStep(
                            number: 3,
                            title: "Create Policy",
                            description: "Go to 'Policies' → 'Create policy' → 'JSON'. Paste the policy provided in the previous screen",
                            icon: "doc.text.fill"
                        )
                        
                        DetailedStep(
                            number: 4,
                            title: "Attach Policy",
                            description: "Name the policy 'InstancifyAccess', create it, and attach it to your new IAM user",
                            icon: "link"
                        )
                        
                        DetailedStep(
                            number: 5,
                            title: "Get Credentials",
                            description: "Copy the Access Key ID and Secret Access Key. Store these securely - you won't be able to see the secret key again",
                            icon: "key.fill"
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationTitle("Setup Instructions")
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
}

struct DetailedStep: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Text("\(number)")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                    Text(title)
                        .font(.headline)
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Guide Components
struct GuideSection<Content: View>: View {
    let title: String
    let systemImage: String
    let content: () -> Content
    
    init(title: String, systemImage: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            content()
        }
        .padding(.vertical)
    }
}

struct CodeBlock: View {
    let code: String
    
    init(_ code: String) {
        self.code = code
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(code)
                .font(.system(.body, design: .monospaced))
                .padding()
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    AWSSetupGuideView()
} 