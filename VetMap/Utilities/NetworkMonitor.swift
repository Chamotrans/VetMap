import Network
import SwiftUI

@MainActor
@Observable
final class NetworkMonitor {
    var isConnected = true
    @ObservationIgnored private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: .global())
    }
}
