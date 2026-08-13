//
// StoreItem.swift
// Simple Store
//

import Foundation
import SwiftData

/// A SwiftData model representing a physical inventory item within a specific store workspace.
///
/// `StoreItem` serves strictly as the local offline-first source of truth. Due to Swift 6
/// concurrency constraints, do not pass instances of this model across actor boundaries.
/// Utilize `StoreItemDTO` for remote synchronization and background processing.
@Model
public final class StoreItem {
    
    /// The unique identifier for the item.
    @Attribute(.unique) public var id: UUID
    
    /// The unique identifier of the tenant/workspace this item belongs to.
    public var storeId: String
    
    /// The display name of the item.
    public var name: String
    
    /// An optional detailed description of the item.
    public var desc: String?
    
    /// The current on-hand stock quantity.
    public var stockCount: Int
    
    /// The retail sales price.
    public var salesPrice: Double
    
    /// The wholesale cost of the item.
    public var itemCost: Double
    
    /// The date the item was added to the store's inventory.
    public var inStoreDate: Date
    
    /// The timestamp of the last modification, utilized for sync conflict resolution.
    public var updatedAt: Date
    
    /// The barcode or SKU string for hardware scanner lookup.
    public var barcode: String?
    
    /// Indicates whether the item is active and visible in the POS checkout flow.
    public var isActive: Bool
    
    /// Associated categorization tags.
    @Relationship(inverse: \ItemTag.items)
    public var tags: [ItemTag]?
    
    /// Local cached image data, stored externally to maintain lightweight SQLite queries.
    @Attribute(.externalStorage)
    public var imageData: Data?
    
    /// The remote Cloud Storage URL mapping for the item's image.
    public var imageURL: String?
    
    public init(
        id: UUID = UUID(),
        storeId: String,
        tags: [ItemTag] = [],
        name: String,
        desc: String? = nil,
        stockCount: Int = 0,
        salesPrice: Double = 0.0,
        itemCost: Double = 0.0,
        inStoreDate: Date = Date(),
        barcode: String? = nil,
        isActive: Bool = true,
        imageData: Data? = nil,
        imageURL: String? = nil
    ) {
        self.id = id
        self.storeId = storeId
        self.tags = tags
        self.name = name
        self.desc = desc
        self.stockCount = stockCount
        self.salesPrice = salesPrice
        self.itemCost = itemCost
        self.inStoreDate = inStoreDate
        self.updatedAt = Date()
        self.barcode = barcode
        self.isActive = isActive
        self.imageData = imageData
        self.imageURL = imageURL
    }
}

// MARK: - Data Transfer Object

/// A thread-safe, `Sendable` representation of a `StoreItem` for network synchronization.
public struct StoreItemDTO: Codable, Sendable, Identifiable {
    public let id: String
    public let storeId: String
    public let name: String
    public let desc: String?
    public let stockCount: Int
    public let salesPrice: Double
    public let itemCost: Double
    public let inStoreDate: Date
    public let updatedAt: Date
    public let barcode: String?
    public let isActive: Bool
    public let imageURL: String?
    
    /// Initializes a DTO directly from a local SwiftData model.
    public init(from model: StoreItem) {
        self.id = model.id.uuidString
        self.storeId = model.storeId
        self.name = model.name
        self.desc = model.desc
        self.stockCount = model.stockCount
        self.salesPrice = model.salesPrice
        self.itemCost = model.itemCost
        self.inStoreDate = model.inStoreDate
        self.updatedAt = model.updatedAt
        self.barcode = model.barcode
        self.isActive = model.isActive
        self.imageURL = model.imageURL
    }
}
