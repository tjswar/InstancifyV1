import SwiftUI

struct AppLockPasswordView: View {
    @EnvironmentObject private var appearanceViewModel: AppearanceSettingsViewModel
    @EnvironmentObject private var appLockService: AppLockService
    @Environment(\.dismiss) private var dismiss
    
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isChangingPassword = false
    @State private var currentPassword = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    PrimitiveToggle(
                        isOn: Binding(
                            get: { appLockService.isPasswordSet() },
                            set: { isEnabled in
                                if !isEnabled {
                                    appLockService.removePassword()
                                }
                            }
                        ),
                        label: "Enable PIN Lock"
                    )
                } header: {
                    Text("PIN Protection")
                } footer: {
                    Text("Enable to protect the app with a 4-digit PIN")
                }
                
                if appLockService.isPasswordSet() {
                    // Change Password
                    Section {
                        if isChangingPassword {
                            SecureField("Current PIN", text: $currentPassword)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                            
                            SecureField("New PIN", text: $password)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                            
                            SecureField("Confirm New PIN", text: $confirmPassword)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                            
                            if showPassword {
                                Text("PIN: \(password)")
                                    .foregroundStyle(.secondary)
                            }
                            
                            PrimitiveToggle(
                                isOn: $showPassword,
                                label: "Show PIN"
                            )
                            
                            Button("Save New PIN") {
                                changePassword()
                            }
                            .disabled(currentPassword.isEmpty || password.count != 4 || password != confirmPassword || !password.allSatisfy { $0.isNumber })
                        } else {
                            Button("Change PIN") {
                                isChangingPassword = true
                            }
                        }
                        
                        Button("Remove PIN", role: .destructive) {
                            appLockService.removePassword()
                            dismiss()
                        }
                    } header: {
                        Text("Manage PIN")
                    }
                } else {
                    // Set New Password
                    Section {
                        SecureField("Enter PIN", text: $password)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                        
                        SecureField("Confirm PIN", text: $confirmPassword)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                        
                        if showPassword {
                            Text("PIN: \(password)")
                                .foregroundStyle(.secondary)
                        }
                        
                        PrimitiveToggle(
                            isOn: $showPassword,
                            label: "Show PIN"
                        )
                    } header: {
                        Text("Set PIN")
                    } footer: {
                        Text("PIN must be 4 digits")
                    }
                    
                    Section {
                        Button("Save PIN") {
                            savePassword()
                        }
                        .disabled(password.count != 4 || password != confirmPassword || !password.allSatisfy { $0.isNumber })
                    }
                }
            }
            .navigationTitle("App Lock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func savePassword() {
        guard password.count == 4, password.allSatisfy({ $0.isNumber }) else {
            errorMessage = "PIN must be exactly 4 digits"
            showError = true
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "PINs do not match"
            showError = true
            return
        }
        
        appLockService.setPassword(password)
        password = ""
        confirmPassword = ""
        dismiss()
    }
    
    private func changePassword() {
        guard appLockService.unlock(with: currentPassword) else {
            errorMessage = "Current PIN is incorrect"
            showError = true
            return
        }
        
        guard password.count == 4, password.allSatisfy({ $0.isNumber }) else {
            errorMessage = "PIN must be exactly 4 digits"
            showError = true
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "PINs do not match"
            showError = true
            return
        }
        
        appLockService.setPassword(password)
        password = ""
        confirmPassword = ""
        currentPassword = ""
        isChangingPassword = false
        dismiss()
    }
} 