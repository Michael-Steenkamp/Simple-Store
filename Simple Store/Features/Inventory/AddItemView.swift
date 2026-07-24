//
//  AddItemView.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-07-18.
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var desc: String = ""
    @State private var stockCount: Int = 0
    @State private var salesPriceString: String = ""
    @State private var itemCostString: String = ""
    @State private var barcode: String = ""
    
    @State private var selectedTags: [ItemTag] = []
    @State private var imageData: Data? = nil
    
    @State private var isShowingScanner = false
    @State private var isShowingTagManager = false
    @State private var isShowingPhotoOptions = false
    @State private var isShowingImagePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    
    enum FocusField: Hashable {
        case name, desc, price, cost, barcode
    }
    @FocusState private var focusedField: FocusField?
    
    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && Double(salesPriceString) != nil
    }
    
    var body: some View {
        NavigationStack {
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
                            hideKeyboard()
                            isShowingScanner = true
                        }) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    Button(action: {
                        hideKeyboard()
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
                                            TagPillView(name: tag.name) // Use the standard shared component
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
                    .buttonStyle(.borderless) // Protects against the global tap-to-dismiss gesture
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
            }
            .dismissKeyboardOnTap()
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveItem()
                    }
                    .fontWeight(.bold)
                    .disabled(!isFormValid)
                }
            }
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
        }
    }
    
    private func saveItem() {
        let finalPrice = Double(salesPriceString) ?? 0.0
        let finalCost = Double(itemCostString) ?? 0.0
        
        let newItem = StoreItem(
            tags: selectedTags,
            name: name.trimmingCharacters(in: .whitespaces),
            desc: desc.trimmingCharacters(in: .whitespaces).isEmpty ? nil : desc.trimmingCharacters(in: .whitespaces),
            stockCount: stockCount,
            salesPrice: finalPrice,
            itemCost: finalCost,
            barcode: barcode.trimmingCharacters(in: .whitespaces).isEmpty ? nil : barcode.trimmingCharacters(in: .whitespaces),
            imageData: imageData
        )
        
        modelContext.insert(newItem)
        try? modelContext.save()
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        dismiss()
    }
}
