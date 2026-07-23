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
    
    @Query(sort: \Employee.name) private var allEmployees: [Employee]
    
    @State private var searchText = ""
    @State private var isSearchFocused = false
    @State private var isShowingAddSheet = false
    @State private var isShowingEmployeeId = false
    
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
    
    var body: some View {
        Group {
            if activeEmployees.isEmpty {
                ContentUnavailableView(
                    "No Employees Yet",
                    systemImage: "lanyardcard",
                    description: Text("Add your team members to track who processes each transaction.")
                )
            } else {
                List {
                    ForEach(filteredEmployees) { employee in
                        HStack {
                            Text(employee.name)
                                .font(.headline)
                            
                            Spacer()
                            
                            Button {
                                isShowingEmployeeId = true
                            } label: {
                                Image(systemName: "person.crop.circle")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    archiveEmployee(employee)
                                }
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                        }
                        // Apple Best Practice: Duplicate swipe action in context menu
                        .contextMenu {
                            Button {
                                isShowingEmployeeId = true
                            } label: {
                                Label("View ID", systemImage: "person.crop.circle")
                            }
                            
                            Button(role: .destructive) {
                                withAnimation {
                                    archiveEmployee(employee)
                                }
                            } label: {
                                Label("Archive Employee", systemImage: "archivebox")
                            }
                        }
                        .alert("\(employee.name)'s ID", isPresented: $isShowingEmployeeId) {
                            Button("OK", role: .cancel) {}
                        } message: {
                            Text("\(employee.id)")
                        }
                    }
                }
                .searchable(text: $searchText, isPresented: $isSearchFocused, prompt: "Search employees by name...")
                .sensoryFeedback(.impact(weight: .medium), trigger: activeEmployees.count)
            }
        }
        .navigationTitle("Employee Directory")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    NavigationLink(destination: ArchivedEmployeesView()) {
                        Image(systemName: "archivebox")
                    }
                    
                    Button(action: { isShowingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingAddSheet) {
            AddEmployeeView()
        }
    }
    
    private func archiveEmployee(_ employee: Employee) {
        employee.isActive = false
        try? modelContext.save()
    }
}

// MARK: - Add Employee Sheet
struct AddEmployeeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
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
                        let newEmployee = Employee(name: name)
                        modelContext.insert(newEmployee)
                        try? modelContext.save()
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
                            withAnimation {
                                restoreEmployee(employee)
                            }
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            withAnimation {
                                permanentlyDelete(employee)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    // Apple Best Practice: Context Menu for Archived Items
                    .contextMenu {
                        Button {
                            withAnimation {
                                restoreEmployee(employee)
                            }
                        } label: {
                            Label("Restore Employee", systemImage: "arrow.uturn.backward")
                        }
                        
                        Button(role: .destructive) {
                            withAnimation {
                                permanentlyDelete(employee)
                            }
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
    }
    
    private func permanentlyDelete(_ employee: Employee) {
        modelContext.delete(employee)
        try? modelContext.save()
    }
}
