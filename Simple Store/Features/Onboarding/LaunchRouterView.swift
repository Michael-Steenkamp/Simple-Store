//
//  LaunchRouterView.swift
//  Simple Store
//

import SwiftUI

/// The root routing component responsible for directing the user to the appropriate screen.
///
/// `LaunchRouterView` monitors the `SessionManager`'s authentication and multi-tenant workspace state
/// to seamlessly transition between the authentication flow, tenant selection, and the active storefront.
struct LaunchRouterView: View {
    
    // MARK: - Environment
    
    @Environment(SessionManager.self) private var session
    @Environment(SyncManager.self) private var syncManager
    
    // MARK: - State
    
    /// Controls the global visibility of the splash screen (only `true` on the initial cold boot).
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            // MARK: - Main Application Content
            if let user = session.currentUser {
                if user.activeStoreId == nil {
                    // Route to tenant onboarding or tenant selection based on existing affiliations
                    if user.storeIds.isEmpty {
                        StoreSelectionView()
                    } else {
                        MyStoresView(isPresentedFromProfile: false)
                    }
                } else {
                    // Route directly into the active multi-tenant workspace
                    StorefrontView()
                        .id(user.activeStoreId)
                        .transition(.opacity)
                }
            } else {
                // Route to authentication if no valid session exists
                AuthenticationView()
            }
            
            // MARK: - Global Splash Screen Overlay
            if showSplash {
                SplashScreenView(isPresented: $showSplash)
                    .zIndex(2)
                    .transition(.opacity)
            }
        }
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
