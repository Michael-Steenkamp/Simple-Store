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
            if var userProfile = try snapshot.data(as: AppUser?.self) {
                
                // MARK: - Smart Startup Routing
                if let autoJoin = userProfile.autoJoinStoreId, userProfile.storeIds.contains(autoJoin) {
                    // If they have an auto-join preference, load them right in
                    userProfile.activeStoreId = autoJoin
                    try? await db.collection("users").document(authUser.uid).updateData(["activeStoreId": autoJoin])
                } else {
                    // Force them to the "My Stores" hub on every launch to pick a context
                    userProfile.activeStoreId = nil
                    try? await db.collection("users").document(authUser.uid).updateData(["activeStoreId": FieldValue.delete()])
                }
                
                self.currentUser = userProfile
            } else {
                self.errorMessage = "User profile not found. Please re-register."
                try? Auth.auth().signOut()
            }
        } catch {
            self.errorMessage = "Failed to fetch user data: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Safely performs the database swap with a crossfade animation
        func switchActiveStore(to newStoreId: String) async {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            
            do {
                try await db.collection("users").document(uid).updateData([
                    "activeStoreId": newStoreId
                ])
                
                // This animation block ensures the root view crossfades smoothly
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.currentUser?.activeStoreId = newStoreId
                }
            } catch {
                self.errorMessage = "Failed to switch workspaces."
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
            
            // Add to workspaces array and set role for this specific store
            try await db.collection("users").document(uid).updateData([
                "storeIds": FieldValue.arrayUnion([storeId]),
                "storeRoles.\(storeId)": UserRole.customer.rawValue,
                "activeStoreId": storeId
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
            
            self.currentUser?.storeIds.append(storeId)
            self.currentUser?.storeRoles[storeId] = UserRole.customer.rawValue
            self.currentUser?.activeStoreId = storeId
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
        var logoURL = ""
        if let data = logoData {
            if let url = try? await StorageManager.shared.uploadStoreLogo(data: data, storeId: newStoreId) {
                logoURL = url
            }
        }
        
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
        
        // Add to array, set admin role for this specific store, make active
        try await db.collection("users").document(authUser.uid).updateData([
            "storeIds": FieldValue.arrayUnion([newStoreId]),
            "storeRoles.\(newStoreId)": UserRole.admin.rawValue,
            "activeStoreId": newStoreId
        ])
        
        let newEmpId = UUID().uuidString
        let empData: [String: Any] = [
            "id": newEmpId,
            "storeId": newStoreId,
            "name": appUser.name,
            "isActive": true
        ]
        try await db.collection("employees").document(newEmpId).setData(empData)
        
        self.currentUser?.storeIds.append(newStoreId)
        self.currentUser?.storeRoles[newStoreId] = UserRole.admin.rawValue
        self.currentUser?.activeStoreId = newStoreId
        
        UserDefaults.standard.set(storeName, forKey: "storeName")
        UserDefaults.standard.set(storeEmail, forKey: "storeEmail")
        UserDefaults.standard.set(storePhone, forKey: "storePhone")
        UserDefaults.standard.set(storeAddress, forKey: "storeAddress")
        if let logoData { UserDefaults.standard.set(logoData, forKey: "storeLogo") }
    }
    
    // MARK: - Account & Store Deletion Rules
    
    func deleteCurrentAccount() async throws {
        guard let authUser = Auth.auth().currentUser, let appUser = currentUser else { return }
        
        if appUser.role == .admin, let storeId = appUser.activeStoreId {
            let adminQuery = try await db.collection("users")
                .whereField("storeIds", arrayContains: storeId)
                .whereField("storeRoles.\(storeId)", isEqualTo: UserRole.admin.rawValue)
                .getDocuments()
            
            if adminQuery.documents.count <= 1 {
                throw NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot delete account. You are the sole administrator of an active store. Please assign another admin or delete the store entirely."])
            }
        }
        
        if let storeId = appUser.activeStoreId {
            if appUser.role == .customer {
                let match = try await db.collection("customers").whereField("storeId", isEqualTo: storeId).whereField("email", isEqualTo: appUser.email ?? "").getDocuments()
                for doc in match.documents {
                    try await doc.reference.updateData(["firstName": "Deleted", "lastName": "Customer", "isActive": false])
                }
            } else if appUser.role == .employee {
                let match = try await db.collection("employees").whereField("storeId", isEqualTo: storeId).whereField("name", isEqualTo: appUser.name).getDocuments()
                for doc in match.documents {
                    try await doc.reference.updateData(["isActive": false])
                }
            }
        }
        
        try await db.collection("users").document(authUser.uid).delete()
        try await authUser.delete()
        
        try? Auth.auth().signOut()
        self.currentUser = nil
    }
    
    func deleteStore(storeId: String) async throws {
        guard let appUser = currentUser, appUser.role == .admin else {
            throw NSError(domain: "", code: 403, userInfo: [NSLocalizedDescriptionKey: "Unauthorized action."])
        }
        
        let collections = ["inventory", "customers", "employees", "transactions", "tags", "customerStatuses"]
        for col in collections {
            let docs = try await db.collection(col).whereField("storeId", isEqualTo: storeId).getDocuments()
            for doc in docs.documents {
                try await doc.reference.delete()
            }
        }
        
        try await db.collection("stores").document(storeId).delete()
        
        // Remove this store from the user's workspaces
        if let authUser = Auth.auth().currentUser {
            try await db.collection("users").document(authUser.uid).updateData([
                "storeIds": FieldValue.arrayRemove([storeId]),
                "storeRoles.\(storeId)": FieldValue.delete(),
                "activeStoreId": FieldValue.delete() // Forces them to pick a new active store on next launch
            ])
            
            self.currentUser?.storeIds.removeAll(where: { $0 == storeId })
            self.currentUser?.storeRoles.removeValue(forKey: storeId)
            self.currentUser?.activeStoreId = self.currentUser?.storeIds.first
        }
    }
    
    // MARK: - Admin Promotion Pipelines
    
    func promoteCustomerToEmployee(customerEmail: String, customerName: String) async throws {
        guard let storeId = currentUser?.activeStoreId, currentUser?.role == .admin else { return }
        
        let snapshot = try await db.collection("users")
            .whereField("storeIds", arrayContains: storeId)
            .whereField("email", isEqualTo: customerEmail)
            .getDocuments()
        
        guard let userDoc = snapshot.documents.first else {
            throw NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find a registered app account matching this customer's email."])
        }
        
        try await userDoc.reference.updateData([
            "storeRoles.\(storeId)": UserRole.employee.rawValue
        ])
        
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
        guard let storeId = currentUser?.activeStoreId, currentUser?.role == .admin else { return }
        
        let snapshot = try await db.collection("users")
            .whereField("storeIds", arrayContains: storeId)
            .whereField("name", isEqualTo: employeeName)
            .getDocuments()
        
        guard let userDoc = snapshot.documents.first else {
            throw NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find a registered app account matching this exact employee name."])
        }
        
        try await userDoc.reference.updateData([
            "storeRoles.\(storeId)": UserRole.admin.rawValue
        ])
    }
    
    func fetchStoreAdminNames() async -> [String] {
        guard let storeId = currentUser?.activeStoreId else { return [] }
        do {
            let snapshot = try await db.collection("users")
                .whereField("storeIds", arrayContains: storeId)
                .whereField("storeRoles.\(storeId)", isEqualTo: UserRole.admin.rawValue)
                .getDocuments()
            
            return snapshot.documents.compactMap { $0.data()["name"] as? String }
        } catch {
            return []
        }
    }
    
    func demoteEmployeeToCustomer(employeeName: String) async throws {
        guard let storeId = currentUser?.activeStoreId, currentUser?.role == .admin else { return }
        
        let snapshot = try await db.collection("users")
            .whereField("storeIds", arrayContains: storeId)
            .whereField("name", isEqualTo: employeeName)
            .getDocuments()
        
        guard let userDoc = snapshot.documents.first else {
            throw NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find a registered app account matching this employee name."])
        }
        
        try await userDoc.reference.updateData([
            "storeRoles.\(storeId)": UserRole.customer.rawValue
        ])
        
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
    
    // MARK: - Workspace Preferences
        
        func toggleAutoJoin(storeId: String) async {
            guard let uid = Auth.auth().currentUser?.uid, let user = currentUser else { return }
            
            // If they click the star on a store that is already auto-join, turn it off. Otherwise, set it.
            let newValue = user.autoJoinStoreId == storeId ? nil : storeId
            
            do {
                try await db.collection("users").document(uid).updateData([
                    "autoJoinStoreId": newValue != nil ? newValue! : FieldValue.delete()
                ])
                self.currentUser?.autoJoinStoreId = newValue
            } catch {
                self.errorMessage = "Failed to update auto-join preference."
            }
        }
        
        func leaveStore(storeId: String) async {
            guard let uid = Auth.auth().currentUser?.uid, let appUser = currentUser else { return }
            isLoading = true
            defer { isLoading = false }
            
            do {
                // 1. Prepare updates and only delete autoJoinStoreId if it matches the store they are leaving
                var updates: [String: Any] = [
                    "storeIds": FieldValue.arrayRemove([storeId]),
                    "storeRoles.\(storeId)": FieldValue.delete()
                ]
                
                if appUser.autoJoinStoreId == storeId {
                    updates["autoJoinStoreId"] = FieldValue.delete()
                }
                
                try await db.collection("users").document(uid).updateData(updates)
                
                // 2. Soft-delete their staff/customer directory record in the database
                let role = appUser.storeRoles[storeId]
                if role == UserRole.customer.rawValue {
                    let match = try await db.collection("customers").whereField("storeId", isEqualTo: storeId).whereField("email", isEqualTo: appUser.email ?? "").getDocuments()
                    for doc in match.documents {
                        try await doc.reference.updateData(["firstName": "Left", "lastName": "Store", "isActive": false])
                    }
                } else if role == UserRole.employee.rawValue || role == UserRole.admin.rawValue {
                    let match = try await db.collection("employees").whereField("storeId", isEqualTo: storeId).whereField("name", isEqualTo: appUser.name).getDocuments()
                    for doc in match.documents {
                        try await doc.reference.updateData(["isActive": false])
                    }
                }
                
                // 3. Update Local State
                self.currentUser?.storeIds.removeAll(where: { $0 == storeId })
                self.currentUser?.storeRoles.removeValue(forKey: storeId)
                if self.currentUser?.autoJoinStoreId == storeId { self.currentUser?.autoJoinStoreId = nil }
                if self.currentUser?.activeStoreId == storeId { self.currentUser?.activeStoreId = nil }
                
            } catch {
                self.errorMessage = "Failed to leave store: \(error.localizedDescription)"
            }
        }
}
