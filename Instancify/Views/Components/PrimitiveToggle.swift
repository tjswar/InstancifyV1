//
//  PrimitiveToggle.swift
//  Instancify
//
//  Created by Dalli Sai Tejaswar Reddy on 2/5/25.
//


// Instancify/Views/Components/PrimitiveToggle.swift
import SwiftUI

struct SystemSwitch: UIViewRepresentable {
    @Binding var isOn: Bool
    
    func makeUIView(context: Context) -> UISwitch {
        let switchView = UISwitch()
        switchView.addTarget(
            context.coordinator,
            action: #selector(Coordinator.valueChanged(_:)),
            for: .valueChanged
        )
        return switchView
    }
    
    func updateUIView(_ uiView: UISwitch, context: Context) {
        if uiView.isOn != isOn {
            uiView.isOn = isOn
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator($isOn)
    }
    
    class Coordinator: NSObject {
        var binding: Binding<Bool>
        
        init(_ binding: Binding<Bool>) {
            self.binding = binding
        }
        
        @objc func valueChanged(_ sender: UISwitch) {
            if binding.wrappedValue != sender.isOn {
                binding.wrappedValue = sender.isOn
            }
        }
    }
}

struct PrimitiveToggle: View {
    @Binding var isOn: Bool
    var label: String?
    
    var body: some View {
        HStack {
            if let label = label {
                Text(label)
                Spacer()
            }
            SystemSwitch(isOn: $isOn)
                .fixedSize()
        }
    }
}