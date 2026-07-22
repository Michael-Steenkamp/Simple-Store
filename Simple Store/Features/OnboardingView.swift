//
//  OnboardingView.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-21.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
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
    
    @State private var logoData: Data? = UserDefaults.standard.data(forKey: "storeLogo")
    
    @State private var isShowingPhotoOptions = false
    @State private var isShowingImagePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    
    var isFormComplete: Bool {
        !storeName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text("Welcome to Simple Store")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Let's take a few minutes to set up your store!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 32)
                .padding(.bottom, 24)
                
                Form {
                    Section {
                        VStack(spacing: 16) {
                            Button(action: { isShowingPhotoOptions = true
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
                            .confirmationDialog("Add Store Logo", isPresented: $isShowingPhotoOptions, titleVisibility: .visible) {
                                Button("Take Photo") { imageSource = .camera; isShowingImagePicker = true }
                                Button("Choose from Library") { imageSource = .photoLibrary; isShowingImagePicker = true }
                                if logoData != nil { Button("Remove Logo", role: .destructive) { logoData = nil } }
                                Button("Cancel", role: .cancel) { }
                            }
                            .fullScreenCover(isPresented: $isShowingImagePicker) {
                                ImagePicker(sourceType: imageSource, selectedImage: $logoData).ignoresSafeArea()
                            }
                            
                            
                            TextField("Simple Store Name", text: $storeName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 10)
                            
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    Section(header: Text("Store Information")) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Spacer()
                            TextField("Email Address", text: $storeEmail)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                        }
                        HStack {
                            Image(systemName: "phone.fill")
                            Spacer()
                            TextField("Phone Number", text: $storePhone)
                                .keyboardType(.phonePad)
                        }
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                            Spacer()
                            TextField("Physical Address", text: $storeAddress)
                        }
                        HStack {
                            Image(systemName: "link")
                            Spacer()
                            TextField("Website Link (e.g. www.store.com)", text: $storeWebsite)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                        }
                    }
                    
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
                
                VStack {
                    Button(action: {
                        if let logoData {
                            UserDefaults.standard.set(logoData, forKey: "storeLogo")
                        } else {
                            UserDefaults.standard.removeObject(forKey: "storeLogo")
                        }
                        
                        withAnimation(.spring) {
                            hasCompletedOnboarding = true
                        }
                    }) {
                        Text("Finish Setup")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundColor(.white)
                            .background(isFormComplete ? Color.blue : Color.gray)
                            .cornerRadius(12)
                            .shadow(color: isFormComplete ? Color.blue.opacity(0.3) : Color.clear, radius: 5, y: 3)
                    }
                    .disabled(!isFormComplete)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .padding(.top, 16)
                }
                .background(Color(UIColor.systemGroupedBackground))
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        }
    }
}
