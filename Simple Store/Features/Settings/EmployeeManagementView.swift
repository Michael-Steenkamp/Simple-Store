//
//  EmployeeManagementView.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-07-20.
//

import SwiftUI
import SwiftData

struct EmployeeManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncManager.self) private var syncManager
    @Environment(SessionManager.self) private var session
    
    @Query(sort: \Employee.name) private var allEmployees: [Employee]
    
    @State private var searchText = ""
    @State private var isSearchFocused = false
    @State private var isShowingAddSheet = false
    
    @State private var adminNames: [String] = []
    
    private var isAdmin: Bool {
        session.currentUser?.role == .admin
    }
    
    var activeEmployees: [Employee] {
        allEmployees.filter { $0.isActive }
    }
    
    var filteredEmployees: [Employee] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return activeEmployees
        } else {
            return activeEmployees.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var pinnedAdmins: [Employee] {
        filteredEmployees.filter { adminNames.contains($0.name) }
    }
    
    var regularStaff: [Employee] {
        filteredEmployees.filter { !adminNames.contains($0.name) }
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
                                    Button(role: .destructive) { archiveEmployee(admin) } label: { Label("Archive", systemImage: "archivebox") }
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
                                        Button { promoteToAdmin(staff) } label: { Label("Make Admin", systemImage: "star.fill") }
                                        .tint(.yellow)
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) { archiveEmployee(staff) } label: { Label("Archive", systemImage: "archivebox") }
                                }
                            }
                        }
                    }
                }
                .searchable(text: $searchText, isPresented: $isSearchFocused, prompt: "Search employees by name...")
            }
        }
        .navigationTitle("Employee Directory")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    if isAdmin {
                        NavigationLink(destination: ArchivedEmployeesView()) { Image(systemName: "archivebox") }
                        Button(action: { isShowingAddSheet = true }) { Image(systemName: "plus") }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingAddSheet) { AddEmployeeView() }
        .task {
            adminNames = await session.fetchStoreAdminNames()
        }
    }
    
    private func promoteToAdmin(_ employee: Employee) {
        Task {
            do {
                try await session.promoteEmployeeToAdmin(employeeName: employee.name)
                withAnimation { adminNames.append(employee.name) }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    private func archiveEmployee(_ employee: Employee) {
        guard isAdmin else { return }
        employee.isActive = false
        try? modelContext.save()
        Task { await syncManager.pushEmployeeToCloud(employee) }
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
                    .foregroundColor(.yellow)
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
    
    @State private var name: String = ""
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Employee Details"), footer: Text("Employees can be selected during the checkout process to track who made the sale.")) {
                    TextField("Full Name", text: $name).textContentType(.name)
                }
            }
            .navigationTitle("New Employee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newEmployee = Employee(
                            storeId: session.currentUser?.storeId,
                            name: name
                        )
                        modelContext.insert(newEmployee)
                        try? modelContext.save()
                        
                        Task { await syncManager.pushEmployeeToCloud(newEmployee) }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
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
                    .foregroundColor(.secondary)
                    .italic()
                    .listRowBackground(Color.clear)
            } else {
                ForEach(archivedEmployees) { employee in
                    HStack {
                        Text(employee.name)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
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
                    .contextMenu {
                        Button {
                            withAnimation { restoreEmployee(employee) }
                        } label: {
                            Label("Restore Employee", systemImage: "arrow.uturn.backward")
                        }
                        
                        Button(role: .destructive) {
                            withAnimation { permanentlyDelete(employee) }
                        } label: {
                            Label("Delete Forever", systemImage: "trash")
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
