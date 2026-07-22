//
//  SettingsTabView.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-19.
//

import SwiftUI
import SwiftData
import PhotosUI

struct SettingsTabView: View {
    @Binding var isPresented: Bool
    
    @AppStorage("storeName") private var storeName: String = "Your Store Name"
    @State private var logoData: Data? = UserDefaults.standard.data(forKey: "storeLogo")
    
    var body: some View {
        Form {
            // MARK: - Store Brand Card
            Section {
                NavigationLink(destination: StoreProfileView()) {
                    HStack(spacing: 16) {
                        if let data = logoData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
                        } else {
                            Image(systemName: "storefront.circle.fill")
                                .resizable()
                                .frame(width: 64, height: 64)
                                .foregroundColor(Color(UIColor.systemGray4))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(storeName.isEmpty ? "Your Store Name" : storeName)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("View and edit store profile")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // MARK: - Management
            Section(header: Text("Management")) {
                NavigationLink(destination: InventoryManagerView()) {
                    Label("Inventory Manager", systemImage: "shippingbox")
                }
                
                NavigationLink(destination: TagManagerView()) {
                    Label("Tag Manager", systemImage: "tag")
                }
            }
            
            // MARK: - Directory
            Section(header: Text("Directory")) {
                NavigationLink(destination: CustomerListView()) {
                    Label("Customer Directory", systemImage: "person.2")
                }
                
                NavigationLink(destination: EmployeeManagementView()) {
                    Label("Employee Directory", systemImage: "person.crop.square")
                }
            }
            
            // MARK: - Business Operations
            Section(header: Text("Business Operations")) {
                NavigationLink(destination: OrderListView()) {
                    Label("Order Directory", systemImage: "list.clipboard")
                }
                
                NavigationLink(destination: GlobalReportsView()) {
                    Label("Reports", systemImage: "chart.bar")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { isPresented = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Store")
                    }
                }
            }
        }
        .onAppear {
            // Refreshes the logo on the main screen if you changed it inside the profile
            logoData = UserDefaults.standard.data(forKey: "storeLogo")
        }
    }
}

// MARK: - Subview: Detailed Store Profile
struct StoreProfileView: View {
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
    
    @State private var tempName: String = ""
    @State private var tempEmail: String = ""
    @State private var tempPhone: String = ""
    @State private var tempAddress: String = ""
    @State private var tempWebsite: String = ""
    
    @State private var tempReceiptThankYou: String = ""
    @State private var tempReceiptReturnPolicy: String = ""
    @State private var tempShowLogo: Bool = true
    @State private var tempShowAddress: Bool = true
    @State private var tempShowWebsite: Bool = true
    @State private var tempShowEmployee: Bool = true
    
    @State private var isEditing = false
    @State private var copiedField: String? = nil
    @State private var logoData: Data? = UserDefaults.standard.data(forKey: "storeLogo")
    
    @State private var isShowingPhotoOptions = false
    @State private var isShowingImagePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            // MARK: - Store Brand
            Section {
                VStack(spacing: 16) {
                    Button(action: {
                        if isEditing { isShowingPhotoOptions = true }
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
                            
                            if isEditing {
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
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                    
                    if isEditing {
                        TextField("Simple Store Name", text: $tempName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 10)
                    } else {
                        Text(storeName.isEmpty ? "Your Store Name" : storeName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .foregroundColor(storeName.isEmpty ? .secondary : .primary)
                            .padding(.bottom, 10)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            // MARK: - Store Information
            Section(header: Text("Store Information")) {
                
                // EMAIL
                if isEditing {
                    HStack {
                        Label("Email", systemImage: "envelope.fill").foregroundColor(.blue)
                        Spacer()
                        TextField("Email Address", text: $tempEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing)
                    }
                } else {
                    Button(action: {
                        UIPasteboard.general.string = storeEmail
                        withAnimation { copiedField = "Email" }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { if copiedField == "Email" { copiedField = nil } }
                        }
                    }) {
                        LabeledContent {
                            if copiedField == "Email" {
                                Text("Copied!").foregroundColor(.green).transition(.opacity)
                            } else {
                                Text(storeEmail.isEmpty ? "Not set" : storeEmail)
                                    .foregroundColor(storeEmail.isEmpty ? .secondary : .primary)
                                    .multilineTextAlignment(.trailing)
                            }
                        } label: {
                            Label("Email", systemImage: "envelope.fill").foregroundColor(.blue)
                        }
                    }
                    .disabled(storeEmail.isEmpty)
                    .buttonStyle(.plain)
                }
                
                // PHONE
                if isEditing {
                    HStack {
                        Label("Phone", systemImage: "phone.fill").foregroundColor(.blue)
                        Spacer()
                        TextField("Phone Number", text: $tempPhone)
                            .keyboardType(.phonePad)
                            .multilineTextAlignment(.trailing)
                    }
                } else {
                    Button(action: {
                        UIPasteboard.general.string = storePhone
                        withAnimation { copiedField = "Phone" }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { if copiedField == "Phone" { copiedField = nil } }
                        }
                    }) {
                        LabeledContent {
                            if copiedField == "Phone" {
                                Text("Copied!").foregroundColor(.green).transition(.opacity)
                            } else {
                                Text(storePhone.isEmpty ? "Not set" : storePhone)
                                    .foregroundColor(storePhone.isEmpty ? .secondary : .primary)
                                    .multilineTextAlignment(.trailing)
                            }
                        } label: {
                            Label("Phone", systemImage: "phone.fill").foregroundColor(.blue)
                        }
                    }
                    .disabled(storePhone.isEmpty)
                    .buttonStyle(.plain)
                }
                
                // ADDRESS
                if isEditing {
                    HStack(alignment: .top) {
                        Label("Address", systemImage: "mappin.and.ellipse").foregroundColor(.blue)
                        Spacer()
                        TextField("Physical Address", text: $tempAddress, axis: .vertical)
                            .lineLimit(3...6)
                            .multilineTextAlignment(.trailing)
                    }
                } else {
                    LabeledContent {
                        Text(storeAddress.isEmpty ? "Not set" : storeAddress)
                            .foregroundColor(storeAddress.isEmpty ? .secondary : .primary)
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                    } label: {
                        Label("Address", systemImage: "mappin.and.ellipse").foregroundColor(.blue)
                    }
                }
                
                // WEBSITE
                if isEditing {
                    HStack {
                        Label("Website", systemImage: "link").foregroundColor(.blue)
                        Spacer()
                        TextField("Website Link", text: $tempWebsite)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing)
                    }
                } else {
                    if storeWebsite.isEmpty {
                        LabeledContent {
                            Text("Not set").foregroundColor(.secondary)
                        } label: {
                            Label("Website", systemImage: "link").foregroundColor(.blue)
                        }
                    } else {
                        let urlString = storeWebsite.lowercased().hasPrefix("http") ? storeWebsite : "https://\(storeWebsite)"
                        if let url = URL(string: urlString) {
                            Link(destination: url) {
                                LabeledContent {
                                    Text(storeWebsite)
                                        .multilineTextAlignment(.trailing)
                                        .foregroundColor(.blue)
                                } label: {
                                    Label("Website", systemImage: "link").foregroundColor(.blue)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            // MARK: - Receipt Configuration
            if isEditing {
                Section(
                    header: Text("Custom Messaging"),
                    footer: Text("This text will appear at the top and bottom of your generated PDF receipts.")
                ) {
                    VStack(alignment: .leading) {
                        Text("Header Message")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g. Thank you for your business!", text: $tempReceiptThankYou, axis: .vertical)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Footer / Policy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g. No returns on opened items.", text: $tempReceiptReturnPolicy, axis: .vertical)
                    }
                }
                
                Section(
                    header: Text("Layout & Visibility"),
                    footer: Text("Toggle which parts of your Store Profile are included on the receipt.")
                ) {
                    Toggle("Show Store Logo", isOn: $tempShowLogo)
                    Toggle("Show Physical Address", isOn: $tempShowAddress)
                    Toggle("Show Website Link", isOn: $tempShowWebsite)
                    Toggle("Show \"Served By\" Name", isOn: $tempShowEmployee)
                }
            }
        }
        .navigationTitle("Store Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isEditing)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: cancelEdits) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Cancel")
                        }
                    }
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    if isEditing { saveEdits() } else { startEditing() }
                }) {
                    Image(systemName: isEditing ? "checkmark" : "pencil")
                        .fontWeight(.bold)
                }
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
    
    // MARK: - Actions
    private func startEditing() {
        tempName = storeName; tempEmail = storeEmail; tempPhone = storePhone; tempAddress = storeAddress; tempWebsite = storeWebsite
        tempReceiptThankYou = receiptThankYou; tempReceiptReturnPolicy = receiptReturnPolicy
        tempShowLogo = showLogoOnReceipt; tempShowAddress = showAddressOnReceipt
        tempShowWebsite = showWebsiteOnReceipt; tempShowEmployee = showEmployeeOnReceipt
        withAnimation(.easeInOut(duration: 0.2)) { isEditing = true }
    }
    
    private func saveEdits() {
        storeName = tempName; storeEmail = tempEmail; storeAddress = tempAddress; storeWebsite = tempWebsite; storePhone = tempPhone.formattedAsPhoneNumber()
        receiptThankYou = tempReceiptThankYou; receiptReturnPolicy = tempReceiptReturnPolicy
        showLogoOnReceipt = tempShowLogo; showAddressOnReceipt = tempShowAddress
        showWebsiteOnReceipt = tempShowWebsite; showEmployeeOnReceipt = tempShowEmployee
        
        if let logoData { UserDefaults.standard.set(logoData, forKey: "storeLogo") } else { UserDefaults.standard.removeObject(forKey: "storeLogo") }
        withAnimation(.easeInOut(duration: 0.2)) { isEditing = false }
    }
    
    private func cancelEdits() {
        logoData = UserDefaults.standard.data(forKey: "storeLogo")
        withAnimation(.easeInOut(duration: 0.2)) { isEditing = false }
    }
}
