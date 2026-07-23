//
//  InventoryManagerView.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-07-20.
//

//
//  InventoryManagerView.swift
//  Simple Inventory
//

import SwiftUI
import SwiftData

struct InventoryManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoreItem.name) private var allItems: [StoreItem]
    
    @State private var searchText = ""
    @State private var isSearchFocused = false
    @State private var isShowingScanner = false
    
    var activeItems: [StoreItem] {
        allItems.filter { $0.isActive }
    }
    
    var filteredItems: [StoreItem] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return activeItems
        } else {
            return activeItems.filter { item in
                let nameMatch = item.name.localizedCaseInsensitiveContains(searchText)
                let barcodeMatch = item.barcode?.localizedCaseInsensitiveContains(searchText) ?? false
                return nameMatch || barcodeMatch
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if filteredItems.isEmpty {
                ContentUnavailableView(
                    "No Active Items",
                    systemImage: "shippingbox",
                    description: Text("Your active inventory will appear here.")
                )
            } else {
                List {
                    ForEach(filteredItems) { item in
                        NavigationLink(destination: BackofficeItemDetailView(item: item)) {
                            InventoryRowView(item: item)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    item.isActive = false
                                    item.updatedAt = Date()
                                    try? modelContext.save()
                                }
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                        }
                        // Apple Best Practice: Duplicate swipe action in context menu
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation {
                                    item.isActive = false
                                    item.updatedAt = Date()
                                    try? modelContext.save()
                                }
                            } label: {
                                Label("Archive Item", systemImage: "archivebox")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .sensoryFeedback(.impact(weight: .medium), trigger: filteredItems.count)
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
            .padding(.bottom, 20)
            .sensoryFeedback(.selection, trigger: isShowingScanner)
        }
        .navigationTitle("Inventory Manager")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, isPresented: $isSearchFocused, prompt: "Search by name or barcode...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    NavigationLink(destination: ArchivedInventoryView()) {
                        Image(systemName: "archivebox")
                    }
                    
                    NavigationLink(destination: AddItemView()) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingScanner) {
            BarcodeScannerView(scannedCode: $searchText)
        }
    }
}

// MARK: - List Row Component
struct InventoryRowView: View {
    let item: StoreItem
    var body: some View {
        HStack(spacing: 16) {
            if let data = item.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .grayscale(item.isActive ? 0 : 0.99)
                    .opacity(item.isActive ? 1.0 : 0.6)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(Image(systemName: "photo").foregroundColor(.gray))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.headline).lineLimit(2).foregroundColor(item.isActive ? .primary : .secondary)
                if let barcode = item.barcode, !barcode.isEmpty { Text(barcode).font(.caption).foregroundColor(.secondary).monospacedDigit() }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.salesPrice, format: .currency(code: "CAD")).fontWeight(.semibold).foregroundColor(item.isActive ? .primary : .secondary)
                if !item.isActive {
                    Text("Archived").font(.caption).foregroundColor(.red).fontWeight(.bold)
                } else if item.stockCount <= 0 {
                    Text("Out of Stock").font(.caption).foregroundColor(.red).fontWeight(.medium)
                } else {
                    Text("\(item.stockCount) in stock").font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Archived Inventory View
struct ArchivedInventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoreItem.name) private var allItems: [StoreItem]
    
    var archivedItems: [StoreItem] {
        allItems.filter { !$0.isActive }
    }
    
    var body: some View {
        List {
            if archivedItems.isEmpty {
                Text("No archived items.")
                    .foregroundColor(.secondary)
                    .italic()
                    .listRowBackground(Color.clear)
            } else {
                ForEach(archivedItems) { item in
                    InventoryRowView(item: item)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                withAnimation {
                                    item.isActive = true
                                    item.updatedAt = Date()
                                    try? modelContext.save()
                                }
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation {
                                    permanentlyDelete(item)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        // Apple Best Practice: Context Menu for Archived Items
                        .contextMenu {
                            Button {
                                withAnimation {
                                    item.isActive = true
                                    item.updatedAt = Date()
                                    try? modelContext.save()
                                }
                            } label: {
                                Label("Restore Item", systemImage: "arrow.uturn.backward")
                            }
                            
                            Button(role: .destructive) {
                                withAnimation {
                                    permanentlyDelete(item)
                                }
                            } label: {
                                Label("Delete Forever", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .navigationTitle("Archived Inventory")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func permanentlyDelete(_ item: StoreItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }
}
