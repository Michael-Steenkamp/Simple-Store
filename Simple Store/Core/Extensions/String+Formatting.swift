//
//  String+Formatting.swift
//  Simple Store
//


import Foundation

public extension String {
    
    /// Sanitizes and formats the current string into a standard North American phone number.
    ///
    /// - Returns: A formatted phone number string (e.g., `(555) 555-5555` or `+1 (555) 555-5555`).
    /// Returns the unmodified original string if it does not conform to standard 10 or 11-digit parameters.
    var formattedAsPhoneNumber: String {
        let digits = self.replacing(#/\D/#, with: "")
        
        switch digits.count {
        case 10:
            return formatDigits(digits, hasCountryCode: false)
        case 11 where digits.hasPrefix("1"):
            return formatDigits(digits, hasCountryCode: true)
        default:
            return self
        }
    }
    
    // MARK: - Private Helpers
    
    private func formatDigits(_ digits: String, hasCountryCode: Bool) -> String {
        let offset = hasCountryCode ? 1 : 0
        
        let areaCode = digits.dropFirst(offset).prefix(3)
        let prefix = digits.dropFirst(offset + 3).prefix(3)
        let line = digits.dropFirst(offset + 6).prefix(4)
        
        let formattedNumber = "(\(areaCode)) \(prefix)-\(line)"
        return hasCountryCode ? "+1 \(formattedNumber)" : formattedNumber
    }
}
