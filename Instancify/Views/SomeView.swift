// Instancify/Views/SomeView.swift
import SwiftUI

struct SomeView: View {
    @State private var featureEnabled = false
    
    var body: some View {
        VStack {
            PrimitiveToggle(isOn: $featureEnabled, label: "Feature Status")
            Text(featureEnabled ? "ON" : "OFF")
                .font(.system(size: 12, weight: .bold))
        }
        .padding()
    }
}

#Preview {
    SomeView()
} 
