//
//  StoreSelectionView.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-08-10.
//

import SwiftUI
import FirebaseFirestore

struct PublicStore: Identifiable {
    let id: String
    let name: String
    let address: String
    let logoURL: String
}

struct StoreSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session
    
    @State private var searchText = ""
    @State private var allStores: [PublicStore] = []
    @State private var isLoadingStores = true
    
    @State private var isCreatingStore: Bool = false
    @State private var selectedStorePreview: PublicStore?
    
    var filteredStores: [PublicStore] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return allStores
        } else {
            return allStores.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // Hide stores the user is already a member of
    var discoverableStores: [PublicStore] {
        let myStores = session.currentUser?.storeIds ?? []
        return filteredStores.filter { !myStores.contains($0.id) }
    }
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Search Header
                VStack(spacing: 16) {
                    Text("Discover Stores")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    TextField("Search by name...", text: $searchText)
                        .padding(12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .overlay(
                            HStack {
                                Spacer()
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 12)
                            }
                        )
                }
                .padding()
                
                // MARK: - Store Grid
                if isLoadingStores {
                    Spacer()
                    ProgressView("Finding stores...")
                    Spacer()
                } else if discoverableStores.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No Stores Found",
                        systemImage: "storefront",
                        description: Text("Try adjusting your search terms, or create a new store.")
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(discoverableStores) { store in
                                StoreCardView(store: store)
                                    .onTapGesture {
                                        selectedStorePreview = store
                                    }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
                
                // MARK: - Create Store Footer
                VStack {
                    Divider()
                    Button(action: {
                        isCreatingStore = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create Your Own Store")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                }
                .background(Color(UIColor.systemBackground))
            }
            .navigationDestination(isPresented: $isCreatingStore) {
                StoreSetupWizardView()
            }
            .sheet(item: $selectedStorePreview) { store in
                StorePreviewView(store: store) {
                    dismiss()
                }
            }
            .task {
                await fetchPublicStores()
            }
        }
    }
    
    private func fetchPublicStores() async {
        isLoadingStores = true
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("stores").getDocuments()
            
            self.allStores = snapshot.documents.map { doc in
                let name = doc.data()["storeName"] as? String ?? "Unnamed Store"
                let address = doc.data()["storeAddress"] as? String ?? ""
                let logoURL = doc.data()["storeLogoURL"] as? String ?? ""
                return PublicStore(id: doc.documentID, name: name, address: address, logoURL: logoURL)
            }.sorted(by: { $0.name < $1.name })
            
        } catch {
            print("Failed to fetch stores: \(error.localizedDescription)")
        }
        isLoadingStores = false
    }
}

// MARK: - Subcomponents

struct StoreCardView: View {
    let store: PublicStore
    
    var body: some View {
        VStack(spacing: 12) {
            if let url = URL(string: store.logoURL), !store.logoURL.isEmpty {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill().frame(width: 70, height: 70).clipShape(Circle())
                    } else {
                        placeholderLogo
                    }
                }
            } else {
                placeholderLogo
            }
            
            VStack(spacing: 4) {
                Text(store.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                if !store.address.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                        Text(store.address)
                            .lineLimit(1)
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
    
    var placeholderLogo: some View {
        Circle()
            .fill(Color(UIColor.tertiarySystemBackground))
            .frame(width: 70, height: 70)
            .overlay(Image(systemName: "storefront.fill").foregroundColor(.gray).font(.title2))
    }
}

struct StorePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session
    
    let store: PublicStore
    var onJoinSuccess: () -> Void
    
    @State private var memberCount: Int = 0
    @State private var isJoining = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                if let url = URL(string: store.logoURL), !store.logoURL.isEmpty {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill().frame(width: 120, height: 120).clipShape(Circle()).shadow(radius: 5)
                        } else {
                            placeholderLogo
                        }
                    }
                } else {
                    placeholderLogo
                }
                
                VStack(spacing: 8) {
                    Text(store.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    if !store.address.isEmpty {
                        Text(store.address)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "person.2.fill")
                        Text("\(memberCount) Members")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1)).foregroundColor(.blue)
                    .clipShape(Capsule())
                    .padding(.top, 8)
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        isJoining = true
                        await session.joinStore(storeId: store.id)
                        isJoining = false
                        dismiss()
                        onJoinSuccess()
                    }
                }) {
                    HStack {
                        if isJoining {
                            ProgressView().tint(.white)
                        } else {
                            Text("Join Workspace").fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.blue).foregroundColor(.white).cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .task { await fetchMemberCount() }
        }
    }
    
    var placeholderLogo: some View {
        Circle()
            .fill(Color(UIColor.secondarySystemBackground))
            .frame(width: 120, height: 120)
            .overlay(Image(systemName: "storefront.fill").foregroundColor(.gray).font(.system(size: 50)))
    }
    
    private func fetchMemberCount() async {
        let db = Firestore.firestore()
        do {
            // Updated to use a standard document fetch and count to avoid AggregateQuery versioning issues
            let snapshot = try await db.collection("users")
                .whereField("storeIds", arrayContains: store.id)
                .getDocuments()
            
            memberCount = snapshot.documents.count
        } catch {
            print("Failed to fetch member count")
        }
    }
}
