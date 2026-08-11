//
//  StorageManager.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-08-11.
//

import Foundation
import FirebaseStorage

@Observable
final class StorageManager {
    static let shared = StorageManager()
    private let storage = Storage.storage().reference()
    
    private init() {}
    
    // MARK: - Store Logo Upload
    func uploadStoreLogo(data: Data, storeId: String) async throws -> String {
        let logoRef = storage.child("stores/\(storeId)/logo.jpg")
        
        // Compress image metadata to save bandwidth
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        let _ = try await logoRef.putDataAsync(data, metadata: metadata)
        let downloadURL = try await logoRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    // MARK: - Item Image Upload
    func uploadItemImage(data: Data, storeId: String, itemId: String) async throws -> String {
        let itemRef = storage.child("stores/\(storeId)/items/\(itemId).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        let _ = try await itemRef.putDataAsync(data, metadata: metadata)
        let downloadURL = try await itemRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    // MARK: - Deletion Helpers
    func deleteItemImage(storeId: String, itemId: String) async {
        let itemRef = storage.child("stores/\(storeId)/items/\(itemId).jpg")
        try? await itemRef.delete()
    }
    
    func deleteStoreFolder(storeId: String) async {
        // Note: Firebase Storage doesn't support deleting entire folders directly from the client SDK.
        // For a production app, you would typically trigger a Firebase Cloud Function to wipe the folder,
        // or iterate through known item IDs to delete them. We will handle individual deletions as they happen.
        let logoRef = storage.child("stores/\(storeId)/logo.jpg")
        try? await logoRef.delete()
    }
}
