//
//  AppUser.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-08-10.
//

import Foundation
import FirebaseFirestore

struct AppUser: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var email: String?
    var phone: String?
    var isSystemAdmin: Bool = false
    
    // MARK: - Multi-Tenant Data
    var storeIds: [String] = []
    var storeRoles: [String: String] = [:] // Example: ["storeA": "admin", "storeB": "customer"]
    var activeStoreId: String?
    
    var autoJoinStoreId: String?
    
    // MARK: - Backward Compatibility
    // This ensures all our existing `session.currentUser?.role == .admin` checks still work perfectly!
    var storeId: String? {
        get { activeStoreId }
        set { activeStoreId = newValue }
    }
    
    var role: UserRole {
        get {
            guard let active = activeStoreId, let roleString = storeRoles[active] else { return .guest }
            return UserRole(rawValue: roleString) ?? .guest
        }
        set {
            if let active = activeStoreId {
                storeRoles[active] = newValue.rawValue
            }
        }
    }
}

enum UserRole: String, Codable {
    case admin, employee, customer, guest
}
