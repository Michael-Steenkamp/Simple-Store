//
//  SettingsTabView.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-07-19.
//

import SwiftUI
import SwiftData
import PhotosUI

struct SettingsTabView: View {
    @Binding var isPresented: Bool
    @Environment(SessionManager.self) private var session
    
    @AppStorage("storeName") private var storeName: String = "Your Store Name"
    @State private var logoData: Data? = UserDefaults.standard.data(forKey: "storeLogo")
    @State private var isShowingUserProfile = false
    
    // Helper to determine if the user is staff (Admin or Employee)
    private var isStaff: Bool {
        let role = session.currentUser?.role
        return role == .admin || role == .employee
    }
    
    var body: some View {
        Form {
            // MARK: - Store Brand Card
            Section {
                if session.currentUser?.role == .admin {
                    NavigationLink(destination: StoreProfileView()) {
                        storeBrandCard
                    }
                } else {
                    storeBrandCard
                }
            }
            
            Section(header: Text("Management")) {
                NavigationLink(destination: InventoryManagerView()) {
                    Label("Inventory Manager", systemImage: "shippingbox")
                }
                
                NavigationLink(destination: TagManagerView()) {
                    Label("Tag Manager", systemImage: "tag")
                }
            }
            
            Section(header: Text("Directory")) {
                NavigationLink(destination: CustomerListView()) {
                    Label("Customer Directory", systemImage: "person.2")
                }
                
                // NEW: Expose Employee Directory to all Staff (Admin & Employee)
                // Since the sub-views already check `isAdmin`, employees will only see a read-only state.
                if isStaff {
                    NavigationLink(destination: EmployeeManagementView()) {
                        Label("Employee Directory", systemImage: "person.crop.square")
                    }
                }
            }
            
            Section(header: Text("Business Operations")) {
                NavigationLink(destination: OrderListView()) {
                    Label("Order Directory", systemImage: "list.clipboard")
                }
                
                // Reports remain strictly Admin-only
                if session.currentUser?.role == .admin {
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
                Button(action: {
                    isShowingUserProfile = true
                }) {
                    Image(systemName: "person.crop.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }) {
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
                    .foregroundColor(Color(UIColor.systemGray4))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(storeName.isEmpty ? "Your Store Name" : storeName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(session.currentUser?.role == .admin ? "View and edit store profile" : "Store Active")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
