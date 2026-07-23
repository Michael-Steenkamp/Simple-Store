//
//  SettingsTabView.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-19.
//

import SwiftUI
import SwiftData

struct SettingsTabView: View {
    // Replaced binding with standard Environment dismiss
    @Environment(\.dismiss) private var dismiss
    
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
        .navigationBarBackButtonHidden(true) // Hide default back to use custom one below
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Store")
                    }
                }
            }
        }
        .onAppear {
            logoData = UserDefaults.standard.data(forKey: "storeLogo")
        }
    }
}
