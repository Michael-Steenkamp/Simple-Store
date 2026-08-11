//
//  AppUser.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-08-10.
//

import Foundation

/// Defines the permission levels across the application for a specific store.
enum UserRole: String, Codable {
    case admin
    case employee
    case customer
    case guest
}

/// Represents an authenticated user in the Simple Store ecosystem.
struct AppUser: Identifiable, Codable {
    let id: String
    var email: String?
    var role: UserRole
    var storeId: String?
    var name: String
    var phone: String?
    
    /// A hidden flag used exclusively to bypass StoreKit subscriptions for the developer.
    /// Default is false. You will manually set this to `true` for your own account in the Firebase Console.
    var isSystemAdmin: Bool?
    
    var isGuest: Bool {
        return role == .guest
    }
}
