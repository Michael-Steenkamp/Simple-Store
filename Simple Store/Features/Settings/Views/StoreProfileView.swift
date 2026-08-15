//
//  StoreProfileView.swift
//  Simple Store
//

import SwiftUI
import PhotosUI

// MARK: - View Model

@MainActor
@Observable
final class StoreProfileViewModel {
    
    func syncProfileToCloud(
        storeId: String,
        storeName: String,
        storeEmail: String,
        storePhone: String,
        storeAddress: String,
        storeWebsite: String,
        receiptThankYou: String,
        receiptReturnPolicy: String,
        showLogoOnReceipt: Bool,
        showAddressOnReceipt: Bool,
        showWebsiteOnReceipt: Bool,
        showEmployeeOnReceipt: Bool,
        logoData: Data?,
        syncManager: SyncManager
    ) {
        var storeLogoURL = ""
        if let logoData {
            Task {
                if let url = try? await StorageManager.shared.uploadStoreLogo(data: logoData, storeId: storeId) {
                    storeLogoURL = url
                } else {
                    storeLogoURL = "OFFLINE_CACHE"
                }
                pushPayload(storeLogoURL: storeLogoURL, storeId: storeId, storeName: storeName, storeEmail: storeEmail, storePhone: storePhone, storeAddress: storeAddress, storeWebsite: storeWebsite, receiptThankYou: receiptThankYou, receiptReturnPolicy: receiptReturnPolicy, showLogoOnReceipt: showLogoOnReceipt, showAddressOnReceipt: showAddressOnReceipt, showWebsiteOnReceipt: showWebsiteOnReceipt, showEmployeeOnReceipt: showEmployeeOnReceipt, syncManager: syncManager)
            }
        } else {
            pushPayload(storeLogoURL: storeLogoURL, storeId: storeId, storeName: storeName, storeEmail: storeEmail, storePhone: storePhone, storeAddress: storeAddress, storeWebsite: storeWebsite, receiptThankYou: receiptThankYou, receiptReturnPolicy: receiptReturnPolicy, showLogoOnReceipt: showLogoOnReceipt, showAddressOnReceipt: showAddressOnReceipt, showWebsiteOnReceipt: showWebsiteOnReceipt, showEmployeeOnReceipt: showEmployeeOnReceipt, syncManager: syncManager)
        }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func pushPayload(
        storeLogoURL: String,
        storeId: String,
        storeName: String,
        storeEmail: String,
        storePhone: String,
        storeAddress: String,
        storeWebsite: String,
        receiptThankYou: String,
        receiptReturnPolicy: String,
        showLogoOnReceipt: Bool,
        showAddressOnReceipt: Bool,
        showWebsiteOnReceipt: Bool,
        showEmployeeOnReceipt: Bool,
        syncManager: SyncManager
    ) {
        let payload: [String: Any] = [
            "storeName": storeName,
            "storeEmail": storeEmail,
            "storePhone": storePhone,
            "storeAddress": storeAddress,
            "storeWebsite": storeWebsite,
            "receiptThankYou": receiptThankYou,
            "receiptReturnPolicy": receiptReturnPolicy,
            "showLogoOnReceipt": showLogoOnReceipt,
            "showAddressOnReceipt": showAddressOnReceipt,
            "showWebsiteOnReceipt": showWebsiteOnReceipt,
            "showEmployeeOnReceipt": showEmployeeOnReceipt,
            "storeLogoURL": storeLogoURL
        ]
        
        syncManager.pushStoreProfileToCloud(storeId: storeId, payload: payload)
    }
}

// MARK: - View

/// An interface for defining the public-facing identity and details of the active workspace.
struct StoreProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session
    @Environment(SyncManager.self) private var syncManager
    
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
    @State private var viewModel = StoreProfileViewModel()
    @State private var logoData: Data? = nil
    @State private var isShowingPhotoOptions = false
    @State private var isShowingImagePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    
    @FocusState private var isPhoneFocused: Bool
    
    var isEmailValid: Bool {
        let trimmed = storeEmail.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed.isValidEmail
    }
    
    var body: some View {
        Form {
            brandSection
            contactSection
            receiptConfigurationSection
            receiptVisibilitySection
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle("Store Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    guard let storeId = session.currentUser?.activeStoreId else {
                        dismiss()
                        return
                    }
                    viewModel.syncProfileToCloud(
                        storeId: storeId,
                        storeName: storeName,
                        storeEmail: storeEmail,
                        storePhone: storePhone,
                        storeAddress: storeAddress,
                        storeWebsite: storeWebsite,
                        receiptThankYou: receiptThankYou,
                        receiptReturnPolicy: receiptReturnPolicy,
                        showLogoOnReceipt: showLogoOnReceipt,
                        showAddressOnReceipt: showAddressOnReceipt,
                        showWebsiteOnReceipt: showWebsiteOnReceipt,
                        showEmployeeOnReceipt: showEmployeeOnReceipt,
                        logoData: logoData,
                        syncManager: syncManager
                    )
                    dismiss()
                }
                .fontWeight(.bold)
                .disabled(!isEmailValid || storeName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if let cachedLogo = UserDefaults.standard.data(forKey: "storeLogo") {
                logoData = cachedLogo
            }
        }
        .onChange(of: isPhoneFocused) { _, isFocused in
            if !isFocused {
                storePhone = storePhone.formattedAsPhoneNumber
            }
        }
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
    
    // MARK: - Subviews
    
    private var brandSection: some View {
        Section {
            VStack(spacing: 16) {
                Button {
                    isShowingPhotoOptions = true
                } label: {
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
                                .foregroundStyle(Color(uiColor: .systemGray4))
                        }
                        
                        Text(logoData == nil ? "Add Logo" : "Edit Logo")
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
                .padding(.top, 10)
                
                TextField("Simple Store Name", text: $storeName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var contactSection: some View {
        Section(
            header: Text("Store Information"),
            footer: Text(isEmailValid ? "" : "Please ensure email formats are correct.")
                .foregroundStyle(.red)
        ) {
            HStack {
                Image(systemName: "envelope")
                    .foregroundStyle(isEmailValid ? .gray : .red)
                    .frame(width: 24)
                TextField("name@example.com (Optional)", text: $storeEmail)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            
            HStack {
                Image(systemName: "phone")
                    .foregroundStyle(.gray)
                    .frame(width: 24)
                TextField("e.g. +1 306 555 5555", text: $storePhone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .focused($isPhoneFocused)
            }
            
            HStack(alignment: .top) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(.gray)
                    .frame(width: 24)
                    .padding(.top, 4)
                TextField("Physical Address", text: $storeAddress, axis: .vertical)
                    .lineLimit(2...4)
                    .textContentType(.fullStreetAddress)
            }
            
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(.gray)
                    .frame(width: 24)
                TextField("Website URL", text: $storeWebsite)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
            }
        }
    }
    
    private var receiptConfigurationSection: some View {
        Section(
            header: Text("Custom Messaging"),
            footer: Text("This text will appear at the top and bottom of your generated PDF receipts.")
        ) {
            VStack(alignment: .leading) {
                Text("Header Message")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. Thank you for your business!", text: $receiptThankYou, axis: .vertical)
            }
            
            VStack(alignment: .leading) {
                Text("Footer / Policy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. No returns on opened items.", text: $receiptReturnPolicy, axis: .vertical)
            }
        }
    }
    
    private var receiptVisibilitySection: some View {
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
}
