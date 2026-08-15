//
//  TagManagerView.swift
//  Simple Store
//

import SwiftUI
import SwiftData

// MARK: - View Model

@MainActor
@Observable
final class TagManagerViewModel {
    var selectedTab = 0
    var newItemName = ""
    
    var tagToDelete: ItemTag? = nil
    var isShowingDeleteTagAlert = false
    
    var statusToDelete: CustomerStatus? = nil
    var isShowingDeleteStatusAlert = false
    
    func addItem(
        allTags: [ItemTag],
        allStatuses: [CustomerStatus],
        session: SessionManager,
        context: ModelContext,
        syncManager: SyncManager,
        isSelectionMode: Bool,
        selectedTags: Binding<[ItemTag]>
    ) {
        let trimmedName = newItemName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        let storeId = session.currentUser?.activeStoreId ?? ""
        
        if selectedTab == 0 {
            if !allTags.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
                let newTag = ItemTag(id: UUID(), storeId: storeId, name: trimmedName)
                context.insert(newTag)
                if isSelectionMode { selectedTags.wrappedValue.append(newTag) }
                syncManager.pushItemTagToCloud(newTag)
            }
        } else {
            if !allStatuses.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
                let newStatus = CustomerStatus(id: UUID(), name: trimmedName, storeId: storeId)
                context.insert(newStatus)
                syncManager.pushCustomerStatusToCloud(newStatus)
            }
        }
        
        try? context.save()
        newItemName = ""
    }
    
    func toggleSelection(for tag: ItemTag, selectedTags: Binding<[ItemTag]>) {
        if let index = selectedTags.wrappedValue.firstIndex(of: tag) {
            selectedTags.wrappedValue.remove(at: index)
        } else {
            selectedTags.wrappedValue.append(tag)
        }
    }
    
    func deleteTag(_ tag: ItemTag, context: ModelContext, syncManager: SyncManager, selectedTags: Binding<[ItemTag]>) {
        if let index = selectedTags.wrappedValue.firstIndex(of: tag) {
            selectedTags.wrappedValue.remove(at: index)
        }
        
        let tagId = tag.id.uuidString
        syncManager.deleteItemTagFromCloud(tagId)
        
        context.delete(tag)
        try? context.save()
        tagToDelete = nil
    }
    
    func deleteStatus(_ status: CustomerStatus, context: ModelContext, syncManager: SyncManager) {
        let statusId = status.id.uuidString
        syncManager.deleteCustomerStatusFromCloud(statusId)
        
        context.delete(status)
        try? context.save()
        statusToDelete = nil
    }
}

// MARK: - View

/// An interface for creating, reviewing, and deleting global categorization tags and customer statuses.
struct TagManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session
    @Environment(SyncManager.self) private var syncManager
    
    @Query(sort: \ItemTag.name) private var allTags: [ItemTag]
    @Query(sort: \CustomerStatus.name) private var allStatuses: [CustomerStatus]
    
    @Binding var selectedTags: [ItemTag]
    var isSelectionMode: Bool
    
    @State private var viewModel = TagManagerViewModel()
    
    init(selectedTags: Binding<[ItemTag]> = .constant([]), isSelectionMode: Bool = false) {
        self._selectedTags = selectedTags
        self.isSelectionMode = isSelectionMode
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !isSelectionMode {
                Picker("Category", selection: $viewModel.selectedTab.animation(.easeInOut)) {
                    Text("Item Tags").tag(0)
                    Text("Customer Statuses").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color(uiColor: .systemGroupedBackground))
            }
            
            List {
                Section(header: Text(viewModel.selectedTab == 0 ? "Create New Tag" : "Create New Status")) {
                    HStack {
                        TextField(viewModel.selectedTab == 0 ? "e.g. Sale, New, Clearance..." : "e.g. Regular, VIP, Wholesale...", text: $viewModel.newItemName)
                            .submitLabel(.done)
                            .onSubmit {
                                withAnimation {
                                    viewModel.addItem(allTags: allTags, allStatuses: allStatuses, session: session, context: modelContext, syncManager: syncManager, isSelectionMode: isSelectionMode, selectedTags: $selectedTags)
                                }
                            }
                        
                        Button {
                            withAnimation {
                                viewModel.addItem(allTags: allTags, allStatuses: allStatuses, session: session, context: modelContext, syncManager: syncManager, isSelectionMode: isSelectionMode, selectedTags: $selectedTags)
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(viewModel.newItemName.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
                        }
                        .disabled(viewModel.newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .buttonStyle(.borderless)
                    }
                }
                
                Section(header: Text(viewModel.selectedTab == 0 ? "Available Tags" : "Available Statuses")) {
                    if viewModel.selectedTab == 0 {
                        if allTags.isEmpty {
                            Text("No tags created yet.")
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            ForEach(allTags) { tag in
                                HStack {
                                    if isSelectionMode {
                                        Button {
                                            withAnimation { viewModel.toggleSelection(for: tag, selectedTags: $selectedTags) }
                                        } label: {
                                            Image(systemName: selectedTags.contains(tag) ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selectedTags.contains(tag) ? .blue : .gray)
                                                .font(.title3)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    
                                    TagPillView(name: tag.name)
                                    
                                    Spacer()
                                    
                                    Button {
                                        viewModel.tagToDelete = tag
                                        viewModel.isShowingDeleteTagAlert = true
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red.opacity(0.8))
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } else {
                        if allStatuses.isEmpty {
                            Text("No custom statuses created yet.")
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            ForEach(allStatuses) { status in
                                HStack {
                                    Text(status.name)
                                    Spacer()
                                    Button {
                                        viewModel.statusToDelete = status
                                        viewModel.isShowingDeleteStatusAlert = true
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red.opacity(0.8))
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }
            }
            .sensoryFeedback(.success, trigger: allTags.count)
            .sensoryFeedback(.success, trigger: allStatuses.count)
            .sensoryFeedback(.selection, trigger: selectedTags.count)
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
        .alert("Delete Tag", isPresented: $viewModel.isShowingDeleteTagAlert, presenting: viewModel.tagToDelete) { tag in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                withAnimation { viewModel.deleteTag(tag, context: modelContext, syncManager: syncManager, selectedTags: $selectedTags) }
            }
        } message: { tag in
            Text("Are you sure you want to permanently delete '\(tag.name)'? This will remove it from all items.")
        }
        .alert("Delete Status", isPresented: $viewModel.isShowingDeleteStatusAlert, presenting: viewModel.statusToDelete) { status in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                withAnimation { viewModel.deleteStatus(status, context: modelContext, syncManager: syncManager) }
            }
        } message: { status in
            Text("Are you sure you want to delete '\(status.name)'? This will remove the status from any assigned customers.")
        }
    }
}
