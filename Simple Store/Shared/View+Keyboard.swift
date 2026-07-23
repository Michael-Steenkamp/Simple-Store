//
//  View+Keyboard.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-07-22.
//

import SwiftUI

extension View {
    /// Forces the keyboard to dismiss by resigning the active text field.
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    /// A convenient modifier to add to any root view (like Forms, VStacks, or ZStacks)
    /// to drop the keyboard when tapping empty space.
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            hideKeyboard()
        }
    }
}
