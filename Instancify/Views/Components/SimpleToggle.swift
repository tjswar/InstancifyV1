// Instancify/Views/Components/SimpleToggle.swift
import SwiftUI

struct SimpleToggle: View {
    @Binding var isOn: Bool
    var label: String
    
    var body: some View {
        PrimitiveToggle(isOn: $isOn, label: label)
    }
}
//
//  SimpleToggle.swift
//  Instancify
//
//  Created by Dalli Sai Tejaswar Reddy on 2/5/25.
//

