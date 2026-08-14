//
//  InventoryManagerView.swift
//  Simple Store
//

import SwiftUI
import SwiftData

// MARK: - View Model

@MainActor
@Observable
final class InventoryManagerViewModel {
    var searchText = ""
    var isSearchFocused = false
    var isShowingScanner = false
    
    var isShowingArchiveAlert = false
    var itemToArchiveAlert: StoreItem? = nil
    
    func handleArchive(item: StoreItem, cartManager: CartManager, context: ModelContext, syncManager: SyncManager) {
        if cartManager.items.keys.contains(where: { $0.id == item.id }) {
            itemToArchiveAlert = item
            isShowingArchiveAlert = true
        } else {
            withAnimation {
                item.isActive = false
                item.updatedAt = Date()
                try? context.save()
            }
            Task { await syncManager.pushItemToCloud(item) }
        }
    }
    
    func confirmArchiveAndRemove(cartManager: CartManager, context: ModelContext, syncManager: SyncManager) {
        guard let item = itemToArchiveAlert else { return }
        withAnimation {
            item.isActive = false
            item.updatedAt = Date()
            cartManager.items.removeValue(forKey: item)
            try? context.save()
        }
        Task { await syncManager.pushItemToCloud(item) }
    }
}

// MARK: - View

struct InventoryManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CartManager.self) private var cartManager
    @Environment(SyncManager.self) private var syncManager
    
    @Query(sort: \StoreItem.name) private var allItems: [StoreItem]
    @State private var viewModel = InventoryManagerViewModel()
    
    var activeItems: [StoreItem] {
        allItems.filter { $0.isActive }
    }
    
    var filteredItems: [StoreItem] {
        if viewModel.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return activeItems
        } else {
            return activeItems.filter { item in
                let nameMatch = item.name.localizedCaseInsensitiveContains(viewModel.searchText)
                let barcodeMatch = item.barcode?.localizedCaseInsensitiveContains(viewModel.searchText) ?? false
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
                                viewModel.handleArchive(item: item, cartManager: cartManager, context: modelContext, syncManager: syncManager)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.handleArchive(item: item, cartManager: cartManager, context: modelContext, syncManager: syncManager)
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
            Button {
                viewModel.isShowingScanner = true
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
            .padding(.bottom, 20)
            .sensoryFeedback(.selection, trigger: viewModel.isShowingScanner)
        }
        .navigationTitle("Inventory Manager")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, isPresented: $viewModel.isSearchFocused, prompt: "Search by name or barcode...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    NavigationLink(destination: ArchivedInventoryView()) { Image(systemName: "archivebox") }
                    NavigationLink(destination: AddItemView()) { Image(systemName: "plus") }
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingScanner) {
            BarcodeScannerView(scannedCode: $viewModel.searchText)
        }
        .alert("Item in Cart", isPresented: $viewModel.isShowingArchiveAlert, presenting: viewModel.itemToArchiveAlert) { item in
            Button("Cancel", role: .cancel) { }
            Button("Archive & Remove", role: .destructive) {
                viewModel.confirmArchiveAndRemove(cartManager: cartManager, context: modelContext, syncManager: syncManager)
            }
        } message: { item in
            Text("This item is currently in your cart. Archiving it will remove it from the active cart. Continue?")
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
                    .overlay(Image(systemName: "photo").foregroundStyle(.gray))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.headline).lineLimit(2).foregroundStyle(item.isActive ? .primary : .secondary)
                if let barcode = item.barcode, !barcode.isEmpty { Text(barcode).font(.caption).foregroundStyle(.secondary).monospacedDigit() }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.salesPrice, format: .currency(code: "CAD")).fontWeight(.semibold).foregroundStyle(item.isActive ? .primary : .secondary)
                if !item.isActive {
                    Text("Archived").font(.caption).foregroundStyle(.red).fontWeight(.bold)
                } else if item.stockCount <= 0 {
                    Text("Out of Stock").font(.caption).foregroundStyle(.red).fontWeight(.medium)
                } else {
                    Text("\(item.stockCount) in stock").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Archived Inventory View

struct ArchivedInventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CartManager.self) private var cartManager
    @Environment(SyncManager.self) private var syncManager
    
    @Query(sort: \StoreItem.name) private var allItems: [StoreItem]
    
    @State private var isShowingDeleteAlert = false
    @State private var itemToDeleteAlert: StoreItem? = nil
    
    var archivedItems: [StoreItem] {
        allItems.filter { !$0.isActive && !$0.name.hasSuffix("(Deleted)") }
    }
    
    var body: some View {
        List {
            if archivedItems.isEmpty {
                Text("No archived items.")
                    .foregroundStyle(.secondary)
                    .italic()
                    .listRowBackground(Color.clear)
            } else {
                ForEach(archivedItems) { item in
                    InventoryRowView(item: item)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                restoreItem(item)
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation {
                                    itemToDeleteAlert = item
                                    isShowingDeleteAlert = true
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .navigationTitle("Archived Inventory")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Permanently Delete", isPresented: $isShowingDeleteAlert, presenting: itemToDeleteAlert) { item in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                withAnimation { permanentlyDelete(item) }
            }
        } message: { item in
            Text("Are you sure you want to permanently delete \(item.name)? This will strip its metadata. Transaction records will be preserved.")
        }
    }
    
    private func restoreItem(_ item: StoreItem) {
        withAnimation {
            item.isActive = true
            item.updatedAt = Date()
            try? modelContext.save()
        }
        Task { await syncManager.pushItemToCloud(item) }
    }
    
    private func permanentlyDelete(_ item: StoreItem) {
        item.name = item.name + " (Deleted)"
        item.imageData = nil
        item.tags = []
        item.barcode = nil
        item.desc = nil
        item.isActive = false
        
        cartManager.items.removeValue(forKey: item)
        try? modelContext.save()
        Task { await syncManager.pushItemToCloud(item) }
    }
}
