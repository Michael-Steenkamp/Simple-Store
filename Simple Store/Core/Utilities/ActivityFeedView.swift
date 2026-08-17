//
//  ActivityFeedView.swift
//  Simple Store
//

import SwiftUI
import SwiftData

/// A chronological timeline displaying workspace telemetry and collaborative actions.
struct ActivityFeedView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncManager.self) private var syncManager
    
    @Query(sort: \ActivityLog.timestamp, order: .reverse) private var logs: [ActivityLog]
    
    var body: some View {
        NavigationStack {
            List {
                if logs.isEmpty {
                    emptyStateView
                } else {
                    ForEach(logs) { log in
                        ActivityLogTemplate(log: log)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !log.isRead {
                                    withAnimation(.snappy) {
                                        log.isRead = true
                                    }
                                    syncManager.markActivityRead(logId: log.id.uuidString)
                                    try? context.save()
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    syncManager.deleteActivityForUser(logId: log.id.uuidString)
                                    context.delete(log)
                                    try? context.save()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                if !log.isRead {
                                    Button {
                                        log.isRead = true
                                        syncManager.markActivityRead(logId: log.id.uuidString)
                                        try? context.save()
                                    } label: {
                                        Label("Read", systemImage: "checkmark.circle")
                                    }
                                    .tint(.blue)
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                if log.isRead {
                                    Button {
                                        log.isRead = false
                                        syncManager.markActivityUnread(logId: log.id.uuidString)
                                        try? context.save()
                                    } label: {
                                        Label("Unread", systemImage: "envelope.badge.fill")
                                    }
                                    .tint(.blue)
                                }
                            }
                    }
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    if logs.contains(where: { !$0.isRead }) {
                        Button("Mark All Read") {
                            let unreadIds = logs.filter { !$0.isRead }.map { $0.id.uuidString }
                            for log in logs where !log.isRead {
                                log.isRead = true
                            }
                            syncManager.markAllActivitiesRead(unreadIds: unreadIds)
                            try? context.save()
                        }
                        .font(.subheadline)
                    }
                    else if !logs.isEmpty {
                        Button("Delete All", role: .destructive) {
                            let logIds = logs.map { $0.id.uuidString }
                            syncManager.deleteAllActivitiesForUser(logIds: logIds)
                            for log in logs {
                                context.delete(log)
                            }
                            try? context.save()
                        }
                        .font(.subheadline)
                    }
                }
            }
            .onDisappear {
                try? context.save()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No recent activity.")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
    }
}

// MARK: - Row Component

struct ActivityLogTemplate: View {
    let log: ActivityLog
    
    var iconName: String {
        switch log.category {
        case "Sales": return "cart.fill"
        case "Inventory": return "shippingbox.fill"
        case "CRM": return "person.2.fill"
        case "System": return "gearshape.fill"
        default: return "bell.fill"
        }
    }
    
    var iconColor: Color {
        switch log.category {
        case "Sales": return .green
        case "Inventory": return .orange
        case "CRM": return .blue
        case "System": return .gray
        default: return .primary
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(log.title)
                        .font(.subheadline)
                        .fontWeight(log.isRead ? .regular : .semibold)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    if !log.isRead {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
                
                HStack {
                    Text(log.category)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(iconColor)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                        .font(.caption2)
                    
                    Text(log.timestamp.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(log.isRead ? 0.7 : 1.0)
    }
}
