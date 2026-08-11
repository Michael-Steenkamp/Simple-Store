//
//  ItemTag.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-07-16.
//

import Foundation
import SwiftData

@Model
final class ItemTag {
    var id: UUID = UUID()
    var storeId: String? // NEW: Added for multi-tenant cloud routing
    var name: String = ""
    
    // The inverse array must be optional for CloudKit/Firestore mapping
    var items: [StoreItem]? = []
    
    init(id: UUID = UUID(), storeId: String? = nil, name: String) {
        self.id = id
        self.storeId = storeId
        self.name = name
        self.items = []
    }
}
