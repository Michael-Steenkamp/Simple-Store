//
//  EmployeeSelectionView.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-20.
//

import SwiftUI
import SwiftData

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
                Button(action: {
                    selectedEmployee = nil
                    dismiss()
                }) {
                    Text("None / Self-Checkout")
                        .foregroundColor(.red)
                        .italic()
                }
                
                ForEach(filteredEmployees) { employee in
                    Button(action: {
                        selectedEmployee = employee
                        dismiss()
                    }) {
                        HStack {
                            Text(employee.name)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedEmployee == employee {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
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
