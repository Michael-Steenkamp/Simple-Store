//
//  ItemTag.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-16.
//

import Foundation
import SwiftData

@Model
final class ItemTag {
    var id: UUID = UUID()
    var name: String = ""
    
    // The inverse array must be optional for CloudKit
    var items: [StoreItem]? = []
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
        self.items = []
    }
}
