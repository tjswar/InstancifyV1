import Foundation
import SwiftUI

final class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var connections: [AWSConnection] = []
    @Published var selectedConnection: AWSConnection?
    @Published var hasCompletedOnboarding = false
    
    init() {
        loadConnections()
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
    
    func addConnection(_ connection: AWSConnection) {
        connections.append(connection)
        saveConnections()
    }
    
    func removeConnection(_ connection: AWSConnection) {
        connections.removeAll { $0.id == connection.id }
        saveConnections()
    }
    
    private func saveConnections() {
        if let encoded = try? JSONEncoder().encode(connections) {
            UserDefaults.standard.set(encoded, forKey: "awsConnections")
        }
    }
    
    private func loadConnections() {
        if let data = UserDefaults.standard.data(forKey: "awsConnections"),
           let decoded = try? JSONDecoder().decode([AWSConnection].self, from: data) {
            connections = decoded
        }
    }
    
    #if DEBUG
    static var preview: AppState {
        let state = AppState()
        state.hasCompletedOnboarding = true
        state.connections = []  // Start with empty connections for preview
        return state
    }
    #endif
} 