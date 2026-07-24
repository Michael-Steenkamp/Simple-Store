//
//  StoreFrontView.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-07-18.
//

import SwiftUI
import SwiftData

struct StorefrontView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CartManager.self) private var cartManager
    
    @Query(sort: \StoreItem.name) private var allItems: [StoreItem]
    @Query(sort: \ItemTag.name) private var allTags: [ItemTag]
    @AppStorage("storeName") private var storeName: String = "Your Store Name"
    
    @State private var searchText = ""
    @State private var showInStockOnly = false
    @State private var showOutOfStockOnly = false
    @State private var isShowingCheckout = false
    @State private var selectedFilterTags: Set<ItemTag> = []
    
    @State private var isSearchFocused = false
    @State private var isShowingScanner = false
    @State private var navigateToSettings = false
    @State private var navigateToAddItem = false
    
    // NEW: Programmatic navigation state for the isolated tap gesture
    @State private var selectedProfileItem: StoreItem? = nil
    
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
                        if filteredItems.isEmpty {
                            emptyStateView
                        } else {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(filteredItems) { item in
                                    ItemCardView(item: item)
                                        // 1. Isolated Tap to Navigate
                                        .onTapGesture {
                                            selectedProfileItem = item
                                        }
                                        // 2. Isolated Long Press to Quick Add
                                        .onLongPressGesture(minimumDuration: 0.4) {
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
                            .padding(.bottom, cartManager.totalItemCount > 0 ? 100 : 20)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if cartManager.totalItemCount > 0 {
                            Button(action: {
                                isShowingCheckout = true
                            }) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Image(systemName: "cart.fill")
                                            .font(.title2)
                                        
                                        Text("\(cartManager.totalItemCount)")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                            .frame(width: 18, height: 18)
                                            .background(Color.white)
                                            .clipShape(Circle())
                                            .offset(x: 12, y: -10)
                                    }
                                    
                                    Text("Checkout • \(cartManager.totalAmount, format: .currency(code: "CAD"))")
                                        .fontWeight(.bold)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                            }
                            .padding(.bottom, 20)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: cartManager.totalItemCount)
                            .sensoryFeedback(.success, trigger: cartManager.totalItemCount)
                        }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Button(action: { isShowingScanner = true }) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.title)
                            .foregroundColor(.primary)
                            .padding(18)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, cartManager.totalItemCount > 0 ? 100 : 20)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: cartManager.totalItemCount)
                    .sensoryFeedback(.selection, trigger: isShowingScanner)
                }
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $searchText, isPresented: $isSearchFocused, prompt: "Search name or barcode...")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                navigateToSettings = true
                            }
                        }) {
                            Image(systemName: "gearshape.fill")
                        }
                    }
                    
                    ToolbarItem(placement: .principal) {
                        Text(storeName)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { navigateToAddItem = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
                // Safely handles routing to the item profile triggered by the tap gesture
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
                .overlay(alignment: .leading) {
                    Color.clear
                        .frame(width: 30)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 20)
                                .onEnded { value in
                                    if value.translation.width > 40 && abs(value.translation.height) < 50 {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            navigateToSettings = true
                                        }
                                    }
                                }
                        )
                }
                .overlay(alignment: .trailing) {
                    Color.clear
                        .frame(width: 30)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 20)
                                .onEnded { value in
                                    if value.translation.width < -40 && abs(value.translation.height) < 50 {
                                        navigateToAddItem = true
                                    }
                                }
                        )
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
    
    var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Items Found")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Try adjusting your filters or search terms.")
                .foregroundColor(.secondary)
            
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
                Button(action: {
                    withAnimation {
                        searchText = ""
                        dismissSearch()
                        showInStockOnly = false
                        showOutOfStockOnly = false
                        selectedFilterTags.removeAll()
                    }
                }) {
                    HStack(spacing: 4) { Image(systemName: "xmark.circle.fill"); Text("Clear") }
                        .font(.subheadline).fontWeight(.bold).padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.red.opacity(0.15)).foregroundColor(.red).clipShape(Capsule())
                }
                .padding(.leading, 16).padding(.vertical, 10).transition(.move(edge: .leading).combined(with: .opacity))
                
                Divider().frame(height: 20).padding(.leading, 12)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Button(action: {
                        withAnimation {
                            showInStockOnly.toggle()
                            if showInStockOnly { showOutOfStockOnly = false }
                        }
                    }) {
                        HStack { Image(systemName: showInStockOnly ? "checkmark.circle.fill" : "shippingbox.fill"); Text("In Stock") }
                            .font(.subheadline).padding(.horizontal, 16).padding(.vertical, 8)
                            .background(showInStockOnly ? Color.blue : Color(UIColor.secondarySystemBackground))
                            .foregroundColor(showInStockOnly ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    
                    Button(action: {
                        withAnimation {
                            showOutOfStockOnly.toggle()
                            if showOutOfStockOnly { showInStockOnly = false }
                        }
                    }) {
                        HStack { Image(systemName: showOutOfStockOnly ? "checkmark.circle.fill" : "shippingbox"); Text("Out of Stock") }
                            .font(.subheadline).padding(.horizontal, 16).padding(.vertical, 8)
                            .background(showOutOfStockOnly ? Color.red : Color(UIColor.secondarySystemBackground))
                            .foregroundColor(showOutOfStockOnly ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    
                    Divider().frame(height: 20)
                    
                    ForEach(allTags) { tag in
                        let isSelected = selectedFilterTags.contains(tag)
                        Button(action: {
                            withAnimation {
                                if isSelected { selectedFilterTags.remove(tag) } else { selectedFilterTags.insert(tag) }
                            }
                        }) {
                            Text(tag.name).font(.subheadline).padding(.horizontal, 16).padding(.vertical, 8)
                                .background(isSelected ? colorForTag(tag.name) : Color(UIColor.secondarySystemBackground))
                                .foregroundColor(isSelected ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.leading, isFilterActive ? 12 : 16).padding(.trailing, 16).padding(.vertical, 10)
            }
        }
        .background(Color(UIColor.systemBackground)).shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 3)
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
