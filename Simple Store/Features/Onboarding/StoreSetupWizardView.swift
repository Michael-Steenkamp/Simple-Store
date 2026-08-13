//
//  StoreSetupWizardView.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-08-11.
//

import SwiftUI
import PhotosUI

struct StoreSetupWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session
    
    @State private var storeName: String = ""
    @State private var storeEmail: String = ""
    @State private var storePhone: String = ""
    @State private var storeAddress: String = ""
    
    @State private var logoData: Data? = nil
    @State private var isShowingPhotoOptions = false
    @State private var isShowingImagePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    
    @State private var isProcessing = false
    @State private var errorMessage = ""
    
    @FocusState private var isPhoneFocused: Bool
    
    var isFormValid: Bool {
        !storeName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    VStack(spacing: 16) {
                        Text("Let's get your store set up.")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                        
                        Button(action: { isShowingPhotoOptions = true }) {
                            VStack(spacing: 8) {
                                if let data = logoData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
                                } else {
                                    ZStack {
                                        Circle()
                                            .fill(Color(UIColor.secondarySystemBackground))
                                            .frame(width: 100, height: 100)
                                        Image(systemName: "camera.macro")
                                            .font(.system(size: 30))
                                            .foregroundColor(Color(UIColor.systemGray3))
                                    }
                                }
                                
                                Text(logoData == nil ? "Add Logo (Optional)" : "Change Logo")
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
                        .padding(.vertical, 10)
                        
                        TextField("Store Name (Required)", text: $storeName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 10)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Section(header: Text("Contact Information (Optional)")) {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        TextField("Business Email", text: $storeEmail)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    
                    HStack {
                        Image(systemName: "phone")
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        TextField("Phone Number", text: $storePhone)
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
                }
                
                Section {
                    Button(action: {
                        Task { await createStore() }
                    }) {
                        HStack {
                            if isProcessing {
                                ProgressView().controlSize(.small).tint(.white)
                            } else {
                                Text("Create Store")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                        .foregroundColor(.white)
                    }
                    .listRowBackground(isFormValid && !isProcessing ? Color.blue : Color.gray.opacity(0.5))
                    .disabled(!isFormValid || isProcessing)
                }
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
                    storePhone = storePhone.formattedAsPhoneNumber()
                }
            }
            .confirmationDialog("Add Logo", isPresented: $isShowingPhotoOptions, titleVisibility: .visible) {
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
    
    private func createStore() async {
        isProcessing = true
        errorMessage = ""
        
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
            
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isProcessing = false
        }
    }
}
