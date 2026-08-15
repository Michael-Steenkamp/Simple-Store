//
//  SettingsTabView.swift
//  Simple Store
//

import SwiftUI
import SwiftData

/// The primary navigation hub for administrative configuration, inventory management, and directory access.
struct SettingsTabView: View {
    @Binding var isPresented: Bool
    @Environment(SessionManager.self) private var session
    
    @AppStorage("storeName") private var storeName: String = "Your Store Name"
    @State private var logoData: Data? = UserDefaults.standard.data(forKey: "storeLogo")
    @State private var isShowingUserProfile = false
    
    // MARK: - Role-Based Access Control
    
    private var isStaff: Bool {
        guard let user = session.currentUser, let activeStore = user.activeStoreId else { return false }
        let role = user.storeRoles[activeStore]
        return user.isSystemAdmin || role == "admin" || role == "employee"
    }
    
    private var isAdmin: Bool {
        guard let user = session.currentUser, let activeStore = user.activeStoreId else { return false }
        return user.isSystemAdmin || user.storeRoles[activeStore] == "admin"
    }
    
    var body: some View {
        Form {
            // MARK: - Store Brand Card
            Section {
                if isAdmin {
                    NavigationLink(destination: StoreProfileView()) {
                        storeBrandCard
                    }
                } else {
                    storeBrandCard
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
                
                if isStaff {
                    NavigationLink(destination: EmployeeManagementView()) {
                        Label("Employee Directory", systemImage: "person.crop.square")
                    }
                }
            }
            
            // MARK: - Business Operations
            Section(header: Text("Business Operations")) {
                NavigationLink(destination: OrderListView()) {
                    Label("Order Directory", systemImage: "list.clipboard")
                }
                
                if isAdmin {
                    NavigationLink(destination: GlobalReportsView()) {
                        Label("Reports", systemImage: "chart.bar")
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .trailing) {
            Color.clear
                .frame(width: 30)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            if value.translation.width < -40 && abs(value.translation.height) < 50 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isPresented = false
                                }
                            }
                        }
                )
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isShowingUserProfile = true
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Store")
                        Image(systemName: "chevron.right")
                    }
                }
            }
        }
        .onAppear {
            logoData = UserDefaults.standard.data(forKey: "storeLogo")
        }
        .sheet(isPresented: $isShowingUserProfile) {
            UserProfileView()
        }
    }
    
    private var storeBrandCard: some View {
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
                    .foregroundStyle(Color(uiColor: .systemGray4))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(storeName.isEmpty ? "Your Store Name" : storeName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text(isAdmin ? "View and edit store profile" : "Store Active")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
