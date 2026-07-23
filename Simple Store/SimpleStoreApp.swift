//
//  SimpleStoreApp.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-07-18.
//

import SwiftUI
import SwiftData

@main
struct SimpleStoreApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    let sharedContainer: ModelContainer
    
    init() {
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
//            SplashScreenView()
            StorefrontView()
        }
        .modelContainer(sharedContainer)
        .environment(CartManager())
    }
}
