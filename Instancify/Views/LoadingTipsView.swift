import SwiftUI

struct LoadingTipsView: View {
    @EnvironmentObject private var appearanceViewModel: AppearanceSettingsViewModel
    @State private var currentTip: String = ""
    @State private var isShowingTip = false
    @State private var tipIndex = 0
    @State private var tipCategory = ""
    @State private var tipDescription = ""
    
    private let tips = [
        // Cost Optimization Tips
        ("Save Money 💰", [
            (
                "Use Instancify's Auto-Stop Feature",
                "Set up automatic instance shutdown during non-working hours to reduce costs by up to 70%"
            ),
            (
                "Right-Size Your Instances",
                "Monitor CPU and memory usage in Instancify to choose the most cost-effective instance type"
            ),
            (
                "Track Your Spending",
                "Use Instancify's cost tracking to monitor daily expenses and optimize your AWS budget"
            )
        ]),
        
        // Performance Tips
        ("Boost Performance ⚡️", [
            (
                "Optimize Storage Performance",
                "Use EBS-optimized instances and provision the right IOPS for your workload type"
            ),
            (
                "Network Performance",
                "Enable enhanced networking and choose the right instance type for network-intensive applications"
            ),
            (
                "Monitor Key Metrics",
                "Track CPU, memory, and network metrics in Instancify to ensure optimal performance"
            )
        ]),
        
        // Security Best Practices
        ("Stay Secure 🔒", [
            (
                "Security Group Management",
                "Use Instancify to easily manage security groups and control instance access"
            ),
            (
                "Regular Updates",
                "Keep your instances secure by regularly updating and patching through AWS Systems Manager"
            ),
            (
                "Data Protection",
                "Enable EBS encryption and use IAM roles to protect sensitive data and access credentials"
            )
        ]),
        
        // Instancify Pro Tips
        ("Pro Tips ✨", [
            (
                "Quick Instance Management",
                "Use Instancify's dashboard to start, stop, and monitor all your instances in one place"
            ),
            (
                "Smart Notifications",
                "Set up alerts for instance state changes and cost thresholds to stay informed"
            ),
            (
                "Region Switching",
                "Easily manage instances across multiple AWS regions with one-click region switching"
            )
        ])
    ]
    
    var body: some View {
        VStack(spacing: 32) {
            // Loading Animation
            VStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(2)
                    .tint(appearanceViewModel.currentAccentColor)
            }
            
            // Tips Section
            VStack(spacing: 16) {
                if isShowingTip {
                    Text(tipCategory)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(appearanceViewModel.currentAccentColor)
                        .transition(.scale.combined(with: .opacity))
                    
                    Text(currentTip)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .transition(.scale.combined(with: .opacity))
                        .padding(.horizontal)
                    
                    Text(tipDescription)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .transition(.scale.combined(with: .opacity))
                        .padding(.horizontal)
                        .frame(maxWidth: 300)
                }
            }
            .frame(height: 160)
            .animation(.spring(duration: 0.6), value: isShowingTip)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
        )
        .onAppear {
            showFirstTip()
        }
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
            showNextTip()
        }
    }
    
    private func showFirstTip() {
        let categoryIndex = Int.random(in: 0..<tips.count)
        let (category, categoryTips) = tips[categoryIndex]
        tipCategory = category
        let (tip, description) = categoryTips.randomElement() ?? categoryTips[0]
        currentTip = tip
        tipDescription = description
        withAnimation {
            isShowingTip = true
        }
    }
    
    private func showNextTip() {
        withAnimation {
            isShowingTip = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            tipIndex = (tipIndex + 1) % tips.count
            let (category, categoryTips) = tips[tipIndex]
            tipCategory = category
            let (tip, description) = categoryTips.randomElement() ?? categoryTips[0]
            currentTip = tip
            tipDescription = description
            withAnimation {
                isShowingTip = true
            }
        }
    }
}

// Lottie Animation View
struct LottieView: View {
    let name: String
    
    var body: some View {
        // Note: You'll need to add the actual Lottie implementation
        // For now, we'll use a placeholder loading animation
        VStack {
            ProgressView()
                .scaleEffect(2)
                .tint(.blue)
            Text("Loading...")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }
} 