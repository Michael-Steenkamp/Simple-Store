//
//  SimpleStoreApp.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-07-18.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct SimpleStoreApp: App {
    // MARK: - Global State Managers
    
    @State private var syncManager = SyncManager()
    
    /// Controls the application session, user profile, and entitlement access.
    @State private var sessionManager = SessionManager()
    
    /// Handles point-of-sale active cart state.
    @State private var cartManager = CartManager()
    
    // MARK: - Local Data Container
    
    let sharedContainer: ModelContainer
    
    init() {
        // 1. Initialize the Firebase backend for hybrid synchronization and auth
        FirebaseApp.configure()
        
        // 2. Initialize the local SwiftData container for offline-first POS operations
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
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            // The LaunchRouterView replaces the static SplashScreenView
            // to dynamically handle onboarding, authentication, and role-based routing.
            LaunchRouterView()
                .environment(sessionManager)
                .environment(syncManager)
                .environment(cartManager)
        }
        // Attach the local POS database to the SwiftUI environment
        .modelContainer(sharedContainer)
    }
}
