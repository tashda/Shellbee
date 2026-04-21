import Foundation
import Network

@Observable
final class Z2MDiscoveryService {
    @MainActor public var discoveredHosts: Set<String> = []
    @MainActor public private(set) var isScanning: Bool = false
    private var browser: NWBrowser?
    private let browserQueue = DispatchQueue(label: "dev.echodb.shellbee.discovery", qos: .userInitiated)
    
    @MainActor
    func start() {
        guard !isScanning else { return }
        isScanning = true
        
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        browser = NWBrowser(for: .bonjour(type: "_http._tcp", domain: "local."), using: parameters)
        
        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            let hosts = results.compactMap { (result: NWBrowser.Result) -> String? in
                if case let .service(name, _, _, _) = result.endpoint {
                    return "\(name).local"
                }
                return nil
            }
            
            // Dispatch to MainActor for state updates
            Task { @MainActor in
                self?.discoveredHosts = Set(hosts)
            }
        }
        
        // Start on background queue to avoid Main Actor lag
        browser?.start(queue: browserQueue)
    }
    
    @MainActor
    func stop() {
        browser?.cancel()
        browser = nil
        isScanning = false
    }
}
