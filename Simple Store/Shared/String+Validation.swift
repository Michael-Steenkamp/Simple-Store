//
//  String+Validation.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-07-22.
//

import Foundation

extension String {
    /// Checks if the string is a valid email using the HTML5 specification regex.
    var isValidEmail: Bool {
        let trimmedEmail = self.trimmingCharacters(in: .whitespaces)
        
        let emailRegex = "^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
        
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: trimmedEmail)
    }
}
