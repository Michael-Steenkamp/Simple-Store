//
//  NetworkMonitor.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-08-11.
//

import Foundation
import Network
import SwiftUI

@Observable
@MainActor
final class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")
    
    var isConnected: Bool = true
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            // 1. Capture the boolean safely on the background thread
            let isSatisfied = path.status == .satisfied
            
            // 2. Await the isolated MainActor function to safely pass the value
            Task {
                await self?.updateConnectionStatus(isSatisfied)
            }
        }
        monitor.start(queue: queue)
    }
    
    // 3. This function safely executes strictly on the MainActor
    private func updateConnectionStatus(_ status: Bool) {
        self.isConnected = status
    }
}
