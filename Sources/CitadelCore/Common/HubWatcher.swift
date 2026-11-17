import Foundation

/// Watches ~/.citadel using DispatchSourceFileSystemObject for real-time local changes,
/// and runs periodic background git sync when remote sync is configured.
public final class HubWatcher: @unchecked Sendable {
    public static let shared = HubWatcher()
    
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var debounceWorkItem: DispatchWorkItem?
    private var timer: Timer?
    private let queue = DispatchQueue(label: "sh.citadel.hubwatcher", qos: .utility)
    
    private var isWatching = false
    private let hubURL = HubManager.shared.hubURL
    
    public var onChangeDetected: (@Sendable () -> Void)?
    
    public init() {}
    
    /// Starts watching ~/.citadel for local changes and schedules remote sync checks
    public func start() {
        guard !isWatching else { return }
        isWatching = true
        
        startFSEventMonitor()
        schedulePeriodicRemoteSync()
    }
    
    /// Stops watching ~/.citadel
    public func stop() {
        isWatching = false
        stopFSEventMonitor()
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            self?.timer = nil
        }
    }
    
    private func startFSEventMonitor() {
        let path = hubURL.path
        guard FileManager.default.fileExists(atPath: path) else { return }
        
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .link, .rename, .extend, .attrib],
            queue: queue
        )
        
        source.setEventHandler { [weak self] in
            self?.handleHubDirectoryChange()
        }
        
        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }
        
        source.resume()
        self.dispatchSource = source
    }
    
    private func stopFSEventMonitor() {
        dispatchSource?.cancel()
        dispatchSource = nil
    }
    
    private func handleHubDirectoryChange() {
        // Debounce frequent changes (e.g. multiple skill files written at once)
        debounceWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.onChangeDetected?()
        }
        debounceWorkItem = item
        queue.asyncAfter(deadline: .now() + 1.5, execute: item)
    }
    
    private func schedulePeriodicRemoteSync() {
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            // Check for remote sync updates every 60 seconds if configured
            self?.timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
                self?.queue.async {
                    if RemoteSyncManager.shared.getRemoteURL() != nil {
                        self?.onChangeDetected?()
                    }
                }
            }
        }
    }
}
