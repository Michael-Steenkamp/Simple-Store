//
//  Utilities.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-20.
//
import Foundation

extension String {
    
    /// Formats a string into a standardized phone number format (e.g. +1 (555) 123-4567)
    func formattedAsPhoneNumber() -> String {
        let digits = self.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let count = digits.count
        
        guard count >= 7 && count <= 15 else {
            return digits.isEmpty ? self : digits
        }
        
        if count <= 7 {
            let suffix = digits.suffix(4)
            let prefix = digits.prefix(count - 4)
            return "\(prefix)-\(suffix)"
        } else if count <= 10 {
            let suffix = digits.suffix(4)
            
            let middleStart = digits.index(digits.endIndex, offsetBy: -7)
            let middle = digits[middleStart..<digits.index(middleStart, offsetBy: 3)]
            let area = digits.prefix(count - 7)
            
            if count == 10 {
                return "(\(area)) \(middle)-\(suffix)"
            } else {
                return "\(area)-\(middle)-\(suffix)"
            }
        } else {
            let suffix = digits.suffix(4)
            
            let middleStart = digits.index(digits.endIndex, offsetBy: -7)
            let middle = digits[middleStart..<digits.index(middleStart, offsetBy: 3)]
            
            let areaStart = digits.index(digits.endIndex, offsetBy: -10)
            let area = digits[areaStart..<digits.index(areaStart, offsetBy: 3)]
            
            let country = digits.prefix(count - 10)
            return "+\(country) (\(area)) \(middle)-\(suffix)"
        }
    }
}
