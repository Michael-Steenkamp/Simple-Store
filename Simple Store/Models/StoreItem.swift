//
//  StoreItem.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-16.
//

import Foundation
import SwiftData

@Model
final class StoreItem {
    var id: UUID = UUID()
    var name: String = ""
    var desc: String?
    var stockCount: Int = 0
    var salesPrice: Double = 0.0
    var itemCost: Double = 0.0
    var inStoreDate: Date = Date()
    var updatedAt: Date = Date()
    var barcode: String?
    var isActive: Bool = true
    
    @Relationship(inverse: \ItemTag.items)
    var tags: [ItemTag]? = []
    
    // .externalStorage tells SwiftData to save large photos outside the main database file to keep queries fast
    @Attribute(.externalStorage)
    var imageData: Data?
    
    init(id: UUID = UUID(), tags: [ItemTag] = [], name: String, desc: String? = nil, stockCount: Int = 0, salesPrice: Double = 0.0, itemCost: Double = 0.0, inStoreDate: Date = Date(), barcode: String? = nil, isActive: Bool = true, imageData: Data? = nil) {
        self.id = id
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
    }
}
