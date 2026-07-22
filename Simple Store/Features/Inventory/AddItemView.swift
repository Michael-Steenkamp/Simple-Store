//
//  AddItemView.swift
//  Simple Inventory
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
        case name, desc, price, cost, barcode, stock
    }
    @FocusState private var focusedField: FocusField?
    
    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && Double(salesPriceString) != nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    
                    ItemPhotoSelectionButton(imageData: imageData) {
                        isShowingPhotoOptions = true
                    }
                    .padding(.top, 20)
                    
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Tags")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(action: { isShowingTagManager = true }) {
                                    Image(systemName: "tag.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            if selectedTags.isEmpty {
                                Text("None")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                FormTagRow(tags: selectedTags)
                            }
                        }
                        
                        Divider()
                        
                        ModernTextField(title: "Item Name *", placeholder: "e.g. Premium Coffee Beans", text: $name)
                            .focused($focusedField, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .price }
                        
                        ModernTextField(title: "Notes (Optional)", placeholder: "Any specific details...", text: $desc)
                            .focused($focusedField, equals: .desc)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .barcode }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    VStack(spacing: 20) {
                        HStack(spacing: 16) {
                            ModernCurrencyField(title: "Sales Price *", text: $salesPriceString)
                                .focused($focusedField, equals: .price)
                            
                            ModernCurrencyField(title: "Wholesale Cost", text: $itemCostString)
                                .focused($focusedField, equals: .cost)
                        }
                        
                        Divider()
                        
                        ItemStockStepper(stockCount: $stockCount, focusedField: $focusedField, equals: .stock)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    VStack(spacing: 16) {
                        HStack {
                            ModernTextField(title: "Barcode", placeholder: "Scan or type...", text: $barcode)
                                .focused($focusedField, equals: .barcode)
                                .submitLabel(.done)
                                .onSubmit { focusedField = nil }
                            
                            Button(action: { isShowingScanner = true }) {
                                Image(systemName: "barcode.viewfinder")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .frame(width: 53, height: 53)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                            .padding(.top, 20)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .overlay(
            VStack {
                Spacer()
                Button(action: saveItem) {
                    Text("Create Item")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isFormValid ? Color.blue : Color.gray)
                        .cornerRadius(16)
                        .shadow(color: isFormValid ? Color.blue.opacity(0.3) : .clear, radius: 10, y: 5)
                }
                .disabled(!isFormValid)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .background(
                    LinearGradient(gradient: Gradient(colors: [Color(UIColor.systemBackground).opacity(0), Color(UIColor.systemBackground)]), startPoint: .top, endPoint: .bottom)
                        .frame(height: 100)
                        .offset(y: 10)
                )
            }
        )
        .navigationTitle("New Item")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Add Photo", isPresented: $isShowingPhotoOptions, titleVisibility: .visible) {
            Button("Take Photo") {
                imageSource = .camera
                isShowingImagePicker = true
            }
            Button("Choose from Library") {
                imageSource = .photoLibrary
                isShowingImagePicker = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .fullScreenCover(isPresented: $isShowingImagePicker) {
            ImagePicker(sourceType: imageSource, selectedImage: $imageData)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $isShowingScanner) {
            BarcodeScannerView(scannedCode: $barcode)
        }
        .sheet(isPresented: $isShowingTagManager) {
            TagManagerView(selectedTags: $selectedTags, isSelectionMode: true)
        }
    }
    
    private func saveItem() {
        let finalPrice = Double(salesPriceString) ?? 0.0
        let finalCost = Double(itemCostString) ?? 0.0
        
        let newItem = StoreItem(
            tags: selectedTags,
            name: name,
            desc: desc.isEmpty ? nil : desc,
            stockCount: stockCount,
            salesPrice: finalPrice,
            itemCost: finalCost,
            barcode: barcode.isEmpty ? nil : barcode,
            imageData: imageData
        )
        
        modelContext.insert(newItem)
        try? modelContext.save()
        dismiss()
    }
}
