//
//  EditItemView.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-07-18.
//

import SwiftUI
import SwiftData
import PhotosUI

struct EditItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CartManager.self) private var cartManager
    
    let item: StoreItem
    var onDelete: (() -> Void)? = nil
    
    @State private var name: String
    @State private var desc: String
    @State private var stockCount: Int
    @State private var salesPriceString: String
    @State private var itemCostString: String
    @State private var barcode: String
    @State private var selectedTags: [ItemTag]
    @State private var imageData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    @State private var isShowingTagManager = false
    @State private var isShowingScanner = false
    @State private var isShowingPhotoOptions = false
    @State private var isShowingImagePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var isShowingDeleteConfirm = false
    @State private var isShowingHardDeleteConfirm = false
    
    enum FocusField: Hashable {
        case name, desc, price, cost, barcode
    }
    @FocusState private var focusedField: FocusField?
    
    init(item: StoreItem, onDelete: (() -> Void)? = nil) {
        self.item = item
        self.onDelete = onDelete
        
        _name = State(initialValue: item.name)
        _desc = State(initialValue: item.desc ?? "")
        _stockCount = State(initialValue: item.stockCount)
        _salesPriceString = State(initialValue: item.salesPrice == 0.0 ? "" : String(format: "%.2f", item.salesPrice))
        _itemCostString = State(initialValue: item.itemCost == 0.0 ? "" : String(format: "%.2f", item.itemCost))
        _barcode = State(initialValue: item.barcode ?? "")
        _selectedTags = State(initialValue: item.tags ?? [])
        _imageData = State(initialValue: item.imageData)
    }
    
    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && Double(salesPriceString) != nil
    }
    
    // Live check to adjust the danger zone alerts
    var isInCart: Bool {
        cartManager.items.keys.contains(where: { $0.id == item.id })
    }
    
    var body: some View {
        Form {
            // MARK: - Product Image
            Section {
                VStack(spacing: 16) {
                    Button(action: {
                        isShowingPhotoOptions = true
                    }) {
                        VStack(spacing: 8) {
                            if let data = imageData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(Color(UIColor.secondarySystemBackground))
                                        .frame(width: 120, height: 120)
                                    Image(systemName: "camera.macro")
                                        .font(.system(size: 40))
                                        .foregroundColor(Color(UIColor.systemGray3))
                                }
                            }
                            
                            Text(imageData == nil ? "Add Product Photo" : "Change Photo")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(UIColor.secondarySystemFill))
                                .foregroundColor(.primary)
                                .clipShape(Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    
                    TextField("Item Name", text: $name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity)
            }
            
            // MARK: - Pricing & Stock
            Section(
                header: Text("Pricing & Inventory"),
                footer: Text(salesPriceString.isEmpty ? "Sales price is required." : "")
                    .foregroundColor(.red)
            ) {
                HStack {
                    Image(systemName: "tag")
                        .foregroundColor(salesPriceString.isEmpty ? .red : .green)
                        .frame(width: 24)
                    Text("$").foregroundColor(.secondary)
                    TextField("0.00 (Sales Price)", text: $salesPriceString)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .price)
                }
                
                HStack {
                    Image(systemName: "building.2")
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    Text("$").foregroundColor(.secondary)
                    TextField("0.00 (Wholesale Cost)", text: $itemCostString)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .cost)
                }
                
                Stepper(value: $stockCount, in: 0...9999) {
                    HStack {
                        Image(systemName: "shippingbox")
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Stock").font(.caption2).foregroundColor(.secondary)
                            Text("\(stockCount)").fontWeight(.semibold)
                        }
                    }
                }
            }
            
            // MARK: - Organization
            Section(header: Text("Organization & Identifiers")) {
                HStack {
                    Image(systemName: "barcode")
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    
                    TextField("Scan or type barcode...", text: $barcode)
                        .focused($focusedField, equals: .barcode)
                        .submitLabel(.done)
                    
                    Spacer()
                    
                    Button(action: {
                        isShowingScanner = true
                    }) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
                
                Button(action: {
                    isShowingTagManager = true
                }) {
                    HStack {
                        Image(systemName: "tag.circle")
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        
                        if selectedTags.isEmpty {
                            Text("Assign Tags")
                                .foregroundColor(.primary)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(selectedTags) { tag in
                                        TagPillView(name: tag.name)
                                    }
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                }
            }
            
            // MARK: - Basic Details
            Section(header: Text("Basic Details")) {
                
                HStack(alignment: .top) {
                    Image(systemName: "text.alignleft")
                        .foregroundColor(.gray)
                        .frame(width: 24)
                        .padding(.top, 4)
                    TextField("Notes or description...", text: $desc, axis: .vertical)
                        .lineLimit(2...5)
                        .focused($focusedField, equals: .desc)
                }
            }
            
            // MARK: - Save
            Section {
                if item.isActive {
                    Button(role: .confirm, action: {
                        saveChanges()
                    }) {
                        Text("Save Changes")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.green)
                            .fontWeight(.bold)
                    }
                }
            }
            
            // MARK: - Danger Zone
            Section {
                if item.isActive {
                    Button(role: .destructive, action: {
                        isShowingDeleteConfirm = true
                    }) {
                        Text("Archive Item")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else {
                    Button(action: {
                        item.isActive = true
                        saveChanges()
                    }) {
                        Text("Restore to Storefront")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.blue)
                    }
                    
                    Button(role: .destructive, action: {
                        isShowingHardDeleteConfirm = true
                    }) {
                        Text("Permanently Delete")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.automatic)
        .navigationTitle("Edit Item")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Add Photo", isPresented: $isShowingPhotoOptions, titleVisibility: .visible) {
            Button("Take Photo") { imageSource = .camera; isShowingImagePicker = true }
            Button("Choose from Library") { imageSource = .photoLibrary; isShowingImagePicker = true }
            if imageData != nil { Button("Remove Photo", role: .destructive) { imageData = nil } }
            Button("Cancel", role: .cancel) { }
        }
        .fullScreenCover(isPresented: $isShowingImagePicker) {
            ImagePicker(sourceType: imageSource, selectedImage: $imageData).ignoresSafeArea()
        }
        .sheet(isPresented: $isShowingScanner) {
            BarcodeScannerView(scannedCode: $barcode)
        }
        .sheet(isPresented: $isShowingTagManager) {
            NavigationStack {
                TagManagerView(selectedTags: $selectedTags, isSelectionMode: true)
            }
        }
        .alert("Archive Item", isPresented: $isShowingDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button(isInCart ? "Archive & Remove" : "Archive", role: .destructive) {
                item.isActive = false
                item.updatedAt = Date()
                cartManager.items.removeValue(forKey: item)
                try? modelContext.save()
                dismiss()
                onDelete?()
            }
        } message: {
            if isInCart {
                Text("This item is currently in your cart. Archiving it will remove it from the cart. Continue?")
            } else {
                Text("Are you sure you want to remove \(item.name) from the storefront? Past transaction records will be preserved.")
            }
        }
        .alert("Permanently Delete", isPresented: $isShowingHardDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button(isInCart ? "Delete & Remove" : "Delete", role: .destructive) {
                item.name = item.name + " (Deleted)"
                item.imageData = nil
                item.tags = []
                item.barcode = nil
                item.desc = nil
                item.isActive = false
                item.updatedAt = Date()
                
                cartManager.items.removeValue(forKey: item)
                
                try? modelContext.save()
                dismiss()
                onDelete?()
            }
        } message: {
            if isInCart {
                Text("This item is in your cart. Permanently deleting it will strip its metadata and remove it from the cart. Continue?")
            } else {
                Text("WARNING: This will permanently strip the metadata of \(item.name) and remove it from the system. Transaction records will be preserved.")
            }
        }
    }
    
    private func saveChanges() {
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
        
        try? modelContext.save()
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        dismiss()
    }
}
