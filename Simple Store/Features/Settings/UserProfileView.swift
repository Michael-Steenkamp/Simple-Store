//
//  UserProfileView.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-08-10.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session
    
    @State private var isEditing = false
    
    @State private var editName = ""
    @State private var editEmail = ""
    @State private var editPhone = ""
    @State private var newPassword = ""
    
    @State private var isProcessing = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    
    @State private var isShowingSignOutAlert = false
    @State private var isShowingDeleteAccountAlert = false
    @State private var isShowingDeleteStoreAlert = false
    @State private var storeNameConfirmation = ""
    
    @State private var isShowingWorkspaceSwitcher = false
    @State private var isShowingDiscovery = false
    @State private var isCreatingStore = false
    
    var body: some View {
        NavigationStack {
            Form {
                if !isEditing {
                    // MARK: - Read-Only Profile Mode
                    Section(header: Text("Profile Information")) {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(session.currentUser?.name ?? "Unknown").foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Email")
                            Spacer()
                            if let email = session.currentUser?.email, !email.isEmpty {
                                Text(email).foregroundColor(.secondary)
                            } else {
                                Text("Guest Account").foregroundColor(.secondary).italic()
                            }
                        }
                        
                        if let phone = session.currentUser?.phone, !phone.isEmpty {
                            HStack {
                                Text("Phone")
                                Spacer()
                                Text(phone).foregroundColor(.secondary)
                            }
                        }
                        
                        HStack {
                            Text("Active Role")
                            Spacer()
                            Text(session.currentUser?.role.rawValue.capitalized ?? "Guest")
                                .fontWeight(.bold)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color.blue.opacity(0.15)).foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                    }
                    
                    // MARK: - Multi-Tenant Workspaces
                    Section(header: Text("Workspaces")) {
                        Button(action: { isShowingWorkspaceSwitcher = true }) {
                            HStack {
                                Image(systemName: "building.2.crop.circle.fill")
                                    .foregroundColor(.blue)
                                Text("My Stores")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(session.currentUser?.storeIds.count ?? 0) Joined")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Section(header: Text("Danger Zone")) {
                        Button(role: .destructive, action: { isShowingDeleteAccountAlert = true }) {
                            Text("Delete Account").frame(maxWidth: .infinity, alignment: .center)
                        }
                        
                        if session.currentUser?.role == .admin {
                            Button(role: .destructive, action: { isShowingDeleteStoreAlert = true }) {
                                Text("Delete Active Store Permanently").frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }
                    
                    Section {
                        Button(role: .destructive, action: { isShowingSignOutAlert = true }) {
                            Text("Sign Out").frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    
                } else {
                    // MARK: - Edit Profile Mode
                    Section(
                        header: Text("Update Profile"),
                        footer: Text("Note: Changing your email or password may require you to sign in again.")
                    ) {
                        TextField("Update Name", text: $editName).textContentType(.name)
                        TextField("Update Email", text: $editEmail).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                        TextField("Update Phone", text: $editPhone).keyboardType(.phonePad)
                        SecureField("New Password (Optional)", text: $newPassword).textContentType(.newPassword)
                        
                        if !errorMessage.isEmpty { Text(errorMessage).font(.caption).foregroundColor(.red) }
                        if !successMessage.isEmpty { Text(successMessage).font(.caption).foregroundColor(.green) }
                        
                        Button(action: { Task { await updateProfile() } }) {
                            HStack {
                                if isProcessing { ProgressView().controlSize(.small) } else { Text("Save Changes") }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .disabled(isProcessing || (editName.isEmpty && editEmail.isEmpty && newPassword.isEmpty && editPhone.isEmpty))
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Profile" : "My Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isEditing {
                        Button("Cancel") { withAnimation { isEditing = false } }
                    } else {
                        Button("Done") { dismiss() }
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if !isEditing {
                        Button(action: { withAnimation { isEditing = true } }) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .onAppear {
                editName = session.currentUser?.name ?? ""
                editEmail = session.currentUser?.email ?? ""
                editPhone = session.currentUser?.phone ?? ""
            }
            .fullScreenCover(isPresented: $isShowingDiscovery) {
                StoreSelectionView()
            }
            .fullScreenCover(isPresented: $isCreatingStore) {
                StoreSetupWizardView()
            }
            .sheet(isPresented: $isShowingWorkspaceSwitcher) {
                MyStoresView(isPresentedFromProfile: true)
            }
            .alert("Delete Account", isPresented: $isShowingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) { Task { await deleteAccount() } }
            } message: { Text("Are you sure? This archives your directory information and permanently removes your login credentials.") }
            .alert("Delete Entire Store?", isPresented: $isShowingDeleteStoreAlert) {
                TextField("Type store name to confirm", text: $storeNameConfirmation)
                Button("Cancel", role: .cancel) { storeNameConfirmation = "" }
                Button("Nuke Store", role: .destructive) { Task { await deleteStoreCompletely() } }
            } message: { Text("This action is irreversible. All store inventory, orders, customer lists, and staff accounts will be wiped from the database.") }
            .alert("Sign Out", isPresented: $isShowingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) { signOut() }
            } message: { Text("Are you sure you want to sign out?") }
        }
    }
    
    // (Helper Functions remain unchanged)
    private func updateProfile() async {
        isProcessing = true
        errorMessage = ""; successMessage = ""
        guard let firebaseUser = Auth.auth().currentUser, let appUser = session.currentUser else { isProcessing = false; return }
        
        do {
            var emailNotice = ""
            var firestoreUpdates: [String: Any] = [:]
            
            if !editEmail.isEmpty && editEmail != appUser.email {
                try await firebaseUser.sendEmailVerification(beforeUpdatingEmail: editEmail)
                emailNotice = " A verification link was sent."
                firestoreUpdates["email"] = editEmail
            }
            if !newPassword.isEmpty { try await firebaseUser.updatePassword(to: newPassword) }
            if !editName.isEmpty && editName != appUser.name { firestoreUpdates["name"] = editName }
            if !editPhone.isEmpty && editPhone != appUser.phone { firestoreUpdates["phone"] = editPhone }
            
            if !firestoreUpdates.isEmpty {
                let db = Firestore.firestore()
                try await db.collection("users").document(appUser.id ?? "").updateData(firestoreUpdates)
                if !editName.isEmpty { session.currentUser?.name = editName }
                if !editEmail.isEmpty { session.currentUser?.email = editEmail }
                if !editPhone.isEmpty { session.currentUser?.phone = editPhone }
            }
            
            successMessage = "Profile updated successfully.\(emailNotice)"
            newPassword = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { isEditing = false }; successMessage = "" }
        } catch { errorMessage = error.localizedDescription }
        isProcessing = false
    }
    
    private func deleteAccount() async {
        do {
            try await session.deleteCurrentAccount()
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
    
    private func deleteStoreCompletely() async {
        guard let storeId = session.currentUser?.activeStoreId else { return }
        do {
            try await session.deleteStore(storeId: storeId)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
    
    private func signOut() {
        do {
            try Auth.auth().signOut()
            Task { await session.checkAuthenticationState() }
            dismiss()
        } catch { print("Error signing out: \(error.localizedDescription)") }
    }
}

// MARK: - Workspace Switcher Sub-View
struct WorkspaceSwitcherView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session
    
    @State private var myStores: [PublicStore] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    ProgressView("Loading workspaces...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else if myStores.isEmpty {
                    Text("You haven't joined any stores yet.")
                        .foregroundColor(.secondary).italic()
                } else {
                    ForEach(myStores) { store in
                        Button(action: {
                            Task {
                                await session.switchActiveStore(to: store.id)
                                dismiss()
                            }
                        }) {
                            HStack {
                                if let url = URL(string: store.logoURL), !store.logoURL.isEmpty {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image { image.resizable().scaledToFill().frame(width: 40, height: 40).clipShape(Circle())
                                        } else { placeholderIcon }
                                    }
                                } else { placeholderIcon }
                                
                                VStack(alignment: .leading) {
                                    Text(store.name).font(.headline).foregroundColor(.primary)
                                    if let role = session.currentUser?.storeRoles[store.id] {
                                        Text(role.capitalized).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                
                                if session.currentUser?.activeStoreId == store.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.blue).font(.title3)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Your Workspaces")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .task { await fetchMyStores() }
        }
    }
    
    var placeholderIcon: some View {
        Circle().fill(Color(UIColor.secondarySystemBackground)).frame(width: 40, height: 40).overlay(Image(systemName: "storefront.fill").foregroundColor(.gray))
    }
    
    private func fetchMyStores() async {
        isLoading = true
        guard let storeIds = session.currentUser?.storeIds, !storeIds.isEmpty else {
            isLoading = false
            return
        }
        
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("stores").whereField(FieldPath.documentID(), in: storeIds).getDocuments()
            
            self.myStores = snapshot.documents.map { doc in
                let name = doc.data()["storeName"] as? String ?? "Unnamed Store"
                let address = doc.data()["storeAddress"] as? String ?? ""
                let logoURL = doc.data()["storeLogoURL"] as? String ?? ""
                return PublicStore(id: doc.documentID, name: name, address: address, logoURL: logoURL)
            }.sorted(by: { $0.name < $1.name })
            
        } catch { print("Failed to fetch workspaces: \(error.localizedDescription)") }
        isLoading = false
    }
}
