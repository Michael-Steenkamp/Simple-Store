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
    var adminNames: [String] = []
    
    func promoteToAdmin(employee: Employee, session: SessionManager) async {
        do {
            try await session.promoteEmployeeToAdmin(employeeName: employee.name)
            withAnimation { adminNames.append(employee.name) }
        } catch {
            print(error.localizedDescription)
        }
    }
}

// MARK: - View

/// An administrative interface for viewing and managing active staff members.
/// Note: New staff can only be created by promoting an existing Customer profile to an Employee.
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
                            }
                        }
                    }
                }
                .searchable(text: $viewModel.searchText, isPresented: $viewModel.isSearchFocused, prompt: "Search employees by name...")
            }
        }
        .navigationTitle("Employee Directory")
        .task {
            viewModel.adminNames = await session.fetchStoreAdminNames()
        }
    }
}

// MARK: - Row Component

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
