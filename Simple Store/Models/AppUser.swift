//
// AppUser.swift
// Simple Store
//

import Foundation
import FirebaseFirestore

/// Defines the permission level of a user within a specific store workspace.
public enum UserRole: String, Codable, Sendable {
    case admin
    case employee
    case customer
    case guest
}

/// A representation of an authenticated user and their multi-tenant access control.
///
/// `AppUser` maps directly to Firestore and handles workspace isolation by tracking
/// the user's role across different stores. It is completely thread-safe for use across actor boundaries.
public struct AppUser: Codable, Identifiable, Sendable {
    
    /// The unique Firestore document identifier.
    @DocumentID public var id: String?
    
    /// The user's display name.
    public var name: String
    
    /// The user's email address.
    public var email: String?
    
    /// The user's contact phone number.
    public var phone: String?
    
    /// A flag indicating if the user has overarching system administration privileges.
    public var isSystemAdmin: Bool = false
    
    // MARK: - Multi-Tenant Data
    
    /// An array of store identifiers the user has been granted access to.
    public var storeIds: [String] = []
    
    /// A mapping of store identifiers to the user's specific role within that store.
    public var storeRoles: [String: String] = [:]
    
    /// The identifier of the currently active store workspace.
    public var activeStoreId: String?
    
    /// The identifier of a store the user should automatically join upon authentication.
    public var autoJoinStoreId: String?
    
    public init(
        id: String? = nil,
        name: String,
        email: String? = nil,
        phone: String? = nil,
        isSystemAdmin: Bool = false,
        storeIds: [String] = [],
        storeRoles: [String: String] = [:],
        activeStoreId: String? = nil,
        autoJoinStoreId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.isSystemAdmin = isSystemAdmin
        self.storeIds = storeIds
        self.storeRoles = storeRoles
        self.activeStoreId = activeStoreId
        self.autoJoinStoreId = autoJoinStoreId
    }
    
    // MARK: - Legacy Compatibility
    
    /// A backward-compatible alias for the active store identifier.
    public var storeId: String? {
        get { activeStoreId }
        set { activeStoreId = newValue }
    }
    
    /// A backward-compatible alias that resolves the user's role for the currently active store.
    /// Returns `.guest` if no active store is set or if the role mapping is missing.
    public var role: UserRole {
        get {
            guard let active = activeStoreId, let roleString = storeRoles[active] else {
                return .guest
            }
            return UserRole(rawValue: roleString) ?? .guest
        }
        set {
            if let active = activeStoreId {
                storeRoles[active] = newValue.rawValue
            }
        }
    }
}
