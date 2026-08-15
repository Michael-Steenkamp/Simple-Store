//
//  EmployeeSelectionView.swift
//  Simple Store
//

import SwiftUI
import SwiftData

/// Provides a searchable interface to associate a staff member as the transaction server or internal buyer.
struct EmployeeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Employee.name) private var allEmployees: [Employee]
    
    @Binding var selectedEmployee: Employee?
    @State private var searchText = ""
    
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
        NavigationStack {
            List {
                Button {
                    selectedEmployee = nil
                    dismiss()
                } label: {
                    Text("None / Self-Checkout")
                        .foregroundStyle(.red)
                        .italic()
                }
                
                ForEach(filteredEmployees) { employee in
                    Button {
                        selectedEmployee = employee
                        dismiss()
                    } label: {
                        HStack {
                            Text(employee.name)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            if selectedEmployee == employee {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Cashier")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search employees...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
