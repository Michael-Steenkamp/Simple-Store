//
//  EmployeeManagementView.swift
//  Simple Store
//

import SwiftUI
import SwiftData

// MARK: - View Model

@MainActor
@Observable
final class EmployeeManagementViewModel {
    var searchText = ""
    var isSearchFocused = false
    var isShowingAddSheet = false
    var adminNames: [String] = []
    
    var newEmployeeName = ""
    
    func promoteToAdmin(employee: Employee, session: SessionManager) async {
        do {
            try await session.promoteEmployeeToAdmin(employeeName: employee.name)
            withAnimation { adminNames.append(employee.name) }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func archiveEmployee(employee: Employee, context: ModelContext, syncManager: SyncManager) async {
        employee.isActive = false
        try? context.save()
        await syncManager.pushEmployeeToCloud(employee)
    }
    
    func saveNewEmployee(session: SessionManager, context: ModelContext, syncManager: SyncManager) async {
        // Safely resolves the optional storeId to satisfy the strictly typed model init
        let storeId = session.currentUser?.activeStoreId ?? ""
        let newEmployee = Employee(
            id: UUID(),
            storeId: storeId,
            name: newEmployeeName
        )
        context.insert(newEmployee)
        try? context.save()
        await syncManager.pushEmployeeToCloud(newEmployee)
    }
}

// MARK: - View

struct EmployeeManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncManager.self) private var syncManager
    @Environment(SessionManager.self) private var session
    
    @Query(sort: \Employee.name) private var allEmployees: [Employee]
    @State private var viewModel = EmployeeManagementViewModel()
    
    private var isAdmin: Bool {
        guard let user = session.currentUser, let activeStore = user.activeStoreId else { return false }
        return user.isSystemAdmin || user.storeRoles[activeStore] == "admin"
    }
    
    var activeEmployees: [Employee] {
        allEmployees.filter { $0.isActive }
    }
    
    var filteredEmployees: [Employee] {
        if viewModel.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return activeEmployees
        } else {
            return activeEmployees.filter { $0.name.localizedCaseInsensitiveContains(viewModel.searchText) }
        }
    }
    
    var pinnedAdmins: [Employee] {
        filteredEmployees.filter { viewModel.adminNames.contains($0.name) }
    }
    
    var regularStaff: [Employee] {
        filteredEmployees.filter { !viewModel.adminNames.contains($0.name) }
    }
    
    var body: some View {
        Group {
            if activeEmployees.isEmpty {
                ContentUnavailableView("No Employees Yet", systemImage: "lanyardcard")
            } else {
                List {
                    if !pinnedAdmins.isEmpty {
                        Section(header: Text("Administrators")) {
                            ForEach(pinnedAdmins) { admin in
                                NavigationLink(destination: EmployeeDetailView(employee: admin)) {
                                    EmployeeRowView(employee: admin, isPinnedAdmin: true)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if isAdmin {
                                        Button(role: .destructive) {
                                            Task { await viewModel.archiveEmployee(employee: admin, context: modelContext, syncManager: syncManager) }
                                        } label: {
                                            Label("Archive", systemImage: "archivebox")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    if !regularStaff.isEmpty {
                        Section(header: Text("Staff")) {
                            ForEach(regularStaff) { staff in
                                NavigationLink(destination: EmployeeDetailView(employee: staff)) {
                                    EmployeeRowView(employee: staff, isPinnedAdmin: false)
                                }
                                .swipeActions(edge: .leading) {
                                    if isAdmin {
                                        Button {
                                            Task { await viewModel.promoteToAdmin(employee: staff, session: session) }
                                        } label: {
                                            Label("Make Admin", systemImage: "star.fill")
                                        }
                                        .tint(.yellow)
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if isAdmin {
                                        Button(role: .destructive) {
                                            Task { await viewModel.archiveEmployee(employee: staff, context: modelContext, syncManager: syncManager) }
                                        } label: {
                                            Label("Archive", systemImage: "archivebox")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .searchable(text: $viewModel.searchText, isPresented: $viewModel.isSearchFocused, prompt: "Search employees by name...")
            }
        }
        .navigationTitle("Employee Directory")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    if isAdmin {
                        NavigationLink(destination: ArchivedEmployeesView()) { Image(systemName: "archivebox") }
                        Button { viewModel.isShowingAddSheet = true } label: { Image(systemName: "plus") }
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingAddSheet) {
            AddEmployeeView(viewModel: viewModel)
        }
        .task {
            viewModel.adminNames = await session.fetchStoreAdminNames()
        }
    }
}

struct EmployeeRowView: View {
    let employee: Employee
    let isPinnedAdmin: Bool
    
    var body: some View {
        HStack {
            Text(employee.name).font(.headline)
            Spacer()
            if isPinnedAdmin {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Employee Sheet

struct AddEmployeeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session
    @Environment(SyncManager.self) private var syncManager
    
    @Bindable var viewModel: EmployeeManagementViewModel
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Employee Details"), footer: Text("Employees can be selected during the checkout process to track who made the sale.")) {
                    TextField("Full Name", text: $viewModel.newEmployeeName).textContentType(.name)
                }
            }
            .navigationTitle("New Employee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveNewEmployee(session: session, context: modelContext, syncManager: syncManager)
                            viewModel.newEmployeeName = ""
                            dismiss()
                        }
                    }
                    .disabled(viewModel.newEmployeeName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Archived Employees View

struct ArchivedEmployeesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncManager.self) private var syncManager
    
    @Query(sort: \Employee.name) private var allEmployees: [Employee]
    
    var archivedEmployees: [Employee] {
        allEmployees.filter { !$0.isActive }
    }
    
    var body: some View {
        List {
            if archivedEmployees.isEmpty {
                Text("No archived employees.")
                    .foregroundStyle(.secondary)
                    .italic()
                    .listRowBackground(Color.clear)
            } else {
                ForEach(archivedEmployees) { employee in
                    HStack {
                        Text(employee.name)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            withAnimation { restoreEmployee(employee) }
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            withAnimation { permanentlyDelete(employee) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Archived Employees")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func restoreEmployee(_ employee: Employee) {
        employee.isActive = true
        try? modelContext.save()
        Task { await syncManager.pushEmployeeToCloud(employee) }
    }
    
    private func permanentlyDelete(_ employee: Employee) {
        employee.isActive = false
        Task {
            await syncManager.pushEmployeeToCloud(employee)
            modelContext.delete(employee)
            try? modelContext.save()
        }
    }
}
