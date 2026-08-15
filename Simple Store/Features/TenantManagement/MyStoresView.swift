//
//  MyStoresView.swift
//  Simple Store
//

import SwiftUI
import FirebaseFirestore

// MARK: - View Model

@MainActor
@Observable
final class MyStoresViewModel {
    var myStores: [PublicStore] = []
    var isLoading = true
    
    var isShowingDiscovery = false
    var isCreatingStore = false
    var storeToLeave: PublicStore?
    
    /// Tracks which specific store card was tapped to show a localized spinner.
    var processingStoreId: String? = nil
    
    func fetchMyStores(session: SessionManager) async {
        isLoading = true
        defer { isLoading = false }
        
        guard let storeIds = session.currentUser?.storeIds, !storeIds.isEmpty else {
            self.myStores = []
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
            
        } catch {
            print("Failed to fetch workspaces: \(error.localizedDescription)")
        }
    }
    
    /// Orchestrates the natural UI dismissal sequence before swapping the active database context.
    func executeHandoff(to storeId: String, session: SessionManager, isPresentedFromProfile: Bool, dismissAction: DismissAction) async {
        await session.switchActiveStore(to: storeId)
        try? await Task.sleep(for: .milliseconds(300))
        processingStoreId = nil
        if isPresentedFromProfile { dismissAction() }
    }
}

// MARK: - View

/// The administrative dashboard for managing joined workspaces and seamlessly transitioning between them.
struct MyStoresView: View {
    @Environment(SessionManager.self) private var session
    @Environment(\.dismiss) private var dismiss
    
    let isPresentedFromProfile: Bool
    @State private var viewModel = MyStoresViewModel()
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    private var isStoreOwner: Bool {
        session.currentUser?.storeRoles.values.contains(UserRole.admin.rawValue) == true
    }
    
    private var ownedStores: [PublicStore] {
        viewModel.myStores.filter { session.currentUser?.storeRoles[$0.id] == UserRole.admin.rawValue }
    }
    
    private var joinedStores: [PublicStore] {
        viewModel.myStores.filter { session.currentUser?.storeRoles[$0.id] != UserRole.admin.rawValue }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSection
                gridSection
                footerActions
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isPresentedFromProfile {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
            .fullScreenCover(isPresented: $viewModel.isShowingDiscovery, onDismiss: { Task { await viewModel.fetchMyStores(session: session) } }) {
                StoreSelectionView(isPresentedModally: true)
            }
            .navigationDestination(isPresented: $viewModel.isCreatingStore) {
                StoreSetupWizardView(isPresentedInSheet: false)
            }
            .alert(item: $viewModel.storeToLeave) { store in
                Alert(
                    title: Text("Leave \(store.name)?"),
                    message: Text("Are you sure you want to leave this workspace? You will need to join again to access it."),
                    primaryButton: .destructive(Text("Leave")) {
                        Task {
                            await session.leaveStore(storeId: store.id)
                            await viewModel.fetchMyStores(session: session)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .task {
                await viewModel.fetchMyStores(session: session)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Your Stores")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Select a store to enter, or manage your memberships.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
    
    @ViewBuilder
    private var gridSection: some View {
        if viewModel.isLoading {
            Spacer()
            ProgressView("Loading stores...")
            Spacer()
        } else if viewModel.myStores.isEmpty {
            Spacer()
            ContentUnavailableView(
                "No Stores Joined",
                systemImage: "storefront",
                description: Text("You haven't joined any stores yet.")
            )
            Spacer()
        } else {
            ScrollView {
                if !ownedStores.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Owned Store")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(ownedStores) { store in
                                MyStoreCard(
                                    store: store,
                                    role: "Admin",
                                    isActiveStore: session.currentUser?.activeStoreId == store.id,
                                    isProcessing: viewModel.processingStoreId == store.id
                                ) {
                                    Task {
                                        withAnimation { viewModel.processingStoreId = store.id }
                                        await viewModel.executeHandoff(to: store.id, session: session, isPresentedFromProfile: isPresentedFromProfile, dismissAction: dismiss)
                                    }
                                } menuActions: {
                                    Button {
                                        Task {
                                            withAnimation { viewModel.processingStoreId = store.id }
                                            await viewModel.executeHandoff(to: store.id, session: session, isPresentedFromProfile: isPresentedFromProfile, dismissAction: dismiss)
                                        }
                                    } label: {
                                        Label("Enter Store", systemImage: "arrow.right.circle")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider().padding(.vertical, 16)
                    }
                }
                
                if !joinedStores.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Joined Stores")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(joinedStores) { store in
                                MyStoreCard(
                                    store: store,
                                    role: session.currentUser?.storeRoles[store.id] ?? "Browsing",
                                    isActiveStore: session.currentUser?.activeStoreId == store.id,
                                    isProcessing: viewModel.processingStoreId == store.id
                                ) {
                                    Task {
                                        withAnimation { viewModel.processingStoreId = store.id }
                                        await viewModel.executeHandoff(to: store.id, session: session, isPresentedFromProfile: isPresentedFromProfile, dismissAction: dismiss)
                                    }
                                } menuActions: {
                                    Button {
                                        Task {
                                            withAnimation { viewModel.processingStoreId = store.id }
                                            await viewModel.executeHandoff(to: store.id, session: session, isPresentedFromProfile: isPresentedFromProfile, dismissAction: dismiss)
                                        }
                                    } label: {
                                        Label("Enter Store", systemImage: "arrow.right.circle")
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        viewModel.storeToLeave = store
                                    } label: {
                                        Label("Leave Store", systemImage: "rectangle.portrait.and.arrow.right")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    private var footerActions: some View {
        VStack(spacing: 12) {
            Divider()
            
            Button {
                viewModel.isShowingDiscovery = true
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Discover New Stores")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor.opacity(0.15))
                .foregroundStyle(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            if !isStoreOwner {
                Button {
                    viewModel.isCreatingStore = true
                } label: {
                    Text("Create Your Own Store")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.accentColor)
                }
                .padding(.bottom, 8)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Card Component

struct MyStoreCard<MenuContent: View>: View {
    let store: PublicStore
    let role: String
    let isActiveStore: Bool
    let isProcessing: Bool
    let onEnter: () -> Void
    @ViewBuilder let menuActions: () -> MenuContent
    
    var body: some View {
        Button(action: onEnter) {
            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
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
                    
                    Menu {
                        menuActions()
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.gray.opacity(0.8))
                            .background(Circle().fill(Color(uiColor: .secondarySystemBackground)))
                    }
                    .offset(x: 25, y: -10)
                }
                
                VStack(spacing: 4) {
                    Text(store.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text(role.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isActiveStore ? Color.yellow.opacity(0.8) : Color.clear, lineWidth: 2)
            )
            .overlay {
                if isProcessing {
                    ZStack {
                        Color(uiColor: .secondarySystemBackground).opacity(0.85)
                        ProgressView().controlSize(.large)
                    }
                    .cornerRadius(16)
                    .transition(.opacity)
                }
            }
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    var placeholderLogo: some View {
        Circle()
            .fill(Color(uiColor: .tertiarySystemBackground))
            .frame(width: 70, height: 70)
            .overlay(Image(systemName: "storefront.fill").foregroundStyle(.gray).font(.title2))
    }
}
