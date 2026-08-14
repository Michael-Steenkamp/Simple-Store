//
//  StoreSelectionView.swift
//  Simple Store
//

import SwiftUI
import FirebaseFirestore

// MARK: - Models

public struct PublicStore: Identifiable {
    public let id: String
    public let name: String
    public let address: String
    public let logoURL: String
}

// MARK: - View Models

@MainActor
@Observable
final class StoreSelectionViewModel {
    var searchText = ""
    var allStores: [PublicStore] = []
    var isLoadingStores = true
    
    var isCreatingStore: Bool = false
    var selectedStorePreview: PublicStore?
    
    func filteredStores(myStoreIds: [String]) -> [PublicStore] {
        let discoverable = allStores.filter { !myStoreIds.contains($0.id) }
        
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return discoverable
        } else {
            return discoverable.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    func fetchPublicStores() async {
        isLoadingStores = true
        defer { isLoadingStores = false }
        
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
    }
}

@MainActor
@Observable
final class StorePreviewViewModel {
    var memberCount: Int = 0
    var isJoining = false
    
    func fetchMemberCount(storeId: String) async {
        let db = Firestore.firestore()
        do {
            let snapshot = try await db.collection("users")
                .whereField("storeIds", arrayContains: storeId)
                .getDocuments()
            
            memberCount = snapshot.documents.count
        } catch {
            print("Failed to fetch member count")
        }
    }
    
    func joinStore(storeId: String, session: SessionManager) async {
        isJoining = true
        await session.joinStore(storeId: storeId)
        isJoining = false
    }
}

// MARK: - Views

/// A searchable global directory allowing users to discover and join public Simple Store workspaces.
struct StoreSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session
    
    @State private var viewModel = StoreSelectionViewModel()
    
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
                    
                    TextField("Search by name...", text: $viewModel.searchText)
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                        .overlay(
                            HStack {
                                Spacer()
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.gray)
                                    .padding(.trailing, 12)
                            }
                        )
                }
                .padding()
                
                // MARK: - Store Grid
                let visibleStores = viewModel.filteredStores(myStoreIds: session.currentUser?.storeIds ?? [])
                
                if viewModel.isLoadingStores {
                    Spacer()
                    ProgressView("Finding stores...")
                    Spacer()
                } else if visibleStores.isEmpty {
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
                            ForEach(visibleStores) { store in
                                StoreCardView(store: store)
                                    .onTapGesture {
                                        viewModel.selectedStorePreview = store
                                    }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
                
                // MARK: - Footer
                VStack {
                    Divider()
                    Button {
                        viewModel.isCreatingStore = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create Your Own Store")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                }
                .background(Color(uiColor: .systemBackground))
            }
            .navigationDestination(isPresented: $viewModel.isCreatingStore) {
                StoreSetupWizardView()
            }
            .sheet(item: $viewModel.selectedStorePreview) { store in
                StorePreviewView(store: store) {
                    dismiss()
                }
            }
            .task {
                await viewModel.fetchPublicStores()
            }
        }
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
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
    
    var placeholderLogo: some View {
        Circle()
            .fill(Color(uiColor: .tertiarySystemBackground))
            .frame(width: 70, height: 70)
            .overlay(Image(systemName: "storefront.fill").foregroundStyle(.gray).font(.title2))
    }
}

struct StorePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session
    
    let store: PublicStore
    var onJoinSuccess: () -> Void
    
    @State private var viewModel = StorePreviewViewModel()
    
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
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "person.2.fill")
                        Text("\(viewModel.memberCount) Members")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1)).foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
                    .padding(.top, 8)
                }
                
                Spacer()
                
                Button {
                    Task {
                        await viewModel.joinStore(storeId: store.id, session: session)
                        dismiss()
                        onJoinSuccess()
                    }
                } label: {
                    HStack {
                        if viewModel.isJoining {
                            ProgressView().tint(.white)
                        } else {
                            Text("Join Workspace").fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.accentColor).foregroundStyle(.white).cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .task {
                await viewModel.fetchMemberCount(storeId: store.id)
            }
        }
    }
    
    var placeholderLogo: some View {
        Circle()
            .fill(Color(uiColor: .secondarySystemBackground))
            .frame(width: 120, height: 120)
            .overlay(Image(systemName: "storefront.fill").foregroundStyle(.gray).font(.system(size: 50)))
    }
}
