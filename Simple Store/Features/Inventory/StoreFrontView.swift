//
//  StoreFrontView.swift
//  Simple Inventory
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
    
    @State private var dynamicScreenWidth: CGFloat = 390
    
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
                                    NavigationLink(destination: ItemProfileView(item: item)) {
                                        ItemCardView(item: item)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 16)
                            // Adds extra padding at the bottom so the floating cart doesn't cover your last row
                            .padding(.bottom, cartManager.totalItemCount > 0 ? 100 : 20)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        // The Cart Button is now a floating overlay!
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
                        }
                    }
                }
                // NEW: Floating Liquid Glass Barcode Scanner
                .overlay(alignment: .bottomTrailing) {
                    Button(action: { isShowingScanner = true }) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.title)
                            .foregroundColor(.primary)
                            .padding(18)
                            .background(.ultraThinMaterial) // Liquid Glass Effect
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 20)
                    // Smart padding: Floats higher if the cart is visible so it doesn't overlap
                    .padding(.bottom, cartManager.totalItemCount > 0 ? 100 : 20)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: cartManager.totalItemCount)
                }
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $searchText, isPresented: $isSearchFocused, prompt: "Search name or barcode...")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { navigateToSettings = true }) {
                            Image(systemName: "gearshape.fill")
                        }
                    }
                    
                    ToolbarItem(placement: .principal) {
                        Text(storeName)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink(destination: AddItemView()) {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $isShowingCheckout) {
                    CartCheckoutView()
                }
                .sheet(isPresented: $isShowingScanner) {
                    BarcodeScannerView(scannedCode: $searchText)
                }
                .navigationDestination(isPresented: $navigateToAddItem) {
                    AddItemView()
                }
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { dynamicScreenWidth = proxy.size.width }
                            .onChange(of: proxy.size.width) { _, newWidth in dynamicScreenWidth = newWidth }
                    }
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
        
        .simultaneousGesture(
            DragGesture(minimumDistance: 40, coordinateSpace: .global)
                .onEnded { value in
                    let startX = value.startLocation.x
                    let w = value.translation.width
                    let h = value.translation.height
                    
                    if navigateToSettings {
                        // Swipe left (a negative width gesture) to dismiss settings
                        if w < 60 && abs(h) < 50 { navigateToSettings = false }
                    } else {
                        // 1. Swipe from Left Edge -> Open Settings
                        if startX < 40 && w > 60 && abs(h) < 50 {
                            navigateToSettings = true
                        }
                        // 2. Swipe from Right Edge -> Add Item
                        else if startX > dynamicScreenWidth - 40 && w < -60 && abs(h) < 50 {
                            navigateToAddItem = true
                        }
                        // 3. Deep Pull Down -> Focus Search Bar
                        else if h > 120 && abs(w) < 50 {
                            isSearchFocused = true
                        }
                    }
                }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: navigateToSettings)
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
                    Button(action: { withAnimation { showInStockOnly.toggle(); if showInStockOnly { showOutOfStockOnly = false } } }) {
                        HStack { Image(systemName: showInStockOnly ? "checkmark.circle.fill" : "shippingbox.fill"); Text("In Stock") }
                            .font(.subheadline).padding(.horizontal, 16).padding(.vertical, 8)
                            .background(showInStockOnly ? Color.blue : Color(UIColor.secondarySystemBackground)).foregroundColor(showInStockOnly ? .white : .primary).clipShape(Capsule())
                    }
                    Button(action: { withAnimation { showOutOfStockOnly.toggle(); if showOutOfStockOnly { showInStockOnly = false } } }) {
                        HStack { Image(systemName: showOutOfStockOnly ? "checkmark.circle.fill" : "shippingbox"); Text("Out of Stock") }
                            .font(.subheadline).padding(.horizontal, 16).padding(.vertical, 8)
                            .background(showOutOfStockOnly ? Color.red : Color(UIColor.secondarySystemBackground)).foregroundColor(showOutOfStockOnly ? .white : .primary).clipShape(Capsule())
                    }
                    Divider().frame(height: 20)
                    ForEach(allTags) { tag in
                        let isSelected = selectedFilterTags.contains(tag)
                        Button(action: { withAnimation { if isSelected { selectedFilterTags.remove(tag) } else { selectedFilterTags.insert(tag) } } }) {
                            Text(tag.name).font(.subheadline).padding(.horizontal, 16).padding(.vertical, 8)
                                .background(isSelected ? colorForTag(tag.name) : Color(UIColor.secondarySystemBackground)).foregroundColor(isSelected ? .white : .primary).clipShape(Capsule())
                        }
                    }
                }
                .padding(.leading, isFilterActive ? 12 : 16).padding(.trailing, 16).padding(.vertical, 10)
            }
        }
        .background(Color(UIColor.systemBackground)).shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 3)
        .animation(.default, value: isFilterActive).animation(.default, value: showInStockOnly)
        .animation(.default, value: showOutOfStockOnly).animation(.default, value: selectedFilterTags)
    }
    private func colorForTag(_ name: String) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .pink, .indigo, .teal]
        let stableHash = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[stableHash % colors.count]
    }
}
