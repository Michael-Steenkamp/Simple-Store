//
//  NotificationBellView.swift
//  Simple Store
//

import SwiftUI
import SwiftData

/// A dynamic toolbar button that monitors unread activity logs and triggers the activity feed.
struct NotificationBellView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<ActivityLog> { $0.isRead == false }) private var unreadLogs: [ActivityLog]
    
    @State private var isShowingFeed = false
    
    var body: some View {
        Button {
            isShowingFeed = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.default)
                    .padding(0)
                    .foregroundStyle(.primary)
                
                if !unreadLogs.isEmpty {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundColor(Color.red)
                        .offset(x: 3, y: -3)
                }
            }
        }
        .sheet(isPresented: $isShowingFeed) {
            ActivityFeedView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: unreadLogs.count)
    }
}
