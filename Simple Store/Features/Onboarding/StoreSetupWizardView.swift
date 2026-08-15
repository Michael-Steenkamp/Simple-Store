//
//  StoreSetupWizardView.swift
//  Simple Store
//

import SwiftUI
import PhotosUI

// MARK: - View Model

@MainActor
@Observable
final class StoreSetupWizardViewModel {
    var storeName: String = ""
    var storeEmail: String = ""
    var storePhone: String = ""
    var storeAddress: String = ""
    var storeWebsite: String = ""
    
    var receiptThankYou: String = ""
    var receiptReturnPolicy: String = ""
    var showLogoOnReceipt: Bool = true
    var showAddressOnReceipt: Bool = true
    var showWebsiteOnReceipt: Bool = true
    var showEmployeeOnReceipt: Bool = true
    
    var logoData: Data? = nil
    var isProcessing = false
    var errorMessage = ""
    
    var isFormValid: Bool {
        !storeName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    func createStore(session: SessionManager) async -> Bool {
        isProcessing = true
        errorMessage = ""
        
        defer { isProcessing = false }
        
        do {
            try await session.createStore(
                storeName: storeName.trimmingCharacters(in: .whitespaces),
                storeEmail: storeEmail.trimmingCharacters(in: .whitespaces),
                storePhone: storePhone,
                storeAddress: storeAddress.trimmingCharacters(in: .whitespaces),
                storeWebsite: storeWebsite.trimmingCharacters(in: .whitespaces),
                receiptThankYou: receiptThankYou,
                receiptReturnPolicy: receiptReturnPolicy,
                showLogoOnReceipt: showLogoOnReceipt,
                showAddressOnReceipt: showAddressOnReceipt,
                showWebsiteOnReceipt: showWebsiteOnReceipt,
                showEmployeeOnReceipt: showEmployeeOnReceipt,
                logoData: logoData
            )
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func formatPhoneInput() {
        storePhone = storePhone.formattedAsPhoneNumber
    }
}

// MARK: - View

/// Provides the onboarding interface for users to provision and configure a new retail workspace.
struct StoreSetupWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session
    
    /// Regulates the visibility of the cancellation controls to prevent redundant top-navigation elements.
    var isPresentedInSheet: Bool = true
    
    @State private var viewModel = StoreSetupWizardViewModel()
    
    @State private var isShowingPhotoOptions = false
    @State private var isShowingImagePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    
    @FocusState private var isPhoneFocused: Bool
    
    var body: some View {
        Form {
            if !viewModel.errorMessage.isEmpty {
                Section {
                    Text(viewModel.errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
            
            brandSection
            contactSection
            receiptConfigurationSection
            receiptVisibilitySection
        }
        .navigationTitle("New Store")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isPresentedInSheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        let success = await viewModel.createStore(session: session)
                        if success { dismiss() }
                    }
                } label: {
                    if viewModel.isProcessing {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Create").fontWeight(.bold)
                    }
                }
                .disabled(!viewModel.isFormValid || viewModel.isProcessing)
            }
        }
        .onChange(of: isPhoneFocused) { _, isFocused in
            if !isFocused {
                viewModel.formatPhoneInput()
            }
        }
        .confirmationDialog("Add Logo", isPresented: $isShowingPhotoOptions, titleVisibility: .visible) {
            Button("Take Photo") { imageSource = .camera; isShowingImagePicker = true }
            Button("Choose from Library") { imageSource = .photoLibrary; isShowingImagePicker = true }
            if viewModel.logoData != nil { Button("Remove Logo", role: .destructive) { viewModel.logoData = nil } }
            Button("Cancel", role: .cancel) { }
        }
        .fullScreenCover(isPresented: $isShowingImagePicker) {
            ImagePicker(sourceType: imageSource, selectedImage: $viewModel.logoData).ignoresSafeArea()
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
                        if let data = viewModel.logoData, let uiImage = UIImage(data: data) {
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
                        
                        Text(viewModel.logoData == nil ? "Add Logo" : "Edit Logo")
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
                
                TextField("Simple Store Name", text: $viewModel.storeName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var contactSection: some View {
        Section(header: Text("Store Information (Optional)")) {
            HStack {
                Image(systemName: "envelope")
                    .foregroundStyle(.gray)
                    .frame(width: 24)
                TextField("Business Email", text: $viewModel.storeEmail)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            
            HStack {
                Image(systemName: "phone")
                    .foregroundStyle(.gray)
                    .frame(width: 24)
                TextField("Phone Number", text: $viewModel.storePhone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .focused($isPhoneFocused)
            }
            
            HStack(alignment: .top) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(.gray)
                    .frame(width: 24)
                    .padding(.top, 4)
                TextField("Physical Address", text: $viewModel.storeAddress, axis: .vertical)
                    .lineLimit(2...4)
                    .textContentType(.fullStreetAddress)
            }
            
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(.gray)
                    .frame(width: 24)
                TextField("Website URL", text: $viewModel.storeWebsite)
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
                TextField("e.g. Thank you for your business!", text: $viewModel.receiptThankYou, axis: .vertical)
            }
            
            VStack(alignment: .leading) {
                Text("Footer / Policy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. No returns on opened items.", text: $viewModel.receiptReturnPolicy, axis: .vertical)
            }
        }
    }
    
    private var receiptVisibilitySection: some View {
        Section(
            header: Text("Layout & Visibility"),
            footer: Text("Toggle which parts of your Store Profile are included on the receipt.")
        ) {
            Toggle("Show Store Logo", isOn: $viewModel.showLogoOnReceipt)
            Toggle("Show Physical Address", isOn: $viewModel.showAddressOnReceipt)
            Toggle("Show Website Link", isOn: $viewModel.showWebsiteOnReceipt)
            Toggle("Show \"Served By\" Name", isOn: $viewModel.showEmployeeOnReceipt)
        }
    }
}
