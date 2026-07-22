//
//  EmployeeManagementView.swift
//  Simple Inventory
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
                                archiveEmployee(employee)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
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
            }
        }
        .navigationTitle("Employee Directory")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { isShowingAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingAddSheet) {
            AddEmployeeView()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 40, coordinateSpace: .global)
                .onEnded { value in
                    let w = value.translation.width
                    let h = value.translation.height
                    if h > 120 && abs(w) < 50 {
                        isSearchFocused = true
                    }
                }
        )
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
            .navigationTitle("New Employee").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { let newEmployee = Employee(name: name); modelContext.insert(newEmployee); try? modelContext.save(); dismiss() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
