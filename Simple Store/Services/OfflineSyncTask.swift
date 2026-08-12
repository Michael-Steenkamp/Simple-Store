//
//  OfflineSyncTask.swift
//  Simple Store
//

import Foundation
import SwiftData

@Model
final class OfflineSyncTask {
    var id: UUID
    var storeId: String
    var collection: String
    var documentId: String
    var payloadData: Data?
    var operation: String
    var timestamp: Date
    
    init(storeId: String, collection: String, documentId: String, payload: [String: Any]?, operation: String) {
        self.id = UUID()
        self.storeId = storeId
        self.collection = collection
        self.documentId = documentId
        self.operation = operation
        self.timestamp = Date()
        
        if let payload = payload {
            var safePayload = payload
            
            // MARK: - Crash Fix
            // JSONSerialization will fatally crash if it encounters a native Date object.
            // We safely convert any Dates into a dictionary representation for offline storage.
            for (key, value) in safePayload {
                if let date = value as? Date {
                    safePayload[key] = ["__type": "Date", "value": date.timeIntervalSince1970]
                }
            }
            
            self.payloadData = try? JSONSerialization.data(withJSONObject: safePayload)
        }
    }
    
    @Transient
    var payload: [String: Any]? {
        guard let data = payloadData,
              var dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        
        // Reconstruct the native Date objects so Firebase can successfully save them as Firestore Timestamps
        for (key, value) in dict {
            if let nested = value as? [String: Any],
               nested["__type"] as? String == "Date",
               let time = nested["value"] as? Double {
                dict[key] = Date(timeIntervalSince1970: time)
            }
        }
        return dict
    }
}
