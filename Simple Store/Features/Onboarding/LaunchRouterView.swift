//
//  LaunchRouterView.swift
//  Simple Store
//

import SwiftUI

/// The root router view responsible for directing the user to the appropriate screen based on authentication and active workspace state.
struct LaunchRouterView: View {
    
    // MARK: - Environment
    
    @Environment(SessionManager.self) private var session
    @Environment(SyncManager.self) private var syncManager
    
    // MARK: - State
    
    /// Controls the global visibility of the splash screen (only true on initial cold boot).
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            // MARK: - Main Application Content
            if let user = session.currentUser {
                if user.activeStoreId == nil {
                    if user.storeIds.isEmpty {
                        StoreSelectionView()
                    } else {
                        MyStoresView(isPresentedFromProfile: false)
                    }
                } else {
                    StorefrontView()
                        .id(user.activeStoreId)
                        .transition(.opacity)
                }
            } else {
                AuthenticationView()
            }
            
            // MARK: - Global Splash Screen Overlay
            if showSplash {
                SplashScreenView(isPresented: $showSplash)
                    .zIndex(2)
                    .transition(.opacity)
            }
        }
        // MARK: - State-Driven View Transitions
        // Triggers a smooth crossfade whenever the active workspace context changes.
        .animation(.easeInOut(duration: 0.4), value: session.currentUser?.activeStoreId)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(session.isLoading || showSplash ? "Loading Application" : "Simple Store Application")
        .task {
            // Initial App Launch Sequence
            try? await Task.sleep(for: .seconds(1.5))
            
            while session.isLoading {
                try? await Task.sleep(for: .milliseconds(100))
            }
            
            withAnimation(.easeInOut(duration: 0.5)) {
                showSplash = false
            }
        }
    }
}
