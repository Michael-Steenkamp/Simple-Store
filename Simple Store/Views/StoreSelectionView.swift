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
}

struct StoreSelectionView: View {
    @Environment(SessionManager.self) private var session
    
    @State private var searchText = ""
    @State private var allStores: [PublicStore] = []
    @State private var isLoadingStores = true
    
    @State private var isCreatingStore: Bool = false
    @State private var showPaywall: Bool = false
    
    var filteredStores: [PublicStore] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return allStores
        } else {
            return allStores.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Search Header
                VStack(spacing: 16) {
                    Text("Discover Stores")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    TextField("Search for a store...", text: $searchText)
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
                
                // MARK: - Store Directory List
                if isLoadingStores {
                    Spacer()
                    ProgressView("Finding stores...")
                    Spacer()
                } else if filteredStores.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No Stores Found",
                        systemImage: "storefront",
                        description: Text("Try adjusting your search terms.")
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(filteredStores) { store in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(store.name)
                                        .font(.headline)
                                    
                                    if !store.address.isEmpty {
                                        Text(store.address)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    Task { await session.joinStore(storeId: store.id) }
                                }) {
                                    Text("Join")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue.opacity(0.15))
                                        .foregroundColor(.blue)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
                
                // MARK: - Create Store Footer
                VStack {
                    Divider()
                    Button(action: {
                        // Temporarily bypassed the premium check for development/testing
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
            .sheet(isPresented: $showPaywall) {
                Text("Premium Subscription Required")
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
                return PublicStore(id: doc.documentID, name: name, address: address)
            }.sorted(by: { $0.name < $1.name })
            
        } catch {
            print("Failed to fetch stores: \(error.localizedDescription)")
        }
        isLoadingStores = false
    }
}
