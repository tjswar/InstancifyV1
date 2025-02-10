import SwiftUI

struct AppLockSettingsView: View {
    @EnvironmentObject private var appLockService: AppLockService
    @State private var showingPasswordSheet = false
    @State private var selectedTimer: Double
    
    init() {
        _selectedTimer = State(initialValue: AppLockService.shared.getLockTimer())
    }
    
    var body: some View {
        Form {
            Section {
                PrimitiveToggle(
                    isOn: Binding(
                        get: { appLockService.isPasswordSet() },
                        set: { isEnabled in
                            if !isEnabled {
                                appLockService.removePassword()
                            } else {
                                showingPasswordSheet = true
                            }
                        }
                    ),
                    label: "Enable PIN Lock"
                )
                
                if appLockService.isPasswordSet() {
                    Button("Change PIN") {
                        showingPasswordSheet = true
                    }
                    
                    Picker("Auto-Lock Timer", selection: $selectedTimer) {
                        ForEach(AppLockService.lockTimerOptions, id: \.interval) { option in
                            Text(option.label)
                                .tag(option.interval)
                        }
                    }
                    .onChange(of: selectedTimer) { oldValue, newValue in
                        appLockService.setLockTimer(newValue)
                    }
                }
            } header: {
                Text("App Lock")
            } footer: {
                if appLockService.isPasswordSet() {
                    Text("The app will automatically lock after the selected time when going to background")
                } else {
                    Text("Lock the app with a 4-digit PIN")
                }
            }
        }
        .navigationTitle("App Lock")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPasswordSheet) {
            AppLockPasswordView()
        }
    }
} 