import SwiftUI
import AWSEC2
import BackgroundTasks
import UserNotifications

struct InstanceRowView: View {
    let instance: EC2Instance
    @Binding var isAutoStopEnabled: Bool
    @State private var showingAutoStopPicker = false
    @State private var countdown: TimeInterval?
    @State private var selectedHours = 1
    @State private var selectedMinutes = 0
    @State private var isCustomTime = false
    @State private var localAutoStopEnabled: Bool
    @State private var remainingTime: TimeInterval?
    @State private var timer: Timer?
    @State private var lastRefreshTime: Date = Date()
    @EnvironmentObject private var appearanceViewModel: AppearanceSettingsViewModel
    @EnvironmentObject private var viewModel: DashboardViewModel
    var onAutoStopToggle: (Bool) -> Void
    @Environment(\.scenePhase) private var scenePhase
    
    private let presetHours = [1, 2, 4, 8, 12, 24]
    
    init(instance: EC2Instance, isAutoStopEnabled: Binding<Bool>, onAutoStopToggle: @escaping (Bool) -> Void) {
        self.instance = instance
        self._isAutoStopEnabled = isAutoStopEnabled
        self.onAutoStopToggle = onAutoStopToggle
        self._localAutoStopEnabled = State(initialValue: instance.autoStopEnabled)
        
        // Initialize countdown and remaining time with proper elapsed time calculation
        if let instanceCountdown = instance.countdown,
           let countdownValue = Double(instanceCountdown) {
            print("📱 [\(instance.id)] Initial countdown from instance: \(instanceCountdown)")
            let currentTime = Date()
            let elapsedTime = currentTime.timeIntervalSince(instance.stateTransitionTime ?? currentTime)
            let adjustedCountdown = max(0, countdownValue - elapsedTime)
            
            print("📱 [\(instance.id)] Elapsed time since last state change: \(elapsedTime)")
            print("📱 [\(instance.id)] Adjusted countdown: \(adjustedCountdown)")
            
            self._countdown = State(initialValue: adjustedCountdown)
            self._remainingTime = State(initialValue: adjustedCountdown)
            
            if adjustedCountdown <= 0 {
                print("⚠️ [\(instance.id)] Countdown has expired, will disable auto-stop")
                self._localAutoStopEnabled = State(initialValue: false)
            }
        }
    }
    
    private var formattedInstanceId: String {
        let parts = instance.id.split(separator: "-")
        if parts.count > 1 {
            return "\(parts[0])-\(parts[1...].joined(separator: "-"))"
        }
        return instance.id
    }
    
    private func sendNotification(title: String, body: String, identifier: String) {
        Task {
            do {
                // Send via FCM for reliable delivery in all app states
                try await FirebaseNotificationService.shared.sendPushNotification(
                    title: title == "TIME SENSITIVE" ? "Auto-Stop Timer" : title,
                    body: body,
                    data: [
                        "instanceId": instance.id,
                        "type": identifier,
                        "timestamp": "\(Date().timeIntervalSince1970)"
                    ]
                )
                print("✅ [\(instance.id)] Push notification sent: \(title)")
            } catch {
                print("❌ [\(instance.id)] Failed to send push notification: \(error)")
            }
        }
    }
    
    private func setupCountdownTimer() {
        // Stop any existing timer first
        stopCountdownTimer()
        
        if let countdownValue = countdown {
            print("⏱️ [\(instance.id)] Setting up timer with countdown: \(countdownValue)")
            
            // Calculate and save the absolute end time
            let endTime = Date().addingTimeInterval(countdownValue)
            UserDefaults.standard.set(endTime.timeIntervalSince1970, forKey: "autoStopEndTime_\(instance.id)")
            
            // Create a repeating timer that fires every second
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
                let now = Date()
                let remaining = endTime.timeIntervalSince(now)
                print("⏱️ [\(instance.id)] Countdown: \(Int(remaining))s remaining")
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    // Update remaining time
                    remainingTime = remaining
                    
                    // Send warning notifications at specific intervals
                    let remainingSeconds = Int(remaining)
                    if remainingSeconds <= 0 {
                        print("⏱️ [\(instance.id)] Countdown completed")
                        stopCountdownTimer()
                        handleAutoStop()
                        return
                    }
                    
                    // Check for warning thresholds based on notification settings
                    if NotificationSettingsViewModel.shared.autoStopWarningsEnabled {
                        let warningIntervals = NotificationSettingsViewModel.shared.selectedWarningIntervals
                        if warningIntervals.contains(remainingSeconds) {
                            print("⚠️ [\(instance.id)] Warning at \(remainingSeconds)s")
                            let formattedTime = formatTimeRemaining(remainingSeconds)
                            sendNotification(
                                title: "Auto-Stop Warning",
                                body: "Instance will stop in \(formattedTime)",
                                identifier: "autostop_warning"
                            )
                        }
                    }
                }
            }
            
            // Set initial remaining time
            remainingTime = countdownValue
            print("⏱️ [\(instance.id)] Timer initialized with end time: \(endTime)")
            
            // Save the auto-stop state
            saveAutoStopState()
            
            // Schedule background task
            scheduleBackgroundTask(endTime: endTime)
            
            // Send initial notification if enabled
            if NotificationSettingsViewModel.shared.autoStopCountdownEnabled {
                sendNotification(
                    title: "Auto-Stop Timer",
                    body: "Instance will stop in \(formatTimeRemaining(Int(countdownValue)))",
                    identifier: "autostop_start"
                )
            }
        } else {
            print("⚠️ [\(instance.id)] No countdown value available")
        }
    }
    
    private func formatTimeRemaining(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")\(minutes > 0 ? " \(minutes) minute\(minutes == 1 ? "" : "s")" : "")"
        } else if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            return "\(seconds) second\(seconds == 1 ? "" : "s")"
        }
    }
    
    private func scheduleBackgroundTask(endTime: Date) {
        let request = BGProcessingTaskRequest(identifier: "com.instancify.autostop")
        request.earliestBeginDate = endTime
        request.requiresNetworkConnectivity = true
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ [\(instance.id)] Scheduled background task for: \(endTime)")
        } catch {
            print("❌ [\(instance.id)] Failed to schedule background task: \(error)")
        }
    }
    
    private func checkAndRestoreTimer() {
        let defaults = UserDefaults.standard
        let endTimeInterval = defaults.double(forKey: "autoStopEndTime_\(instance.id)")
        
        if endTimeInterval > 0 {
            let endTime = Date(timeIntervalSince1970: endTimeInterval)
            let remaining = endTime.timeIntervalSince(Date())
            
            print("🔄 [\(instance.id)] Checking timer state: endTime=\(endTime), remaining=\(remaining)s")
            
            if remaining > 0 {
                countdown = remaining
                remainingTime = remaining
                setupCountdownTimer()
                print("✅ [\(instance.id)] Restored timer with \(Int(remaining))s remaining")
            } else {
                print("⏱️ [\(instance.id)] Timer has expired, triggering auto-stop")
                handleAutoStop()
            }
        }
    }
    
    private func saveAutoStopState() {
        let defaults = UserDefaults.standard
        let key = "autoStop_\(instance.id)"
        
        // Only save if we have an active timer
        if localAutoStopEnabled && countdown != nil {
            let endTimeInterval = defaults.double(forKey: "autoStopEndTime_\(instance.id)")
            let data: [String: Any] = [
                "enabled": true,
                "endTime": endTimeInterval
            ]
            defaults.set(data, forKey: key)
            print("💾 [\(instance.id)] Saved auto-stop state: endTime=\(Date(timeIntervalSince1970: endTimeInterval))")
        } else {
            defaults.removeObject(forKey: key)
            defaults.removeObject(forKey: "autoStopEndTime_\(instance.id)")
            print("💾 [\(instance.id)] Cleared auto-stop state")
        }
    }
    
    private func loadAutoStopState() {
        let defaults = UserDefaults.standard
        let key = "autoStop_\(instance.id)"
        
        if let data = defaults.dictionary(forKey: key),
           let enabled = data["enabled"] as? Bool,
           enabled {  // Only restore if it was enabled
            let endTimeInterval = defaults.double(forKey: "autoStopEndTime_\(instance.id)")
            
            if endTimeInterval > 0 {
                let endTime = Date(timeIntervalSince1970: endTimeInterval)
                let remaining = endTime.timeIntervalSince(Date())
                print("📱 [\(instance.id)] Loading state: endTime=\(endTime), remaining=\(remaining)s")
                
                if remaining > 0 {
                    self.countdown = remaining
                    self.localAutoStopEnabled = true
                    self.isAutoStopEnabled = true
                    setupCountdownTimer()
                    print("✅ [\(instance.id)] Restored timer with \(Int(remaining))s remaining")
                } else {
                    print("⏱️ [\(instance.id)] Timer has expired, triggering auto-stop")
                    clearAutoStopState()
                    handleAutoStop()
                }
            } else {
                print("⚠️ [\(instance.id)] No valid end time found")
                clearAutoStopState()
            }
        } else {
            print("📱 [\(instance.id)] No saved state found or state was disabled")
        }
    }
    
    private func clearAutoStopState() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "autoStop_\(instance.id)")
        defaults.removeObject(forKey: "autoStopEndTime_\(instance.id)")
        localAutoStopEnabled = false
        isAutoStopEnabled = false
        countdown = nil
        remainingTime = nil
        stopCountdownTimer()
        print("🗑️ [\(instance.id)] Cleared auto-stop state")
    }
    
    private func handleAutoStop() {
        withAnimation {
            // First disable auto-stop locally
            localAutoStopEnabled = false
            isAutoStopEnabled = false
            
            // Clear countdown state
            countdown = nil
            remainingTime = nil
            
            // Clear saved state
            clearAutoStopState()
            
            // Log activity
            InstanceActivity.addActivity(
                instanceId: instance.id,
                type: .autoStop,
                details: "Auto-stop timer completed",
                runtime: calculateRuntime(),
                cost: (calculateRuntime() / 3600.0) * instance.hourlyRate
            )
            
            // Send final notification if enabled
            if NotificationSettingsViewModel.shared.autoStopWarningsEnabled {
                sendNotification(
                    title: "Auto-Stop Timer",
                    body: "Instance is stopping",
                    identifier: "autostop_stopping"
                )
            }
            
            // Actually stop the instance
            Task {
                print("🛑 [\(instance.id)] Initiating instance stop...")
                
                // First stop the auto-stop feature
                await viewModel.toggleAutoStop(for: instance.id, enabled: false)
                
                // Then stop the instance itself
                do {
                    try await EC2Service.shared.stopInstance(instance.id)
                    print("✅ [\(instance.id)] Instance stop command sent successfully")
                    
                    // Send generic state notification
                    sendNotification(
                        title: "Instance Status",
                        body: "Instance has been stopped",
                        identifier: "instance_stopped"
                    )
                    
                    // Notify parent about auto-stop state change
                    onAutoStopToggle(false)
                    
                    print("✅ [\(instance.id)] Auto-stop sequence completed")
                } catch {
                    print("❌ [\(instance.id)] Failed to stop instance: \(error)")
                    
                    // Send error notification if enabled
                    sendNotification(
                        title: "Instance Error",
                        body: "Failed to stop instance",
                        identifier: "instance_error"
                    )
                }
            }
        }
    }
    
    private func stopCountdownTimer() {
        print("🛑 [\(instance.id)] Stopping countdown timer")
        timer?.invalidate()
        timer = nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main instance info
            HStack(alignment: .center, spacing: 12) {
                // Status indicator and name
                HStack(spacing: 8) {
                    Circle()
                        .fill(instance.state == .running ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(instance.name ?? "Unnamed Instance")
                                .font(.headline)
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(instance.state.displayString)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(instance.state == .running ? Color.green : Color.secondary)
                        }
                        Text(formattedInstanceId)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Runtime for running instances
                if instance.state == .running {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .foregroundStyle(appearanceViewModel.currentAccentColor)
                        Text(Calendar.formatRuntime(from: instance.launchTime))
                            .font(.subheadline)
                            .foregroundStyle(appearanceViewModel.currentAccentColor)
                    }
                }
            }
            
            // Auto-stop controls (only for running instances)
            if instance.state == .running {
                Divider()
                
                VStack(spacing: 8) {
                    // Auto-stop toggle with label
                    HStack {
                        Label("Auto-stop", systemImage: "timer")
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { localAutoStopEnabled },
                            set: { newValue in
                                withAnimation {
                                    print("🔄 [\(instance.id)] Toggle changed to: \(newValue)")
                                    localAutoStopEnabled = newValue
                                    isAutoStopEnabled = newValue
                                    if !newValue {
                                        print("🛑 [\(instance.id)] Auto-stop disabled")
                                        countdown = nil
                                        stopCountdownTimer()
                                    }
                                    onAutoStopToggle(newValue)
                                    if newValue && countdown == nil {
                                        showingAutoStopPicker = true
                                    }
                                }
                            }
                        ))
                        .labelsHidden()
                    }
                    
                    // Timer display/button (only when auto-stop is enabled)
                    if localAutoStopEnabled {
                        Button {
                            isCustomTime = false
                            showingAutoStopPicker = true
                        } label: {
                            HStack {
                                if let remaining = remainingTime {
                                    let hours = Int(remaining / 3600)
                                    let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
                                    let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
                                    let timeString = {
                                        if hours > 0 {
                                            return "Stops in \(hours)h \(minutes)m"
                                        } else if minutes > 0 {
                                            return "Stops in \(minutes)m \(seconds)s"
                                        } else {
                                            return "Stops in \(seconds)s"
                                        }
                                    }()
                                    Label(
                                        title: { Text(timeString) },
                                        icon: { Image(systemName: "clock.badge.checkmark") }
                                    )
                                    .foregroundStyle(.green)
                                } else {
                                    Label(
                                        "Set stop timer",
                                        systemImage: "clock.badge.exclamationmark"
                                    )
                                    .foregroundStyle(.orange)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear {
            print("📱 [\(instance.id)] View appeared")
            checkAndRestoreTimer()
        }
        .onChange(of: instance.autoStopEnabled) { oldValue, newValue in
            withAnimation {
                print("🔄 [\(instance.id)] Instance auto-stop changed: \(oldValue) → \(newValue)")
                localAutoStopEnabled = newValue
                isAutoStopEnabled = newValue
                if !newValue {
                    print("🛑 [\(instance.id)] Auto-stop disabled")
                    clearAutoStopState()
                } else {
                    checkAndRestoreTimer()
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                print("📱 [\(instance.id)] App became active")
                checkAndRestoreTimer()
            case .background:
                print("📱 [\(instance.id)] App entered background")
                saveAutoStopState()
            default:
                break
            }
        }
        .onChange(of: instance.state) { oldState, newState in
            // Send notification on state change
            if oldState != newState {
                sendInstanceStateNotification(state: newState.rawValue)
                
                // Log activity with runtime and cost calculation
                let runtime = calculateRuntime()
                let cost = (runtime / 3600.0) * instance.hourlyRate
                
                InstanceActivity.addActivity(
                    instanceId: instance.id,
                    type: .stateChange(from: oldState.rawValue, to: newState.rawValue),
                    details: "Instance state changed from \(oldState.rawValue) to \(newState.rawValue)",
                    runtime: runtime,
                    cost: cost
                )
                
                // Clean up old activities
                InstanceActivity.cleanupOldActivities(for: instance.id)
            }
        }
        .onDisappear {
            print("👋 [\(instance.id)] View disappeared")
            saveAutoStopState()
            stopCountdownTimer()
        }
        .sheet(isPresented: $showingAutoStopPicker) {
            NavigationView {
                Form {
                    Section {
                        Picker("Timer Type", selection: $isCustomTime) {
                            Text("Preset").tag(false)
                            Text("Custom").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 8)
                    }
                    
                    if isCustomTime {
                        Section {
                            Stepper("Hours: \(selectedHours)", value: $selectedHours, in: 0...24)
                            Stepper("Minutes: \(selectedMinutes)", value: $selectedMinutes, in: 0...59)
                        } footer: {
                            Text("Set a custom duration")
                        }
                    } else {
                        Section {
                            ForEach(presetHours, id: \.self) { hours in
                                Button {
                                    selectedHours = hours
                                    selectedMinutes = 0
                                    setTimer()
                                } label: {
                                    HStack {
                                        Text("\(hours) hour\(hours == 1 ? "" : "s")")
                                        Spacer()
                                        if selectedHours == hours && !isCustomTime {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(appearanceViewModel.currentAccentColor)
                                        }
                                    }
                                }
                            }
                        } footer: {
                            Text("Choose a preset duration")
                        }
                    }
                    
                    if isCustomTime {
                        Section {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Text("Stops at")
                                        .foregroundStyle(.secondary)
                                    Text(Date().addingTimeInterval(TimeInterval(selectedHours * 3600 + selectedMinutes * 60)), style: .time)
                                        .font(.system(.title3, design: .rounded))
                                        .fontWeight(.medium)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        
                        Section {
                            Button("Set Timer") {
                                setTimer()
                            }
                            .disabled(selectedHours == 0 && selectedMinutes == 0)
                        }
                    }
                }
                .navigationTitle("Auto-Stop Timer")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if isCustomTime {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingAutoStopPicker = false
                            }
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showingAutoStopPicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    private func setTimer() {
        let totalSeconds = Double(selectedHours * 3600 + selectedMinutes * 60)
        print("⏱️ [\(instance.id)] Setting timer for \(totalSeconds) seconds")
        
        // Update state
        countdown = totalSeconds
        remainingTime = totalSeconds
        localAutoStopEnabled = true
        isAutoStopEnabled = true
        lastRefreshTime = Date()
        
        // Log activity
        let timeString = formatTimeRemaining(Int(totalSeconds))
        InstanceActivity.addActivity(
            instanceId: instance.id,
            type: .autoStop,
            details: "Auto-stop timer set for \(timeString)"
        )
        
        // Setup and start the timer
        setupCountdownTimer()
        
        // Save state
        saveAutoStopState()
        
        // Notify parent
        onAutoStopToggle(true)
        
        // Close the picker
        showingAutoStopPicker = false
        
        print("⏱️ [\(instance.id)] Timer setup complete")
    }
    
    private func sendInstanceStateNotification(state: String) {
        sendNotification(
            title: "Instance Status",
            body: "Instance is now \(state)",
            identifier: "instance_\(state)"
        )
    }
    
    private func calculateRuntime() -> TimeInterval {
        guard let launchTime = instance.launchTime else { return 0 }
        return Date().timeIntervalSince(launchTime)
    }
}

#Preview {
    InstanceRowView(
        instance: EC2Instance(
            id: "i-1234567890abcdef0",
            instanceType: "t2.micro",
            state: .running,
            name: "Test Instance",
            launchTime: Date(),
            publicIP: "1.2.3.4",
            privateIP: "10.0.0.1",
            autoStopEnabled: true,
            countdown: nil,
            stateTransitionTime: nil,
            hourlyRate: 0.0116,
            runtime: 0,
            currentCost: 0.0,
            projectedDailyCost: 0.2784,
            region: "us-west-2"
        ),
        isAutoStopEnabled: .constant(true),
        onAutoStopToggle: { _ in }
    )
    .environmentObject(AppearanceSettingsViewModel.shared)
    .environmentObject(DashboardViewModel())
} 
