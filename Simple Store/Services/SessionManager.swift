//
//  SessionManager.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-08-10.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@Observable
@MainActor
final class SessionManager {
    var currentUser: AppUser? {
        didSet {
            subscriptionManager.isSystemAdmin = currentUser?.isSystemAdmin ?? false
        }
    }
    var isLoading: Bool = true
    var errorMessage: String?
    
    let subscriptionManager = SubscriptionManager()
    private var db: Firestore { Firestore.firestore() }
    
    init() {
        Task {
            await checkAuthenticationState()
        }
    }
    
    func checkAuthenticationState() async {
        isLoading = true
        defer { isLoading = false }
        
        guard let authUser = Auth.auth().currentUser else {
            currentUser = nil
            return
        }
        
        do {
            let snapshot = try await db.collection("users").document(authUser.uid).getDocument()
            if let userProfile = try snapshot.data(as: AppUser?.self) {
                self.currentUser = userProfile
            } else {
                self.errorMessage = "User profile not found. Please re-register."
                try? Auth.auth().signOut()
            }
        } catch {
            self.errorMessage = "Failed to fetch user data: \(error.localizedDescription)"
        }
    }
    
    func joinStore(storeId: String) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.errorMessage = "Authentication error. Please sign in again."
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let storeDoc = try await db.collection("stores").document(storeId).getDocument()
            guard storeDoc.exists else {
                self.errorMessage = "Store not found. It may have been deleted."
                return
            }
            
            try await db.collection("users").document(uid).updateData([
                "storeId": storeId,
                "role": UserRole.customer.rawValue
            ])
            
            let newRecordId = UUID().uuidString
            let userName = self.currentUser?.name ?? "Guest User"
            let nameParts = userName.components(separatedBy: " ")
            let first = nameParts.first ?? "Guest"
            let last = nameParts.dropFirst().joined(separator: " ")
            
            let custData: [String: Any] = [
                "id": newRecordId,
                "storeId": storeId,
                "firstName": first,
                "lastName": last,
                "email": self.currentUser?.email ?? "",
                "phone": "",
                "isActive": true,
                "updatedAt": Timestamp(),
                "dateAdded": Timestamp()
            ]
            try await db.collection("customers").document(newRecordId).setData(custData)
            
            self.currentUser?.storeId = storeId
            self.currentUser?.role = .customer
            self.errorMessage = nil
            
        } catch {
            self.errorMessage = "Failed to join store: \(error.localizedDescription)"
        }
    }
    
    func createStore(storeName: String, storeEmail: String, storePhone: String, storeAddress: String, logoData: Data?) async throws {
            guard let authUser = Auth.auth().currentUser, let appUser = currentUser else {
                throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication error. Please sign in again."])
            }
            
            isLoading = true
            defer { isLoading = false }
            
            let newStoreId = UUID().uuidString
            
            // 1. Upload the store logo if they provided one
            var logoURL = ""
            if let data = logoData {
                if let url = try? await StorageManager.shared.uploadStoreLogo(data: data, storeId: newStoreId) {
                    logoURL = url
                }
            }
            
            // 2. Mint the new Store Document in Firestore
            let storeData: [String: Any] = [
                "id": newStoreId,
                "storeName": storeName,
                "storeEmail": storeEmail,
                "storePhone": storePhone,
                "storeAddress": storeAddress,
                "storeLogoURL": logoURL,
                "createdAt": Timestamp()
            ]
            try await db.collection("stores").document(newStoreId).setData(storeData)
            
            // 3. Upgrade the current user to the Admin of this new store
            try await db.collection("users").document(authUser.uid).updateData([
                "storeId": newStoreId,
                "role": UserRole.admin.rawValue
            ])
            
            // 4. Generate an Employee Directory record so they can process POS transactions immediately
            let newEmpId = UUID().uuidString
            let empData: [String: Any] = [
                "id": newEmpId,
                "storeId": newStoreId,
                "name": appUser.name,
                "isActive": true
            ]
            try await db.collection("employees").document(newEmpId).setData(empData)
            
            // 5. Update local active session routing
            self.currentUser?.storeId = newStoreId
            self.currentUser?.role = .admin
            
            // Optional: Pre-load the user defaults so the Storefront looks good instantly
            UserDefaults.standard.set(storeName, forKey: "storeName")
            UserDefaults.standard.set(storeEmail, forKey: "storeEmail")
            UserDefaults.standard.set(storePhone, forKey: "storePhone")
            UserDefaults.standard.set(storeAddress, forKey: "storeAddress")
            if let logoData { UserDefaults.standard.set(logoData, forKey: "storeLogo") }
        }
    
    // MARK: - Account & Store Deletion Rules
    
    func deleteCurrentAccount() async throws {
        guard let authUser = Auth.auth().currentUser, let appUser = currentUser else { return }
        
        // Safety Rule: If Admin, ensure there is at least one other Admin in the store
        if appUser.role == .admin, let storeId = appUser.storeId {
            let adminQuery = try await db.collection("users")
                .whereField("storeId", isEqualTo: storeId)
                .whereField("role", isEqualTo: UserRole.admin.rawValue)
                .getDocuments()
            
            if adminQuery.documents.count <= 1 {
                throw NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot delete account. You are the sole administrator of this store. Please assign another admin or delete the store entirely."])
            }
        }
        
        // Soft-delete / Archive matching directory records to prevent dangling keys
        if let storeId = appUser.storeId {
            if appUser.role == .customer {
                // Email is optional, safely coalesced to clear the warning
                let match = try await db.collection("customers").whereField("storeId", isEqualTo: storeId).whereField("email", isEqualTo: appUser.email ?? "").getDocuments()
                for doc in match.documents {
                    try await doc.reference.updateData(["firstName": "Deleted", "lastName": "Customer", "isActive": false])
                }
            } else if appUser.role == .employee {
                // Name is non-optional, safely passed directly
                let match = try await db.collection("employees").whereField("storeId", isEqualTo: storeId).whereField("name", isEqualTo: appUser.name).getDocuments()
                for doc in match.documents {
                    try await doc.reference.updateData(["isActive": false])
                }
            }
        }
        
        // Delete Firestore user document & Auth account
        try await db.collection("users").document(authUser.uid).delete()
        try await authUser.delete()
        
        try? Auth.auth().signOut()
        self.currentUser = nil
    }
    
    func deleteStore(storeId: String) async throws {
        guard let appUser = currentUser, appUser.role == .admin else {
            throw NSError(domain: "", code: 403, userInfo: [NSLocalizedDescriptionKey: "Unauthorized action."])
        }
        
        // Batch wipe all collections tied to this store ID to prevent database clutter
        let collections = ["inventory", "customers", "employees", "transactions", "tags", "customerStatuses"]
        for col in collections {
            let docs = try await db.collection(col).whereField("storeId", isEqualTo: storeId).getDocuments()
            for doc in docs.documents {
                try await doc.reference.delete()
            }
        }
        
        // Delete store profile document
        try await db.collection("stores").document(storeId).delete()
        
        // Reset admin user record back to a clean guest state
        if let authUser = Auth.auth().currentUser {
            try await db.collection("users").document(authUser.uid).updateData([
                "storeId": FieldValue.delete(),
                "role": UserRole.guest.rawValue
            ])
            self.currentUser?.storeId = nil
            self.currentUser?.role = .guest
        }
    }
    
    // MARK: - Admin Promotion Pipelines
    
    func promoteCustomerToEmployee(customerEmail: String, customerName: String) async throws {
        guard let storeId = currentUser?.storeId, currentUser?.role == .admin else { return }
        
        // 1. Find the customer's Auth user document via email
        let snapshot = try await db.collection("users")
            .whereField("storeId", isEqualTo: storeId)
            .whereField("email", isEqualTo: customerEmail)
            .getDocuments()
        
        guard let userDoc = snapshot.documents.first else {
            throw NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find a registered app account matching this customer's email."])
        }
        
        // 2. Escalate their role in Firestore
        try await userDoc.reference.updateData([
            "role": UserRole.employee.rawValue
        ])
        
        // 3. Automatically generate their Employee directory record so they can process POS transactions
        let newEmpId = UUID().uuidString
        let empData: [String: Any] = [
            "id": newEmpId,
            "storeId": storeId,
            "name": customerName,
            "isActive": true
        ]
        try await db.collection("employees").document(newEmpId).setData(empData)
    }
    
    func promoteEmployeeToAdmin(employeeName: String) async throws {
        guard let storeId = currentUser?.storeId, currentUser?.role == .admin else { return }
        
        // Since employees don't currently strictly require an email in the SwiftData model,
        // we map them to their user account via their exact name and store ID.
        let snapshot = try await db.collection("users")
            .whereField("storeId", isEqualTo: storeId)
            .whereField("name", isEqualTo: employeeName)
            .getDocuments()
        
        guard let userDoc = snapshot.documents.first else {
            throw NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find a registered app account matching this exact employee name."])
        }
        
        try await userDoc.reference.updateData([
            "role": UserRole.admin.rawValue
        ])
    }
    
    func fetchStoreAdminNames() async -> [String] {
        guard let storeId = currentUser?.storeId else { return [] }
        do {
            let snapshot = try await db.collection("users")
                .whereField("storeId", isEqualTo: storeId)
                .whereField("role", isEqualTo: UserRole.admin.rawValue)
                .getDocuments()
            
            return snapshot.documents.compactMap { $0.data()["name"] as? String }
        } catch {
            return []
        }
    }
    
    func demoteEmployeeToCustomer(employeeName: String) async throws {
            guard let storeId = currentUser?.storeId, currentUser?.role == .admin else { return }
            
            // 1. Find the employee's Auth user document via exact name
            let snapshot = try await db.collection("users")
                .whereField("storeId", isEqualTo: storeId)
                .whereField("name", isEqualTo: employeeName)
                .getDocuments()
            
            guard let userDoc = snapshot.documents.first else {
                throw NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find a registered app account matching this employee name."])
            }
            
            // 2. Demote their role in Firestore
            try await userDoc.reference.updateData([
                "role": UserRole.customer.rawValue
            ])
            
            // 3. Automatically generate a Customer directory record for them
            let newCustId = UUID().uuidString
            let nameParts = employeeName.components(separatedBy: " ")
            let first = nameParts.first ?? "Guest"
            let last = nameParts.dropFirst().joined(separator: " ")
            
            let userEmail = userDoc.data()["email"] as? String ?? ""
            let userPhone = userDoc.data()["phone"] as? String ?? ""
            
            let custData: [String: Any] = [
                "id": newCustId,
                "storeId": storeId,
                "firstName": first,
                "lastName": last,
                "email": userEmail,
                "phone": userPhone,
                "isActive": true,
                "updatedAt": Timestamp(),
                "dateAdded": Timestamp()
            ]
            
            try await db.collection("customers").document(newCustId).setData(custData)
        }
}
