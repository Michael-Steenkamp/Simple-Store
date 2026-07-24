//
//  String+Formatting.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-07-22.
//

import Foundation

extension String {
    /// Cleans and formats a string into a standard phone number format: (XXX) XXX-XXXX
    func formattedAsPhoneNumber() -> String {
        // Remove all non-numeric characters
        let numbers = self.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        // Format standard 10-digit numbers
        if numbers.count == 10 {
            let areaCode = numbers.prefix(3)
            let prefix = numbers.dropFirst(3).prefix(3)
            let line = numbers.dropFirst(6)
            return "(\(areaCode)) \(prefix)-\(line)"
        }
        // Format 11-digit numbers starting with country code 1
        else if numbers.count == 11 && numbers.hasPrefix("1") {
            let areaCode = numbers.dropFirst(1).prefix(3)
            let prefix = numbers.dropFirst(4).prefix(3)
            let line = numbers.dropFirst(7)
            return "+1 (\(areaCode)) \(prefix)-\(line)"
        }
        
        // If it doesn't match standard lengths (e.g. international), return as-is
        return self
    }
}
