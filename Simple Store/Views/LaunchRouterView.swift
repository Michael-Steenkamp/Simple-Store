//
//  LaunchRouterView.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-08-10.
//

import SwiftUI

/// The root view of the application that handles conditional routing.
struct LaunchRouterView: View {
    @Environment(SessionManager.self) private var session
    
    var body: some View {
        Group {
            if session.isLoading {
                SplashScreenView()
            } else if let user = session.currentUser {
                if user.storeId == nil {
                    // User is authenticated but hasn't joined or created a store
                    StoreSelectionView()
                } else {
                    switch user.role {
                    case .admin, .employee:
                        StorefrontView()
                    case .customer, .guest:
                        StorefrontView()
                    }
                }
            } else {
                // Unauthenticated state
                AuthenticationView()
            }
        }
        // Accessibility support for VoiceOver to announce when routing changes
        .accessibilityElement(children: .contain)
        .accessibilityLabel(session.isLoading ? "Loading Application" : "Simple Store Application")
    }
}
