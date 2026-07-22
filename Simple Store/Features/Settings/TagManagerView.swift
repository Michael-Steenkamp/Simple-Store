//
//  TagManagerView.swift
//  Simple Inventory
//
//  Created by Michael Steenkamp on 2026-07-18.
//

import SwiftUI
import SwiftData

struct TagManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \ItemTag.name) private var allTags: [ItemTag]
    @Query(sort: \CustomerStatus.name) private var allStatuses: [CustomerStatus]
    
    @Binding var selectedTags: [ItemTag]
    var isSelectionMode: Bool
    
    @State private var selectedTab = 0
    @State private var newItemName = ""
    
    @State private var tagToDelete: ItemTag? = nil
    @State private var isShowingDeleteTagAlert = false
    
    @State private var statusToDelete: CustomerStatus? = nil
    @State private var isShowingDeleteStatusAlert = false
    
    init(selectedTags: Binding<[ItemTag]> = .constant([]), isSelectionMode: Bool = false) {
        self._selectedTags = selectedTags
        self.isSelectionMode = isSelectionMode
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !isSelectionMode {
                Picker("Category", selection: $selectedTab) {
                    Text("Item Tags").tag(0)
                    Text("Customer Statuses").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color(UIColor.systemGroupedBackground))
            }
            
            List {
                // MARK: - Input Section
                Section(header: Text(selectedTab == 0 ? "Create New Tag" : "Create New Status")) {
                    HStack {
                        TextField(selectedTab == 0 ? "e.g. Sale, New, Clearance..." : "e.g. Regular, VIP, Wholesale...", text: $newItemName)
                            .submitLabel(.done)
                            .onSubmit(addItem)
                        
                        Button(action: addItem) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(newItemName.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
                        }
                        .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .buttonStyle(.borderless)
                    }
                }
                
                // MARK: - Data List
                Section(header: Text(selectedTab == 0 ? "Available Tags" : "Available Statuses")) {
                    if selectedTab == 0 {
                        if allTags.isEmpty {
                            Text("No tags created yet.")
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            ForEach(allTags) { tag in
                                HStack {
                                    if isSelectionMode {
                                        Button(action: { toggleSelection(for: tag) }) {
                                            Image(systemName: selectedTags.contains(tag) ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedTags.contains(tag) ? .blue : .gray)
                                                .font(.title3)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    
                                    TagPillView(name: tag.name)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        tagToDelete = tag
                                        isShowingDeleteTagAlert = true
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red.opacity(0.8))
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } else {
                        if allStatuses.isEmpty {
                            Text("No custom statuses created yet.")
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            ForEach(allStatuses) { status in
                                HStack {
                                    Text(status.name)
                                    Spacer()
                                    Button(action: {
                                        statusToDelete = status
                                        isShowingDeleteStatusAlert = true
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red.opacity(0.8))
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(isSelectionMode ? "Manage Tags" : "Tag & Status Manager")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isSelectionMode {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .alert("Delete Tag", isPresented: $isShowingDeleteTagAlert, presenting: tagToDelete) { tag in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteTag(tag) }
        } message: { tag in
            Text("Are you sure you want to permanently delete '\(tag.name)'? This will remove it from all items.")
        }
        .alert("Delete Status", isPresented: $isShowingDeleteStatusAlert, presenting: statusToDelete) { status in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteStatus(status) }
        } message: { status in
            Text("Are you sure you want to delete '\(status.name)'? This will remove the status from any assigned customers.")
        }
    }
    
    // MARK: - Actions
    
    private func addItem() {
        let trimmedName = newItemName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        if selectedTab == 0 {
            if !allTags.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
                let newTag = ItemTag(name: trimmedName)
                modelContext.insert(newTag)
                if isSelectionMode { selectedTags.append(newTag) }
            }
        } else {
            if !allStatuses.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
                let newStatus = CustomerStatus(name: trimmedName)
                modelContext.insert(newStatus)
            }
        }
        
        try? modelContext.save()
        newItemName = ""
    }
    
    private func toggleSelection(for tag: ItemTag) {
        if let index = selectedTags.firstIndex(of: tag) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
        }
    }
    
    private func deleteTag(_ tag: ItemTag) {
        if let index = selectedTags.firstIndex(of: tag) {
            selectedTags.remove(at: index)
        }
        modelContext.delete(tag)
        try? modelContext.save()
        tagToDelete = nil
    }
    
    private func deleteStatus(_ status: CustomerStatus) {
        modelContext.delete(status)
        try? modelContext.save()
        statusToDelete = nil
    }
}
