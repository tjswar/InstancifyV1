import SwiftUI

struct OnboardingView: View {
    @State private var showingIAMInstructions = false
    @Environment(\.dismiss) private var dismiss
    
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
                    "ec2:RebootInstances"
                ],
                "Resource": "*"
            }
        ]
    }
    """
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Quick Setup")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("1. Go to AWS IAM Console")
                        Text("2. Create a new IAM User")
                        Text("3. Attach the policy below")
                        Text("4. Copy Access Keys")
                    }
                }
                
                Section(header: Text("Required Policy")) {
                    VStack(alignment: .leading) {
                        Text("Copy this policy:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView {
                            Text(iamPolicyJSON)
                                .font(.system(.caption, design: .monospaced))
                                .padding()
                        }
                        .frame(height: 200)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                        
                        Button {
                            UIPasteboard.general.string = iamPolicyJSON
                            HapticManager.notification(.success)
                        } label: {
                            Label("Copy Policy", systemImage: "doc.on.doc")
                        }
                        .padding(.top, 8)
                    }
                }
                
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
            .navigationTitle("AWS Setup Guide")
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

struct IAMInstructionsView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    InstructionStep(
                        number: 1,
                        title: "Open AWS Console",
                        description: "Go to AWS Management Console and navigate to IAM service"
                    )
                    
                    InstructionStep(
                        number: 2,
                        title: "Create IAM User",
                        description: "Click 'Users' → 'Add user' → Enter name 'Instancify'"
                    )
                    
                    InstructionStep(
                        number: 3,
                        title: "Attach Policy",
                        description: "Create new policy → Paste the policy JSON → Name it 'InstancifyAccess'"
                    )
                    
                    InstructionStep(
                        number: 4,
                        title: "Get Credentials",
                        description: "Create access key → Copy Access Key ID and Secret Access Key"
                    )
                    
                    InstructionStep(
                        number: 5,
                        title: "Connect App",
                        description: "Open Instancify → Paste credentials → Select your region"
                    )
                }
                .padding()
            }
            .navigationTitle("Setup Instructions")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(number)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.accentColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState.shared)
} 