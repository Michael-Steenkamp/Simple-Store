//
//  EditItemView.swift
//  Simple Store
//

import SwiftUI
import SwiftData
import PhotosUI

// MARK: - View Model

/// Manages form mutations, Firebase Storage synchronization, and destructive data operations for existing inventory items.
@MainActor
@Observable
final class EditItemViewModel {
    var name: String
    var desc: String
    var stockCount: Int
    var salesPriceString: String
    var itemCostString: String
    var barcode: String
    var selectedTags: [ItemTag]
    var imageData: Data?
    
    let item: StoreItem
    
    init(item: StoreItem) {
        self.item = item
        self.name = item.name
        self.desc = item.desc ?? ""
        self.stockCount = item.stockCount
        self.salesPriceString = item.salesPrice == 0.0 ? "" : String(format: "%.2f", item.salesPrice)
        self.itemCostString = item.itemCost == 0.0 ? "" : String(format: "%.2f", item.itemCost)
        self.barcode = item.barcode ?? ""
        self.selectedTags = item.tags ?? []
        self.imageData = item.imageData
    }
    
    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && Double(salesPriceString) != nil
    }
    
    func saveChanges(context: ModelContext, session: SessionManager, syncManager: SyncManager) {
        let finalPrice = Double(salesPriceString) ?? 0.0
        let finalCost = Double(itemCostString) ?? 0.0
        
        item.name = name.trimmingCharacters(in: .whitespaces)
        item.desc = desc.trimmingCharacters(in: .whitespaces).isEmpty ? nil : desc.trimmingCharacters(in: .whitespaces)
        item.stockCount = stockCount
        item.salesPrice = finalPrice
        item.itemCost = finalCost
        item.barcode = barcode.trimmingCharacters(in: .whitespaces).isEmpty ? nil : barcode.trimmingCharacters(in: .whitespaces)
        item.tags = selectedTags
        item.imageData = imageData
        item.updatedAt = Date()
        
        try? context.save()
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        let itemId = item.id.uuidString
        if let storeId = session.currentUser?.activeStoreId {
            if let data = imageData {
                Task {
                    let uploadedURL = await Task.detached {
                        do {
                            return try await StorageManager.shared.uploadItemImage(data: data, storeId: storeId, itemId: itemId)
                        } catch {
                            return "OFFLINE_CACHE"
                        }
                    }.value
                    
                    item.imageURL = uploadedURL
                    try? context.save()
                    syncManager.pushItemToCloud(item)
                }
                return
            } else {
                Task { await StorageManager.shared.deleteItemImage(storeId: storeId, itemId: itemId) }
                item.imageURL = nil
                try? context.save()
            }
        }
        
        syncManager.pushItemToCloud(item)
    }
    
    func archiveItem(context: ModelContext, syncManager: SyncManager, cartManager: CartManager) {
        item.isActive = false
        item.updatedAt = Date()
        cartManager.items.removeValue(forKey: item)
        try? context.save()
        syncManager.pushItemToCloud(item)
    }
    
    /// Evaluates transaction history to selectively execute a hard database deletion or a referential soft-delete.
    func permanentlyDeleteItem(hasHistory: Bool, context: ModelContext, session: SessionManager, syncManager: SyncManager, cartManager: CartManager) {
        let itemIdString = item.id.uuidString
        cartManager.items.removeValue(forKey: item)
        
        if hasHistory {
            item.name = item.name + " (Deleted)"
            item.imageData = nil
            item.imageURL = nil
            item.tags = []
            item.barcode = nil
            item.desc = nil
            item.isActive = false
            item.updatedAt = Date()
            
            try? context.save()
            
            if let storeId = session.currentUser?.activeStoreId {
                Task { await StorageManager.shared.deleteItemImage(storeId: storeId, itemId: itemIdString) }
            }
            syncManager.pushItemToCloud(item)
            
        } else {
            context.delete(item)
            try? context.save()
            
            if let storeId = session.currentUser?.activeStoreId {
                Task { await StorageManager.shared.deleteItemImage(storeId: storeId, itemId: itemIdString) }
            }
            Task { await syncManager.deleteItemFromCloud(itemIdString) }
        }
    }
}

// MARK: - View

/// Provides the interface for editing item attributes, managing photos, and handling destructive archive/delete operations.
struct EditItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CartManager.self) private var cartManager
    @Environment(SyncManager.self) private var syncManager
    @Environment(SessionManager.self) private var session
    
    @Query private var allTransactions: [Transaction]
    @State private var viewModel: EditItemViewModel
    
    @State private var isShowingTagManager = false
    @State private var isShowingScanner = false
    @State private var isShowingPhotoOptions = false
    @State private var isShowingImagePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var isShowingDeleteConfirm = false
    @State private var isShowingHardDeleteConfirm = false
    
    var onDelete: (() -> Void)? = nil
    
    enum FocusField: Hashable {
        case name, desc, price, cost, barcode
    }
    @FocusState private var focusedField: FocusField?
    
    init(item: StoreItem, onDelete: (() -> Void)? = nil) {
        self.onDelete = onDelete
        _viewModel = State(initialValue: EditItemViewModel(item: item))
    }
    
    var isInCart: Bool {
        cartManager.items.keys.contains(where: { $0.id == viewModel.item.id })
    }
    
    /// Identifies whether the active item possesses transactional history to regulate the hard deletion constraints.
    var hasTransactionalHistory: Bool {
        let itemIdString = viewModel.item.id.uuidString
        return allTransactions.contains { transaction in
            transaction.lineItems?.contains { $0.itemID == itemIdString } == true
        }
    }
    
    var body: some View {
        Form {
            photoSection
            pricingSection
            organizationSection
            detailsSection
            
            Section {
                if viewModel.item.isActive {
                    Button(role: .confirm) {
                        viewModel.saveChanges(context: modelContext, session: session, syncManager: syncManager)
                        dismiss()
                    } label: {
                        Text("Save Changes")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundStyle(.green)
                            .fontWeight(.bold)
                    }
                    .disabled(!viewModel.isFormValid)
                }
            }
            
            dangerZoneSection
        }
        .scrollDismissesKeyboard(.automatic)
        .navigationTitle("Edit Item")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Add Photo", isPresented: $isShowingPhotoOptions, titleVisibility: .visible) {
            Button("Take Photo") { imageSource = .camera; isShowingImagePicker = true }
            Button("Choose from Library") { imageSource = .photoLibrary; isShowingImagePicker = true }
            if viewModel.imageData != nil { Button("Remove Photo", role: .destructive) { viewModel.imageData = nil } }
            Button("Cancel", role: .cancel) { }
        }
        .fullScreenCover(isPresented: $isShowingImagePicker) {
            ImagePicker(sourceType: imageSource, selectedImage: $viewModel.imageData).ignoresSafeArea()
        }
        .sheet(isPresented: $isShowingScanner) {
            BarcodeScannerView(scannedCode: $viewModel.barcode)
        }
        .sheet(isPresented: $isShowingTagManager) {
            NavigationStack {
                TagManagerView(selectedTags: $viewModel.selectedTags, isSelectionMode: true)
            }
        }
        .alert("Archive Item", isPresented: $isShowingDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button(isInCart ? "Archive & Remove" : "Archive", role: .destructive) {
                viewModel.archiveItem(context: modelContext, syncManager: syncManager, cartManager: cartManager)
                dismiss()
                onDelete?()
            }
        } message: {
            if isInCart {
                Text("This item is currently in your cart. Archiving it will remove it from the cart. Continue?")
            } else {
                Text("Are you sure you want to remove \(viewModel.item.name) from the storefront? Past transaction records will be preserved.")
            }
        }
        .alert("Permanently Delete", isPresented: $isShowingHardDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button(isInCart ? "Delete & Remove" : "Delete", role: .destructive) {
                viewModel.permanentlyDeleteItem(hasHistory: hasTransactionalHistory, context: modelContext, session: session, syncManager: syncManager, cartManager: cartManager)
                dismiss()
                onDelete?()
            }
        } message: {
            if isInCart {
                Text("This item is in your cart. Permanently deleting it will strip its metadata and remove it from the cart. Continue?")
            } else {
                Text("WARNING: This will permanently delete \(viewModel.item.name) from the system.")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var photoSection: some View {
        Section {
            VStack(spacing: 16) {
                Button {
                    isShowingPhotoOptions = true
                } label: {
                    VStack(spacing: 8) {
                        if let data = viewModel.imageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color(uiColor: .secondarySystemBackground))
                                    .frame(width: 120, height: 120)
                                Image(systemName: "camera.macro")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color(uiColor: .systemGray3))
                            }
                        }
                        
                        Text(viewModel.imageData == nil ? "Add Product Photo" : "Change Photo")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(uiColor: .secondarySystemFill))
                            .foregroundStyle(.primary)
                            .clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 10)
                
                TextField("Item Name", text: $viewModel.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var pricingSection: some View {
        Section(
            header: Text("Pricing & Inventory"),
            footer: Text(viewModel.salesPriceString.isEmpty ? "Sales price is required." : "")
                .foregroundStyle(.red)
        ) {
            HStack {
                Image(systemName: "tag")
                    .foregroundStyle(viewModel.salesPriceString.isEmpty ? .red : .green)
                    .frame(width: 24)
                Text("$").foregroundStyle(.secondary)
                TextField("0.00 (Sales Price)", text: $viewModel.salesPriceString)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .price)
            }
            
            HStack {
                Image(systemName: "building.2")
                    .foregroundStyle(.gray)
                    .frame(width: 24)
                Text("$").foregroundStyle(.secondary)
                TextField("0.00 (Wholesale Cost)", text: $viewModel.itemCostString)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .cost)
            }
            
            Stepper(value: $viewModel.stockCount, in: 0...9999) {
                HStack {
                    Image(systemName: "shippingbox")
                        .foregroundStyle(.gray)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stock").font(.caption2).foregroundStyle(.secondary)
                        Text("\(viewModel.stockCount)").fontWeight(.semibold)
                    }
                }
            }
        }
    }
    
    private var organizationSection: some View {
        Section(header: Text("Organization & Identifiers")) {
            HStack {
                Image(systemName: "barcode")
                    .foregroundStyle(.gray)
                    .frame(width: 24)
                
                TextField("Scan or type barcode...", text: $viewModel.barcode)
                    .focused($focusedField, equals: .barcode)
                    .submitLabel(.done)
                
                Spacer()
                
                Button {
                    isShowingScanner = true
                } label: {
                    Image(systemName: "barcode.viewfinder")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }
            
            Button {
                isShowingTagManager = true
            } label: {
                HStack {
                    Image(systemName: "tag.circle")
                        .foregroundStyle(.gray)
                        .frame(width: 24)
                    
                    if viewModel.selectedTags.isEmpty {
                        Text("Assign Tags")
                            .foregroundStyle(.primary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(viewModel.selectedTags) { tag in
                                    TagPillView(name: tag.name)
                                }
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
        }
    }
    
    private var detailsSection: some View {
        Section(header: Text("Basic Details")) {
            HStack(alignment: .top) {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(.gray)
                    .frame(width: 24)
                    .padding(.top, 4)
                TextField("Notes or description...", text: $viewModel.desc, axis: .vertical)
                    .lineLimit(2...5)
                    .focused($focusedField, equals: .desc)
            }
        }
    }
    
    private var dangerZoneSection: some View {
        Section {
            if viewModel.item.isActive {
                Button(role: .destructive) {
                    isShowingDeleteConfirm = true
                } label: {
                    Text("Archive Item")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                Button {
                    viewModel.item.isActive = true
                    viewModel.saveChanges(context: modelContext, session: session, syncManager: syncManager)
                } label: {
                    Text("Restore to Storefront")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundStyle(.blue)
                }
                
                Button(role: .destructive) {
                    isShowingHardDeleteConfirm = true
                } label: {
                    Text("Permanently Delete")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }
}
