//
//  StorageManager.swift
//  Simple Store
//

import Foundation
import FirebaseStorage

/// A thread-safe service responsible for handling asset uploads and deletions in Firebase Storage.
///
/// Manages workspace logos and inventory item media assets structured under store tenant paths.
public final class StorageManager: Sendable {
    
    // MARK: - Singleton
    
    /// The shared singleton instance of `StorageManager`.
    public static let shared = StorageManager()
    
    // MARK: - Private Properties
    
    private let storageRef: StorageReference
    
    // MARK: - Initialization
    
    private init() {
        let storage = Storage.storage()
        // Enforces a strict 10-second timeout.
        // This ensures the application fails-fast during offline operations, immediately triggering local caching fallbacks.
        storage.maxUploadRetryTime = 10.0
        storage.maxOperationRetryTime = 10.0
        self.storageRef = storage.reference()
    }
    
    // MARK: - Store Logo Operations
    
    /// Uploads a JPEG store logo image to Firebase Storage for a given store workspace.
    ///
    /// - Parameters:
    ///   - data: The raw JPEG image binary data to upload.
    ///   - storeId: The unique identifier of the target store workspace.
    /// - Returns: The HTTPS download URL string for the uploaded store logo asset.
    /// - Throws: An error if the data upload or download URL retrieval fails.
    public func uploadStoreLogo(data: Data, storeId: String) async throws -> String {
        let logoRef = storageRef.child("stores/\(storeId)/logo.jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await logoRef.putDataAsync(data, metadata: metadata)
        let downloadURL = try await logoRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    // MARK: - Item Image Operations
    
    /// Uploads a product item JPEG image to Firebase Storage under the specific store workspace hierarchy.
    ///
    /// - Parameters:
    ///   - data: The raw JPEG image binary data to upload.
    ///   - storeId: The unique identifier of the store owning the item.
    ///   - itemId: The unique identifier of the item.
    /// - Returns: The HTTPS download URL string for the uploaded product image asset.
    /// - Throws: An error if the data upload or download URL retrieval fails.
    public func uploadItemImage(data: Data, storeId: String, itemId: String) async throws -> String {
        let itemRef = storageRef.child("stores/\(storeId)/items/\(itemId).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await itemRef.putDataAsync(data, metadata: metadata)
        let downloadURL = try await itemRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    // MARK: - Deletion Helpers
    
    /// Deletes a product item image asset from Firebase Storage.
    ///
    /// - Parameters:
    ///   - storeId: The unique identifier of the store owning the item.
    ///   - itemId: The unique identifier of the target item.
    public func deleteItemImage(storeId: String, itemId: String) async {
        let itemRef = storageRef.child("stores/\(storeId)/items/\(itemId).jpg")
        try? await itemRef.delete()
    }
    
    /// Deletes top-level store workspace assets (such as the store logo) from Firebase Storage.
    ///
    /// - Note: The Firebase Storage Client SDK does not support client-side recursive folder deletion.
    ///   For complete store storage bucket cleanup, offload folder deletion to a Firebase Cloud Function.
    /// - Parameter storeId: The unique identifier of the store workspace being deleted.
    public func deleteStoreFolder(storeId: String) async {
        let logoRef = storageRef.child("stores/\(storeId)/logo.jpg")
        try? await logoRef.delete()
    }
}
