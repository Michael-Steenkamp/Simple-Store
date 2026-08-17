//
//  StorefrontView.swift
//  Simple Store
//

import SwiftUI
import SwiftData
import FirebaseFirestore

/// The primary POS and inventory interface, providing filtering, dynamic role-based access, and seamless hardware scanner integration.
struct StorefrontView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CartManager.self) private var cartManager
    @Environment(SessionManager.self) private var session
    @Environment(SyncManager.self) private var syncManager
    
    @Query(sort: \StoreItem.name) private var allItems: [StoreItem]
    @Query(sort: \ItemTag.name) private var allTags: [ItemTag]
    
    @AppStorage("storeName") private var storeName: String = "Your Store Name"
    @State private var logoData: Data? = UserDefaults.standard.data(forKey: "storeLogo")
    
    @State private var searchText = ""
    @State private var showInStockOnly = false
    @State private var showOutOfStockOnly = false
    @State private var isShowingCheckout = false
    @State private var selectedFilterTags: Set<ItemTag> = []
    
    @State private var isSearchFocused = false
    @State private var isShowingScanner = false
    @State private var navigateToSettings = false
    @State private var navigateToAddItem = false
    
    @State private var isShowingUserProfile = false
    @State private var isShowingStoreInfo = false
    @State private var isShowingDiscovery = false
    
    @State private var selectedProfileItem: StoreItem? = nil
    
    // MARK: - Role-Based Access Control
    
    private var isStaff: Bool {
        guard let user = session.currentUser, let activeStore = user.activeStoreId else { return false }
        let role = user.storeRoles[activeStore]
        return user.isSystemAdmin || role == "admin" || role == "employee"
    }
    
    // MARK: - Filtering Logic
    
    var isFilterActive: Bool {
        !searchText.isEmpty || showInStockOnly || showOutOfStockOnly || !selectedFilterTags.isEmpty
    }
    
    var filteredItems: [StoreItem] {
        var items = allItems.filter { $0.isActive }
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            items = items.filter { item in
                let nameMatches = item.name.localizedCaseInsensitiveContains(searchText)
                let barcodeMatches = item.barcode?.localizedCaseInsensitiveContains(searchText) ?? false
                return nameMatches || barcodeMatches
            }
        }
        if showInStockOnly {
            items = items.filter { $0.stockCount > 0 }
        } else if showOutOfStockOnly {
            items = items.filter { $0.stockCount <= 0 }
        }
        if !selectedFilterTags.isEmpty {
            items = items.filter { item in
                guard let itemTags = item.tags else { return false }
                return !Set(itemTags).isDisjoint(with: selectedFilterTags)
            }
        }
        return items
    }
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    
    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    FilterBarView(
                        searchText: $searchText,
                        showInStockOnly: $showInStockOnly,
                        showOutOfStockOnly: $showOutOfStockOnly,
                        selectedFilterTags: $selectedFilterTags,
                        allTags: allTags,
                        isFilterActive: isFilterActive
                    )
                    
                    ScrollView {
                        if filteredItems.isEmpty && !syncManager.isSyncing {
                            emptyStateView
                        } else {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(filteredItems) { item in
                                    ItemCardView(item: item)
                                        .onTapGesture { if isStaff { selectedProfileItem = item } }
                                        .onLongPressGesture(minimumDuration: 0.4) {
                                            guard isStaff else { return }
                                            let currentQty = cartManager.items[item] ?? 0
                                            if currentQty < item.stockCount {
                                                cartManager.items[item] = currentQty + 1
                                                let generator = UIImpactFeedbackGenerator(style: .heavy)
                                                generator.impactOccurred()
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 16)
                            .padding(.bottom, cartManager.totalItemCount > 0 && isStaff ? 100 : 20)
                        }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        isShowingScanner = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                            .font(.title)
                            .foregroundStyle(.primary)
                            .padding(18)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, (cartManager.totalItemCount > 0 && isStaff) ? 100 : 20)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: cartManager.totalItemCount)
                    .sensoryFeedback(.selection, trigger: isShowingScanner)
                }
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $searchText, isPresented: $isSearchFocused, prompt: "Search name or barcode...")
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        if isStaff {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    navigateToSettings = true
                                }
                            } label: {
                                Image(systemName: "gearshape.fill")
                            }
                        } else {
                            Button {
                                isShowingUserProfile = true
                            } label: {
                                Image(systemName: "person.crop.circle")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                            }
                            
                            NotificationBellView()
                        }
                    }
                    
                    ToolbarItem(placement: .principal) {
                        Text(storeName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        if isStaff {
                            Button {
                                navigateToAddItem = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        } else {
                            Button {
                                isShowingStoreInfo = true
                            } label: {
                                if let data = logoData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 30, height: 30)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
                .overlay {
                    if syncManager.isSyncing && allItems.isEmpty {
                        ZStack {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .ignoresSafeArea()
                            
                            VStack(spacing: 20) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                
                                Text("Entering Workspace...")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.4), value: syncManager.isSyncing)
                .navigationDestination(item: $selectedProfileItem) { item in
                    ItemProfileView(item: item)
                }
                .navigationDestination(isPresented: $navigateToAddItem) {
                    AddItemView()
                }
                .sheet(isPresented: $isShowingCheckout) {
                    CartCheckoutView()
                }
                .sheet(isPresented: $isShowingScanner) {
                    BarcodeScannerView(scannedCode: $searchText)
                }
                .sheet(isPresented: $isShowingUserProfile) {
                    UserProfileView()
                }
                .sheet(isPresented: $isShowingStoreInfo) {
                    CustomerStoreInfoView()
                }
                .fullScreenCover(isPresented: $isShowingDiscovery) {
                    StoreSelectionView()
                }
                .onAppear {
                    logoData = UserDefaults.standard.data(forKey: "storeLogo")
                }
                .onChange(of: session.currentUser?.activeStoreId) { _, newStoreId in
                    if newStoreId == nil {
                        isShowingDiscovery = true
                    }
                }
                .overlay(alignment: .leading) {
                    if isStaff {
                        Color.clear
                            .frame(width: 30)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 20).onEnded { value in
                                    if value.translation.width > 40 && abs(value.translation.height) < 50 {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { navigateToSettings = true }
                                    }
                                }
                            )
                    }
                }
                .overlay(alignment: .trailing) {
                    if isStaff {
                        Color.clear
                            .frame(width: 30)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 20).onEnded { value in
                                    if value.translation.width < -40 && abs(value.translation.height) < 50 {
                                        navigateToAddItem = true
                                    }
                                }
                            )
                    }
                }
            }
            .task(id: session.currentUser?.activeStoreId) {
                if let storeId = session.currentUser?.activeStoreId {
                    let activeRole = session.currentUser?.storeRoles[storeId] ?? "customer"
                    syncManager.startListening(storeId: storeId, role: activeRole, context: modelContext)
                    await fetchStoreProfile(storeId: storeId)
                }
            }
            
            if navigateToSettings {
                NavigationStack {
                    SettingsTabView(isPresented: $navigateToSettings)
                }
                .transition(.move(edge: .leading))
                .zIndex(2)
            }
        }
    }
    
    // MARK: - Store Profile Sync
    
    private func fetchStoreProfile(storeId: String) async {
        let db = Firestore.firestore()
        do {
            let doc = try await db.collection("stores").document(storeId).getDocument()
            if let data = doc.data() {
                if let name = data["storeName"] as? String { storeName = name }
                UserDefaults.standard.set(data["storeEmail"] as? String ?? "", forKey: "storeEmail")
                UserDefaults.standard.set(data["storePhone"] as? String ?? "", forKey: "storePhone")
                UserDefaults.standard.set(data["storeAddress"] as? String ?? "", forKey: "storeAddress")
                UserDefaults.standard.set(data["storeWebsite"] as? String ?? "", forKey: "storeWebsite")
                UserDefaults.standard.set(data["receiptReturnPolicy"] as? String ?? "", forKey: "receiptReturnPolicy")
                
                if let logoURLString = data["storeLogoURL"] as? String, !logoURLString.isEmpty {
                    if logoURLString != "OFFLINE_CACHE", let url = URL(string: logoURLString) {
                        if let (imageData, _) = try? await URLSession.shared.data(from: url) {
                            UserDefaults.standard.set(imageData, forKey: "storeLogo")
                            self.logoData = imageData
                        }
                    }
                } else {
                    UserDefaults.standard.removeObject(forKey: "storeLogo")
                    self.logoData = nil
                }
            }
        } catch {
            print("Failed to sync store profile: \(error.localizedDescription)")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("No Items Found")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Try adjusting your filters or search terms.")
                .foregroundStyle(.secondary)
            
            if isFilterActive {
                Button("Clear Filters") {
                    withAnimation {
                        searchText = ""
                        isSearchFocused = false
                        showInStockOnly = false
                        showOutOfStockOnly = false
                        selectedFilterTags.removeAll()
                    }
                }
                .padding(.top, 8)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.top, 60)
    }
}

// MARK: - Customer Store Info View Component

struct CustomerStoreInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("storeName") private var storeName: String = "Your Store Name"
    @AppStorage("storeEmail") private var storeEmail: String = ""
    @AppStorage("storePhone") private var storePhone: String = ""
    @AppStorage("storeAddress") private var storeAddress: String = ""
    @AppStorage("storeWebsite") private var storeWebsite: String = ""
    @AppStorage("receiptReturnPolicy") private var receiptReturnPolicy: String = ""
    
    @State private var logoData: Data? = UserDefaults.standard.data(forKey: "storeLogo")
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 16) {
                        if let data = logoData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
                        } else {
                            Image(systemName: "storefront.circle.fill")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .foregroundStyle(Color(uiColor: .systemGray4))
                        }
                        
                        Text(storeName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .listRowBackground(Color.clear)
                }
                
                Section(header: Text("Contact Us")) {
                    if !storeEmail.isEmpty {
                        HStack {
                            Image(systemName: "envelope.fill").foregroundStyle(.blue).frame(width: 24)
                            Text(storeEmail)
                        }
                    }
                    if !storePhone.isEmpty {
                        HStack {
                            Image(systemName: "phone.fill").foregroundStyle(.green).frame(width: 24)
                            Text(storePhone)
                        }
                    }
                    if !storeAddress.isEmpty {
                        HStack(alignment: .top) {
                            Image(systemName: "mappin.and.ellipse").foregroundStyle(.red).frame(width: 24)
                            Text(storeAddress)
                        }
                    }
                    if !storeWebsite.isEmpty {
                        HStack {
                            Image(systemName: "link").foregroundStyle(.purple).frame(width: 24)
                            Text(storeWebsite)
                        }
                    }
                }
                
                if !receiptReturnPolicy.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section(header: Text("Store Policy")) {
                        Text(receiptReturnPolicy)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("About Us")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Filter Bar Component

struct FilterBarView: View {
    @Environment(\.dismissSearch) private var dismissSearch
    @Binding var searchText: String
    @Binding var showInStockOnly: Bool
    @Binding var showOutOfStockOnly: Bool
    @Binding var selectedFilterTags: Set<ItemTag>
    var allTags: [ItemTag]
    var isFilterActive: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            if isFilterActive {
                Button {
                    withAnimation {
                        searchText = ""
                        dismissSearch()
                        showInStockOnly = false
                        showOutOfStockOnly = false
                        selectedFilterTags.removeAll()
                    }
                } label: {
                    HStack(spacing: 4) { Image(systemName: "xmark.circle.fill"); Text("Clear") }
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                }
                .padding(.leading, 16)
                .padding(.vertical, 10)
                .transition(.move(edge: .leading).combined(with: .opacity))
                
                Divider().frame(height: 20).padding(.leading, 12)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Button {
                        withAnimation {
                            showInStockOnly.toggle()
                            if showInStockOnly { showOutOfStockOnly = false }
                        }
                    } label: {
                        HStack { Image(systemName: showInStockOnly ? "checkmark.circle.fill" : "shippingbox.fill"); Text("In Stock") }
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(showInStockOnly ? Color.blue : Color(uiColor: .secondarySystemBackground))
                            .foregroundStyle(showInStockOnly ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    
                    Button {
                        withAnimation {
                            showOutOfStockOnly.toggle()
                            if showOutOfStockOnly { showInStockOnly = false }
                        }
                    } label: {
                        HStack { Image(systemName: showOutOfStockOnly ? "checkmark.circle.fill" : "shippingbox"); Text("Out of Stock") }
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(showOutOfStockOnly ? Color.red : Color(uiColor: .secondarySystemBackground))
                            .foregroundStyle(showOutOfStockOnly ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    
                    Divider().frame(height: 20)
                    
                    ForEach(allTags) { tag in
                        let isSelected = selectedFilterTags.contains(tag)
                        Button {
                            withAnimation {
                                if isSelected { selectedFilterTags.remove(tag) } else { selectedFilterTags.insert(tag) }
                            }
                        } label: {
                            Text(tag.name)
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isSelected ? colorForTag(tag.name) : Color(uiColor: .secondarySystemBackground))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.leading, isFilterActive ? 12 : 16)
                .padding(.trailing, 16)
                .padding(.vertical, 10)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 3)
        .animation(.default, value: isFilterActive)
        .animation(.default, value: showInStockOnly)
        .animation(.default, value: showOutOfStockOnly)
        .animation(.default, value: selectedFilterTags)
    }
    
    private func colorForTag(_ name: String) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .pink, .indigo, .teal]
        let stableHash = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[stableHash % colors.count]
    }
}
