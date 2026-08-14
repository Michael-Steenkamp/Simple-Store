//
//  AddItemView.swift
//  Simple Store
//

import SwiftUI
import SwiftData
import PhotosUI

// MARK: - View Model

/// Manages form state, validation, and multi-tenant data ingestion for new inventory items.
@MainActor
@Observable
final class AddItemViewModel {
    var name: String = ""
    var desc: String = ""
    var stockCount: Int = 0
    var salesPriceString: String = ""
    var itemCostString: String = ""
    var barcode: String = ""
    
    var selectedTags: [ItemTag] = []
    var imageData: Data? = nil
    
    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && Double(salesPriceString) != nil
    }
    
    /// Provisions a new inventory item, uploads its photo to Storage, and syncs to Firestore.
    func saveItem(
        context: ModelContext,
        session: SessionManager,
        syncManager: SyncManager
    ) async {
        guard isFormValid else { return }
        
        let finalPrice = Double(salesPriceString) ?? 0.0
        let finalCost = Double(itemCostString) ?? 0.0
        let storeId = session.currentUser?.activeStoreId ?? ""
        
        let newItem = StoreItem(
            id: UUID(),
            storeId: storeId,
            tags: selectedTags,
            name: name.trimmingCharacters(in: .whitespaces),
            desc: desc.trimmingCharacters(in: .whitespaces).isEmpty ? nil : desc.trimmingCharacters(in: .whitespaces),
            stockCount: stockCount,
            salesPrice: finalPrice,
            itemCost: finalCost,
            barcode: barcode.trimmingCharacters(in: .whitespaces).isEmpty ? nil : barcode.trimmingCharacters(in: .whitespaces),
            imageData: imageData
        )
        
        context.insert(newItem)
        try? context.save()
        
        if let data = imageData {
            if let url = try? await StorageManager.shared.uploadItemImage(data: data, storeId: storeId, itemId: newItem.id.uuidString) {
                newItem.imageURL = url
                try? context.save()
            }
        }
        
        await syncManager.pushItemToCloud(newItem)
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - View

/// Provides the interface for creating and provisioning new inventory items.
struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session
    @Environment(SyncManager.self) private var syncManager
    
    @State private var viewModel = AddItemViewModel()
    
    @State private var isShowingScanner = false
    @State private var isShowingTagManager = false
    @State private var isShowingPhotoOptions = false
    @State private var isShowingImagePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    
    enum FocusField: Hashable {
        case name, desc, price, cost, barcode
    }
    @FocusState private var focusedField: FocusField?
    
    var body: some View {
        NavigationStack {
            Form {
                photoSection
                pricingSection
                organizationSection
                detailsSection
            }
            .scrollDismissesKeyboard(.automatic)
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveItem(context: modelContext, session: session, syncManager: syncManager)
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(!viewModel.isFormValid)
                }
            }
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
}
