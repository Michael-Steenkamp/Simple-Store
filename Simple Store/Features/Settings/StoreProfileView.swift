//
//  StoreProfileView.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-07-22.
//

import SwiftUI
import PhotosUI

struct StoreProfileView: View {
    // MARK: - Auto-Saving Data Bindings
    @AppStorage("storeName") private var storeName: String = ""
    @AppStorage("storeEmail") private var storeEmail: String = ""
    @AppStorage("storePhone") private var storePhone: String = ""
    @AppStorage("storeAddress") private var storeAddress: String = ""
    @AppStorage("storeWebsite") private var storeWebsite: String = ""
    
    @AppStorage("receiptThankYou") private var receiptThankYou: String = ""
    @AppStorage("receiptReturnPolicy") private var receiptReturnPolicy: String = ""
    @AppStorage("showLogoOnReceipt") private var showLogoOnReceipt: Bool = true
    @AppStorage("showAddressOnReceipt") private var showAddressOnReceipt: Bool = true
    @AppStorage("showWebsiteOnReceipt") private var showWebsiteOnReceipt: Bool = true
    @AppStorage("showCashierOnReceipt") private var showEmployeeOnReceipt: Bool = true
    
    // MARK: - UI State
    @State private var logoData: Data? = UserDefaults.standard.data(forKey: "storeLogo")
    @State private var isShowingPhotoOptions = false
    @State private var isShowingImagePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    
    // Used to trigger phone formatting when the user finishes typing
    @FocusState private var isPhoneFocused: Bool
    
    // Validates the email live
    var isEmailValid: Bool {
        let trimmed = storeEmail.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed.isValidEmail
    }
    
    var body: some View {
        Form {
            // MARK: - Store Brand Header
            Section {
                VStack(spacing: 16) {
                    Button(action: {
                        isShowingPhotoOptions = true
                    }) {
                        VStack(spacing: 8) {
                            if let data = logoData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
                            } else {
                                Image(systemName: "storefront.circle.fill")
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(Color(UIColor.systemGray4))
                            }
                            
                            Text(logoData == nil ? "Add Logo" : "Edit Logo")
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
                    
                    TextField("Simple Store Name", text: $storeName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity)
            }
            
            // MARK: - Store Contact Information
            Section(
                header: Text("Store Information"),
                footer: Text(isEmailValid ? "" : "Please ensure email formats are correct.")
                    .foregroundColor(.red)
            ) {
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(isEmailValid ? .gray : .red)
                        .frame(width: 24)
                    TextField("name@example.com (Optional)", text: $storeEmail)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                
                HStack {
                    Image(systemName: "phone")
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    TextField("e.g. +1 306 555 5555", text: $storePhone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .focused($isPhoneFocused)
                }
                
                HStack(alignment: .top) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.gray)
                        .frame(width: 24)
                        .padding(.top, 4)
                    TextField("Physical Address", text: $storeAddress, axis: .vertical)
                        .lineLimit(2...4)
                        .textContentType(.fullStreetAddress)
                }
                
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    TextField("Website URL", text: $storeWebsite)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                }
            }
            
            // MARK: - Receipt Configuration
            Section(
                header: Text("Custom Messaging"),
                footer: Text("This text will appear at the top and bottom of your generated PDF receipts.")
            ) {
                VStack(alignment: .leading) {
                    Text("Header Message")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g. Thank you for your business!", text: $receiptThankYou, axis: .vertical)
                }
                
                VStack(alignment: .leading) {
                    Text("Footer / Policy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g. No returns on opened items.", text: $receiptReturnPolicy, axis: .vertical)
                }
            }
            
            Section(
                header: Text("Layout & Visibility"),
                footer: Text("Toggle which parts of your Store Profile are included on the receipt.")
            ) {
                Toggle("Show Store Logo", isOn: $showLogoOnReceipt)
                Toggle("Show Physical Address", isOn: $showAddressOnReceipt)
                Toggle("Show Website Link", isOn: $showWebsiteOnReceipt)
                Toggle("Show \"Served By\" Name", isOn: $showEmployeeOnReceipt)
            }
        }
        .dismissKeyboardOnTap()
        .navigationTitle("Store Profile")
        .navigationBarTitleDisplayMode(.inline)
        // Clean up the phone number format when the user finishes typing
        .onChange(of: isPhoneFocused) { _, isFocused in
            if !isFocused {
                storePhone = storePhone.formattedAsPhoneNumber()
            }
        }
        // Save or remove logo immediately upon selection
        .onChange(of: logoData) { _, newData in
            if let newData {
                UserDefaults.standard.set(newData, forKey: "storeLogo")
            } else {
                UserDefaults.standard.removeObject(forKey: "storeLogo")
            }
        }
        .confirmationDialog("Update Store Logo", isPresented: $isShowingPhotoOptions, titleVisibility: .visible) {
            Button("Take Photo") { imageSource = .camera; isShowingImagePicker = true }
            Button("Choose from Library") { imageSource = .photoLibrary; isShowingImagePicker = true }
            if logoData != nil { Button("Remove Logo", role: .destructive) { logoData = nil } }
            Button("Cancel", role: .cancel) { }
        }
        .fullScreenCover(isPresented: $isShowingImagePicker) {
            ImagePicker(sourceType: imageSource, selectedImage: $logoData).ignoresSafeArea()
        }
    }
}
