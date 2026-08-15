//
//  String+Validation.swift
//  Simple Store
//

import Foundation

public extension String {
    
    /// Validates whether the current string conforms to the standard HTML5 email specification.
    ///
    /// This property automatically strips leading and trailing whitespace and newline characters
    /// before evaluating the string.
    ///
    /// - Returns: `true` if the string is a valid email format, otherwise `false`.
    var isValidEmail: Bool {
        let trimmedEmail = self.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Utilizing modern Swift 5.7+ Regex infrastructure instead of legacy NSPredicate
        let emailPattern = #"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"#
        
        guard let regex = try? Regex(emailPattern) else {
            return false
        }
        
        return trimmedEmail.wholeMatch(of: regex) != nil
    }
}
