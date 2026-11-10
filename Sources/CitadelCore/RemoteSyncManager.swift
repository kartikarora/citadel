import Foundation

public struct RemoteSyncStatus: Sendable {
    public let remoteURL: String?
    public let currentBranch: String
    public let isConfigured: Bool
    public let hasUncommittedChanges: Bool
    public let aheadCount: Int
    public let behindCount: Int
    
    public init(remoteURL: String?, currentBranch: String = "main", isConfigured: Bool, hasUncommittedChanges: Bool, aheadCount: Int = 0, behindCount: Int = 0) {
        self.remoteURL = remoteURL
        self.currentBranch = currentBranch
        self.isConfigured = isConfigured
        self.hasUncommittedChanges = hasUncommittedChanges
        self.aheadCount = aheadCount
        self.behindCount = behindCount
    }
}

public final class RemoteSyncManager: @unchecked Sendable {
    public static let shared = RemoteSyncManager()
    
    private let hub = HubManager.shared
    
    /// Gets current remote origin URL if configured
    public func getRemoteURL(remote: String = "origin") -> String? {
        let res = runGit(["remote", "get-url", remote])
        guard res.exitCode == 0 else { return nil }
        let trimmed = res.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    /// Sets or updates the remote origin URL
    public func setRemoteURL(_ urlString: String, remote: String = "origin") -> (success: Bool, error: String?) {
        if getRemoteURL(remote: remote) != nil {
            let res = runGit(["remote", "set-url", remote, urlString])
            return (res.exitCode == 0, res.exitCode == 0 ? nil : res.output)
        } else {
            let res = runGit(["remote", "add", remote, urlString])
            return (res.exitCode == 0, res.exitCode == 0 ? nil : res.output)
        }
    }
    
    /// Gets detailed remote sync status
    public func getStatus() -> RemoteSyncStatus {
        let rawRemote = getRemoteURL()
        let remote = rawRemote.map { GitAuthProvider.shared.sanitizedRemoteURL($0) }
        let statusRes = runGit(["status", "-s"]).output.trimmingCharacters(in: .whitespacesAndNewlines)
        let branchRes = runGit(["branch", "--show-current"]).output.trimmingCharacters(in: .whitespacesAndNewlines)
        let branch = branchRes.isEmpty ? "main" : branchRes
        
        return RemoteSyncStatus(
            remoteURL: remote,
            currentBranch: branch,
            isConfigured: remote != nil,
            hasUncommittedChanges: !statusRes.isEmpty
        )
    }
    
    // MARK: - Sync Manifest & Marker
    
    public struct SyncMarker: Codable, Sendable {
        public let syncStoreId: String
        public let app: String
        public let version: String
        public let schemaVersion: Int
        public let createdAt: Date?
        public let lastSyncedAt: Date
        public let deviceUsername: String
        public let botEmail: String
        
        public init(
            syncStoreId: String = UUID().uuidString.lowercased(),
            app: String = "Citadel",
            version: String = "1.0.0",
            schemaVersion: Int = 1,
            createdAt: Date? = nil,
            lastSyncedAt: Date = Date(),
            deviceUsername: String = CitadelConstants.Git.deviceUsername,
            botEmail: String = CitadelConstants.Git.botEmail
        ) {
            self.syncStoreId = syncStoreId
            self.app = app
            self.version = version
            self.schemaVersion = schemaVersion
            self.createdAt = createdAt ?? Date()
            self.lastSyncedAt = lastSyncedAt
            self.deviceUsername = deviceUsername
            self.botEmail = botEmail
        }
    }
    
    /// Writes or updates the .citadel-sync-manifest.json marker file into the hub
    @discardableResult
    public func writeSyncMarker(marker: SyncMarker? = nil) -> Bool {
        let existing = readSyncMarker()
        let resolvedStoreId = marker?.syncStoreId ?? existing?.syncStoreId ?? UUID().uuidString.lowercased()
        let resolvedCreatedAt = existing?.createdAt ?? marker?.createdAt ?? Date()
        
        let finalMarker = marker ?? SyncMarker(
            syncStoreId: resolvedStoreId,
            createdAt: resolvedCreatedAt,
            lastSyncedAt: Date()
        )
        
        let file = hub.hubURL.appendingPathComponent(CitadelConstants.Paths.syncMarkerFile)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(finalMarker)
            try data.write(to: file)
            return true
        } catch {
            return false
        }
    }
    
    /// Reads the local sync marker if present
    public func readSyncMarker() -> SyncMarker? {
        let file = hub.hubURL.appendingPathComponent(CitadelConstants.Paths.syncMarkerFile)
        guard FileManager.default.fileExists(atPath: file.path),
              let data = try? Data(contentsOf: file) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SyncMarker.self, from: data)
    }

    /// Pushes local Citadel hub to remote git
    public func push(remote: String = "origin", branch: String = "main") -> (success: Bool, message: String) {
        guard getRemoteURL(remote: remote) != nil else {
            return (false, "No remote Git URL configured. Set one with 'ctdl remote set <url>'")
        }
        writeSyncMarker()
        _ = hub.gitCommit(message: "chore(sync): snapshot armory and portal links")
        let res = runGit(["push", "-u", remote, branch])
        return (res.exitCode == 0, res.output.isEmpty ? "Pushed to \(remote)/\(branch)" : res.output)
    }
    
    /// Pulls remote updates and re-syncs all AI tools
    public func pull(remote: String = "origin", branch: String = "main") throws -> (success: Bool, message: String) {
        guard getRemoteURL(remote: remote) != nil else {
            return (false, "No remote Git URL configured. Set one with 'ctdl remote set <url>'")
        }
        let res = runGit(["pull", "--rebase", remote, branch])
        guard res.exitCode == 0 else {
            return (false, "Pull failed: \(res.output)")
        }
        // Immediately re-sync tools on pull
        _ = try SyncEngine.shared.syncAll()
        return (true, "Successfully pulled and re-synchronized multiverse.")
    }
    
    private func runGit(_ args: [String]) -> (exitCode: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", hub.hubURL.path] + args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus, out)
        } catch {
            return (-1, error.localizedDescription)
        }
    }
}

