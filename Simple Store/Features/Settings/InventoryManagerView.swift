//
//  InventoryManagerView.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-20.
//

import SwiftUI
import SwiftData

struct InventoryManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoreItem.name) private var allItems: [StoreItem]
    
    @State private var searchText = ""
    @State private var isSearchFocused = false
    @State private var isShowingScanner = false
    @State private var selectedTab = 0
    
    var filteredItems: [StoreItem] {
        let items = allItems.filter { selectedTab == 0 ? $0.isActive : !$0.isActive }
        
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return items
        } else {
            return items.filter { item in
                let nameMatch = item.name.localizedCaseInsensitiveContains(searchText)
                let barcodeMatch = item.barcode?.localizedCaseInsensitiveContains(searchText) ?? false
                return nameMatch || barcodeMatch
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("View Mode", selection: $selectedTab) {
                Text("Active Stock").tag(0)
                Text("Archived").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            .background(Color(UIColor.systemBackground))
            
            if filteredItems.isEmpty {
                ContentUnavailableView(
                    selectedTab == 0 ? "No Active Items" : "No Archived Items",
                    systemImage: selectedTab == 0 ? "shippingbox" : "archivebox",
                    description: Text(selectedTab == 0 ? "Your active inventory will appear here." : "Deleted items can be restored from here.")
                )
            } else {
                List {
                    ForEach(filteredItems) { item in
                        NavigationLink(destination: BackofficeItemDetailView(item: item)) {
                            InventoryRowView(item: item)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if !item.isActive {
                                Button {
                                    item.isActive = true
                                    item.updatedAt = Date()
                                    try? modelContext.save()
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.indigo)
                            } else {
                                Button(role: .destructive) {
                                    item.isActive = false
                                    item.updatedAt = Date()
                                    try? modelContext.save()
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
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
            .padding(.bottom, 20)
        }
        .navigationTitle("Inventory Manager")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, isPresented: $isSearchFocused, prompt: "Search by name or barcode...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(destination: AddItemView()) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingScanner) {
            BarcodeScannerView(scannedCode: $searchText)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 40, coordinateSpace: .global)
                .onEnded { value in
                    let w = value.translation.width
                    let h = value.translation.height
                    if h > 120 && abs(w) < 50 {
                        isSearchFocused = true
                    }
                }
        )
    }
}

// MARK: - List Row Component
struct InventoryRowView: View {
    let item: StoreItem
    var body: some View {
        HStack(spacing: 16) {
            if let data = item.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 8)).grayscale(item.isActive ? 0 : 0.99).opacity(item.isActive ? 1.0 : 0.6)
            } else {
                RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.2)).frame(width: 50, height: 50).overlay(Image(systemName: "photo").foregroundColor(.gray))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.headline).lineLimit(2).foregroundColor(item.isActive ? .primary : .secondary)
                if let barcode = item.barcode, !barcode.isEmpty { Text(barcode).font(.caption).foregroundColor(.secondary).monospacedDigit() }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.salesPrice, format: .currency(code: "CAD")).fontWeight(.semibold).foregroundColor(item.isActive ? .primary : .secondary)
                if !item.isActive { Text("Archived").font(.caption).foregroundColor(.red).fontWeight(.bold)
                } else if item.stockCount <= 0 { Text("Out of Stock").font(.caption).foregroundColor(.red).fontWeight(.medium)
                } else { Text("\(item.stockCount) in stock").font(.caption).foregroundColor(.secondary) }
            }
        }
        .padding(.vertical, 4)
    }
}
