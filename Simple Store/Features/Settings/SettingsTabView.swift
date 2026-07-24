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
        // MARK: - Right Edge Hotspot (Swipe left to return to Store)
        // Scoped HERE so it doesn't bleed into sub-views!
        .overlay(alignment: .trailing) {
            Color.clear
                .frame(width: 30) // Only intercepts touches on the very right edge
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            // Ensure it's a confident horizontal swipe left
                            if value.translation.width < -40 && abs(value.translation.height) < 50 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isPresented = false
                                }
                            }
                        }
                )
        }
        .toolbar {
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
    }
}
