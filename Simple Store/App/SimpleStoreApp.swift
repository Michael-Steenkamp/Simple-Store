//
//  SimpleStoreApp.swift
//  Simple Store
//

import SwiftUI
import SwiftData
import FirebaseCore

/// The main entry point for the Simple Store application.
@main
struct SimpleStoreApp: App {
    
    // MARK: - Global State Managers
    
    /// Handles background synchronization between local SwiftData and remote Firebase Firestore.
    @State private var syncManager = SyncManager()
    
    /// Controls the application session, user profile, and entitlement access.
    @State private var sessionManager = SessionManager()
    
    /// Handles point-of-sale active cart state.
    @State private var cartManager = CartManager()
    
    // MARK: - Local Data Container
    
    /// The shared SwiftData model container for offline-first operations.
    let sharedContainer: ModelContainer
    
    init() {
        FirebaseApp.configure()
        
        do {
            sharedContainer = try ModelContainer(
                for: StoreItem.self,
                ItemTag.self,
                Customer.self,
                Transaction.self,
                CustomerStatus.self,
                Employee.self
            )
        } catch {
            fatalError("Failed to initialize SwiftData ModelContainer: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            LaunchRouterView()
                .environment(sessionManager)
                .environment(syncManager)
                .environment(cartManager)
        }
        .modelContainer(sharedContainer)
    }
}
