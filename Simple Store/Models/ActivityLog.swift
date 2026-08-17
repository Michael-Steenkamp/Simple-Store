//
// ActivityLog.swift
// Simple Store
//

import Foundation
import SwiftData

/// Represents an immutable, persistent audit trail event for the workspace.
@Model
public final class ActivityLog {
    @Attribute(.unique) public var id: UUID
    public var storeId: String
    public var timestamp: Date
    public var title: String
    public var category: String
    public var isRead: Bool
    public var count: Int
    public var groupingKey: String?
    public var targetRoles: [String]
    public var targetUserIds: [String]
    
    public init(
            id: UUID = UUID(),
            storeId: String,
            timestamp: Date = Date(),
            title: String,
            category: String,
            isRead: Bool = false,
            count: Int = 1,
            groupingKey: String? = nil,
            targetRoles: [String] = [],
            targetUserIds: [String] = []
        ) {
            self.id = id
            self.storeId = storeId
            self.timestamp = timestamp
            self.title = title
            self.category = category
            self.isRead = isRead
            self.count = count
            self.groupingKey = groupingKey
            self.targetRoles = targetRoles
            self.targetUserIds = targetUserIds
        }
}

// MARK: - Data Transfer Object

public struct ActivityLogDTO: Codable, Sendable, Identifiable {
    public let id: String
    public let storeId: String
    public let timestamp: Date
    public let title: String
    public let category: String
    
    public init(from model: ActivityLog) {
        self.id = model.id.uuidString
        self.storeId = model.storeId
        self.timestamp = model.timestamp
        self.title = model.title
        self.category = model.category
    }
}
