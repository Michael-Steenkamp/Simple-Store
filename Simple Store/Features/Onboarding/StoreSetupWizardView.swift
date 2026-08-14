//
//  StoreSetupWizardView.swift
//  Simple Store
//

import SwiftUI
import PhotosUI

// MARK: - View Model

/// Manages form state, input validation, and Firebase provisioning for new multi-tenant workspaces.
@MainActor
@Observable
final class StoreSetupWizardViewModel {
    var storeName: String = ""
    var storeEmail: String = ""
    var storePhone: String = ""
    var storeAddress: String = ""
    
    var logoData: Data? = nil
    
    var isProcessing = false
    var errorMessage = ""
    
    var isFormValid: Bool {
        !storeName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    /// Executes the workspace creation sequence and binds the user as the primary administrator.
    func createStore(session: SessionManager) async -> Bool {
        isProcessing = true
        errorMessage = ""
        
        defer {
            isProcessing = false
        }
        
        do {
            try await session.createStore(
                storeName: storeName.trimmingCharacters(in: .whitespaces),
                storeEmail: storeEmail.trimmingCharacters(in: .whitespaces),
                storePhone: storePhone,
                storeAddress: storeAddress.trimmingCharacters(in: .whitespaces),
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
    
    /// Sanitizes and structures the phone number input when the field loses focus.
    func formatPhoneInput() {
        storePhone = storePhone.formattedAsPhoneNumber
    }
}

// MARK: - View

/// Provides the onboarding interface for users to provision and configure a new retail workspace.
struct StoreSetupWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session
    
    @State private var viewModel = StoreSetupWizardViewModel()
    
    @State private var isShowingPhotoOptions = false
    @State private var isShowingImagePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    
    @FocusState private var isPhoneFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                if !viewModel.errorMessage.isEmpty {
                    Section {
                        Text(viewModel.errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
                
                logoAndNameSection
                contactInformationSection
                actionSection
            }
            .navigationTitle("New Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
    }
    
    // MARK: - Subviews
    
    private var logoAndNameSection: some View {
        Section {
            VStack(spacing: 16) {
                Text("Let's get your store set up.")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                
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
                            ZStack {
                                Circle()
                                    .fill(Color(uiColor: .secondarySystemBackground))
                                    .frame(width: 100, height: 100)
                                Image(systemName: "camera.macro")
                                    .font(.system(size: 30))
                                    .foregroundStyle(Color(uiColor: .systemGray3))
                            }
                        }
                        
                        Text(viewModel.logoData == nil ? "Add Logo (Optional)" : "Change Logo")
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
                
                TextField("Store Name (Required)", text: $viewModel.storeName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var contactInformationSection: some View {
        Section(header: Text("Contact Information (Optional)")) {
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
        }
    }
    
    private var actionSection: some View {
        Section {
            Button {
                Task {
                    let success = await viewModel.createStore(session: session)
                    if success { dismiss() }
                }
            } label: {
                HStack {
                    if viewModel.isProcessing {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Text("Create Store")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
                .foregroundStyle(.white)
            }
            .listRowBackground(viewModel.isFormValid && !viewModel.isProcessing ? Color.accentColor : Color.gray.opacity(0.5))
            .disabled(!viewModel.isFormValid || viewModel.isProcessing)
        }
    }
}
