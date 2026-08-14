//
//  EmployeeDetailView.swift
//  Simple Store
//

import SwiftUI
import SwiftData

// MARK: - View Model

@MainActor
@Observable
final class EmployeeDetailViewModel {
    var isShowingDemoteConfirm = false
    var isShowingArchiveConfirm = false
    var actionError = ""
    
    func demoteEmployee(employee: Employee, session: SessionManager, context: ModelContext, syncManager: SyncManager) async -> Bool {
        actionError = ""
        do {
            try await session.demoteEmployeeToCustomer(employeeName: employee.name)
            await archiveEmployee(employee: employee, context: context, syncManager: syncManager)
            return true
        } catch {
            actionError = error.localizedDescription
            return false
        }
    }
    
    func archiveEmployee(employee: Employee, context: ModelContext, syncManager: SyncManager) async {
        employee.isActive = false
        try? context.save()
        await syncManager.pushEmployeeToCloud(employee)
    }
}

// MARK: - View

struct EmployeeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Environment(SessionManager.self) private var session
    @Environment(SyncManager.self) private var syncManager
    
    let employee: Employee
    @State private var viewModel = EmployeeDetailViewModel()
    
    /// Securely verifies administrative capabilities via the multi-tenant `AppUser` model.
    private var isAdmin: Bool {
        guard let user = session.currentUser, let activeStore = user.activeStoreId else { return false }
        return user.isSystemAdmin || user.storeRoles[activeStore] == "admin"
    }
    
    var body: some View {
        Form {
            if !viewModel.actionError.isEmpty {
                Section {
                    Text(viewModel.actionError)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
            
            Section(header: Text("Employee Information")) {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(employee.name)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("System ID")
                    Spacer()
                    Text(employee.id.uuidString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            if isAdmin {
                Section(footer: Text("Demoting will move this user to the Customer Directory and revoke their staff access.")) {
                    Button {
                        viewModel.isShowingDemoteConfirm = true
                    } label: {
                        Text("Demote to Customer")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.orange)
                            .fontWeight(.semibold)
                    }
                }
                
                Section {
                    Button {
                        viewModel.isShowingArchiveConfirm = true
                    } label: {
                        Text("Archive Employee")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle(employee.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Demote to Customer?", isPresented: $viewModel.isShowingDemoteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Demote", role: .destructive) {
                Task {
                    let success = await viewModel.demoteEmployee(employee: employee, session: session, context: modelContext, syncManager: syncManager)
                    if success { dismiss() }
                }
            }
        } message: {
            Text("Are you sure? They will lose access to the inventory manager, settings, and POS checkout.")
        }
        .alert("Archive Employee?", isPresented: $viewModel.isShowingArchiveConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Archive", role: .destructive) {
                Task {
                    await viewModel.archiveEmployee(employee: employee, context: modelContext, syncManager: syncManager)
                    dismiss()
                }
            }
        } message: {
            Text("This employee will be hidden from the active directory.")
        }
    }
}
