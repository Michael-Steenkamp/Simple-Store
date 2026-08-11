//
//  EmployeeDetailView.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-08-10.
//

import SwiftUI
import SwiftData

struct EmployeeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Environment(SessionManager.self) private var session
    @Environment(SyncManager.self) private var syncManager
    
    let employee: Employee
    
    @State private var isShowingDemoteConfirm = false
    @State private var isShowingArchiveConfirm = false
    @State private var actionError = ""
    
    private var isAdmin: Bool {
        session.currentUser?.role == .admin
    }
    
    var body: some View {
        Form {
            if !actionError.isEmpty {
                Section {
                    Text(actionError)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
            
            Section(header: Text("Employee Information")) {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(employee.name)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("System ID")
                    Spacer()
                    Text(employee.id.uuidString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            // MARK: - Admin Actions
            if isAdmin {
                Section(footer: Text("Demoting will move this user to the Customer Directory and revoke their staff access.")) {
                    Button(action: { isShowingDemoteConfirm = true }) {
                        Text("Demote to Customer")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)
                    }
                }
                
                Section {
                    Button(action: { isShowingArchiveConfirm = true }) {
                        Text("Archive Employee")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .navigationTitle(employee.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Demote to Customer?", isPresented: $isShowingDemoteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Demote", role: .destructive) { demoteEmployee() }
        } message: {
            Text("Are you sure? They will lose access to the inventory manager, settings, and POS checkout.")
        }
        .alert("Archive Employee?", isPresented: $isShowingArchiveConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Archive", role: .destructive) { archiveEmployee() }
        } message: {
            Text("This employee will be hidden from the active directory.")
        }
    }
    
    private func demoteEmployee() {
        actionError = ""
        Task {
            do {
                try await session.demoteEmployeeToCustomer(employeeName: employee.name)
                archiveEmployee() // Soft-delete their employee profile locally
            } catch {
                actionError = error.localizedDescription
            }
        }
    }
    
    private func archiveEmployee() {
        employee.isActive = false
        try? modelContext.save()
        Task { await syncManager.pushEmployeeToCloud(employee) }
        dismiss()
    }
}
