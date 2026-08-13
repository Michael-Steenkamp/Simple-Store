//
// ItemTag.swift
// Simple Store
//

import Foundation
import SwiftData

/// A SwiftData model representing a categorization tag for inventory items within a specific workspace.
///
/// `ItemTag` serves strictly as the local offline-first source of truth. Due to Swift 6
/// concurrency constraints, do not pass instances of this model across actor boundaries.
/// Utilize `ItemTagDTO` for remote synchronization and background processing.
@Model
public final class ItemTag {
    
    /// The unique identifier for the tag.
    @Attribute(.unique) public var id: UUID
    
    /// The unique identifier of the tenant/workspace this tag belongs to.
    public var storeId: String
    
    /// The display name of the tag.
    public var name: String
    
    /// The inventory items associated with this tag.
    /// Maintained as an optional array to support seamless remote database mapping.
    public var items: [StoreItem]?
    
    public init(
        id: UUID = UUID(),
        storeId: String,
        name: String
    ) {
        self.id = id
        self.storeId = storeId
        self.name = name
        self.items = []
    }
}

// MARK: - Data Transfer Object

/// A thread-safe, `Sendable` representation of an `ItemTag` for network synchronization.
public struct ItemTagDTO: Codable, Sendable, Identifiable {
    public let id: String
    public let storeId: String
    public let name: String
    
    /// Initializes a DTO directly from a local SwiftData model.
    public init(from model: ItemTag) {
        self.id = model.id.uuidString
        self.storeId = model.storeId
        self.name = model.name
    }
}
