//
//  MyStoresView.swift
//  Simple Store
//

import SwiftUI
import SwiftData
import FirebaseFirestore

struct MyStoresView: View {
    @Environment(SessionManager.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let isPresentedFromProfile: Bool
    
    @State private var myStores: [PublicStore] = []
    @State private var isLoading = true
    
    @State private var isShowingDiscovery = false
    @State private var isCreatingStore = false
    @State private var storeToLeave: PublicStore?
    
    @Query private var pendingTasks: [OfflineSyncTask]
    @State private var showingOfflineWarning = false
    
    // NEW: Tracks which specific store card was tapped to show a local spinner
    @State private var processingStoreId: String? = nil
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Header
                VStack(spacing: 8) {
                    Text("Your Workspaces")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Select a store to enter, or manage your memberships.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                
                // MARK: - Grid
                if isLoading {
                    Spacer()
                    ProgressView("Loading workspaces...")
                    Spacer()
                } else if myStores.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No Stores Joined",
                        systemImage: "storefront",
                        description: Text("You haven't joined any workspaces yet.")
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(myStores) { store in
                                MyStoreCard(
                                    store: store,
                                    role: session.currentUser?.storeRoles[store.id] ?? "guest",
                                    isAutoJoin: session.currentUser?.autoJoinStoreId == store.id,
                                    isActiveStore: session.currentUser?.activeStoreId == store.id,
                                    isProcessing: processingStoreId == store.id // Pass processing state
                                ) {
                                    // MARK: - Smooth Handoff Trigger
                                    Task {
                                        withAnimation { processingStoreId = store.id }
                                        await executeHandoff(to: store.id)
                                    }
                                } menuActions: {
                                    Button(action: {
                                        Task {
                                            withAnimation { processingStoreId = store.id }
                                            await executeHandoff(to: store.id)
                                        }
                                    }) {
                                        Label("Enter Workspace", systemImage: "arrow.right.circle")
                                    }
                                    
                                    Button(action: { Task { await session.toggleAutoJoin(storeId: store.id) } }) {
                                        if session.currentUser?.autoJoinStoreId == store.id {
                                            Label("Remove Auto-Join", systemImage: "star.slash")
                                        } else {
                                            Label("Set as Auto-Join", systemImage: "star.fill")
                                        }
                                    }
                                    Divider()
                                    Button(role: .destructive, action: { storeToLeave = store }) {
                                        Label("Leave Store", systemImage: "rectangle.portrait.and.arrow.right")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
                
                // MARK: - Footer Actions
                VStack(spacing: 12) {
                    Divider()
                    
                    Button(action: { isShowingDiscovery = true }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Discover New Stores")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button(action: { isCreatingStore = true }) {
                        Text("Create Your Own Store")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    .padding(.bottom, 8)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isPresentedFromProfile {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
            .fullScreenCover(isPresented: $isShowingDiscovery, onDismiss: { Task { await fetchMyStores() } }) {
                StoreSelectionView()
            }
            .fullScreenCover(isPresented: $isCreatingStore, onDismiss: { Task { await fetchMyStores() } }) {
                StoreSetupWizardView()
            }
            .alert(item: $storeToLeave) { store in
                Alert(
                    title: Text("Leave \(store.name)?"),
                    message: Text("Are you sure you want to leave this workspace? You will need to join again to access it."),
                    primaryButton: .destructive(Text("Leave")) {
                        Task {
                            await session.leaveStore(storeId: store.id)
                            await fetchMyStores()
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert("Offline Data Pending", isPresented: $showingOfflineWarning) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You have unsynced transactions saved to this iPad. Please reconnect to the internet to sync your data before switching workspaces.")
            }
            .task { await fetchMyStores() }
        }
    }
    
    // MARK: - Orchestrates the natural UI dismissal before switching
    private func executeHandoff(to storeId: String) async {
        // SAFETY LOCK: Block the workspace switch if there is pending offline data
        if !pendingTasks.isEmpty {
            processingStoreId = nil
            showingOfflineWarning = true
            return
        }
        
        await session.switchActiveStore(to: storeId)
        try? await Task.sleep(for: .milliseconds(300))
        processingStoreId = nil
        if isPresentedFromProfile { dismiss() }
    }
    
    private func fetchMyStores() async {
        isLoading = true
        guard let storeIds = session.currentUser?.storeIds, !storeIds.isEmpty else {
            self.myStores = []
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
            
        } catch {
            print("Failed to fetch workspaces: \(error.localizedDescription)")
        }
        isLoading = false
    }
}

struct MyStoreCard<MenuContent: View>: View {
    let store: PublicStore
    let role: String
    let isAutoJoin: Bool
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
                            .foregroundColor(.gray.opacity(0.8))
                            .background(Circle().fill(Color(UIColor.secondarySystemBackground)))
                    }
                    .offset(x: 25, y: -10)
                }
                
                VStack(spacing: 4) {
                    Text(store.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    HStack(spacing: 4) {
                        if isAutoJoin {
                            Image(systemName: "star.fill").foregroundColor(.yellow)
                        }
                        Text(role.capitalized)
                    }
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isActiveStore ? Color.yellow.opacity(0.8) : Color.clear, lineWidth: 2)
            )
            // MARK: - Darkened spinner overlay to acknowledge the user's tap instantly
            .overlay {
                if isProcessing {
                    ZStack {
                        Color(UIColor.secondarySystemBackground).opacity(0.85)
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
            .fill(Color(UIColor.tertiarySystemBackground))
            .frame(width: 70, height: 70)
            .overlay(Image(systemName: "storefront.fill").foregroundColor(.gray).font(.title2))
    }
}
