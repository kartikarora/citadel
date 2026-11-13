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
    
    /// Sets or updates the remote origin URL, or removes it if urlString is empty
    @discardableResult
    public func setRemoteURL(_ urlString: String, remote: String = "origin") -> (success: Bool, error: String?) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return removeRemote(remote: remote)
        }
        // Never persist embedded tokens in ~/.citadel/.git/config
        let cleanURL = GitAuthProvider.shared.sanitizedRemoteURL(trimmed)
        
        if getRemoteURL(remote: remote) != nil {
            let res = runGit(["remote", "set-url", remote, cleanURL])
            return (res.exitCode == 0, res.exitCode == 0 ? nil : res.output)
        } else {
            let res = runGit(["remote", "add", remote, cleanURL])
            return (res.exitCode == 0, res.exitCode == 0 ? nil : res.output)
        }
    }
    
    /// Removes the remote if configured
    @discardableResult
    public func removeRemote(remote: String = "origin") -> (success: Bool, error: String?) {
        guard getRemoteURL(remote: remote) != nil else {
            return (true, nil)
        }
        let res = runGit(["remote", "remove", remote])
        return (res.exitCode == 0, res.exitCode == 0 ? nil : res.output)
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
        guard let rawRemote = getRemoteURL(remote: remote) else {
            return (false, "No remote Git URL configured. Set one with 'ctdl remote set <url>'")
        }
        let cleanRemote = GitAuthProvider.shared.sanitizedRemoteURL(rawRemote)
        if cleanRemote != rawRemote {
            _ = setRemoteURL(cleanRemote, remote: remote)
        }
        writeSyncMarker()
        _ = hub.gitCommit(message: "chore(sync): snapshot armory and portal links")
        let res = runGit(["push", "-u", remote, branch], authenticatedRemoteURL: cleanRemote)
        return (res.exitCode == 0, res.output.isEmpty ? "Pushed to \(remote)/\(branch)" : res.output)
    }
    
    /// Pulls remote updates and re-syncs all AI tools
    public func pull(remote: String = "origin", branch: String = "main") throws -> (success: Bool, message: String) {
        guard let rawRemote = getRemoteURL(remote: remote) else {
            return (false, "No remote Git URL configured. Set one with 'ctdl remote set <url>'")
        }
        let cleanRemote = GitAuthProvider.shared.sanitizedRemoteURL(rawRemote)
        if cleanRemote != rawRemote {
            _ = setRemoteURL(cleanRemote, remote: remote)
        }
        let res = runGit(["pull", "--rebase", remote, branch], authenticatedRemoteURL: cleanRemote)
        guard res.exitCode == 0 else {
            return (false, "Pull failed: \(res.output)")
        }
        // Immediately re-sync tools on pull
        _ = try SyncEngine.shared.syncAll()
        return (true, "Successfully pulled and re-synchronized multiverse.")
    }
    
    private func runGit(_ args: [String], authenticatedRemoteURL: String? = nil) -> (exitCode: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        // Isolate Citadel's git operations from global/system gitconfig, `gh auth git-credential`, and osxkeychain
        process.arguments = [
            "-c", "credential.helper=",
            "-c", "user.name=\(HubManager.botName)",
            "-c", "user.email=\(HubManager.botEmail)",
            "-C", hub.hubURL.path
        ] + args
        var env = ProcessInfo.processInfo.environment
        env["GIT_TERMINAL_PROMPT"] = "0"
        env["GIT_CONFIG_GLOBAL"] = "/dev/null"
        env["GIT_CONFIG_NOSYSTEM"] = "1"

        var askpassScriptURL: URL?
        defer {
            if let script = askpassScriptURL {
                try? FileManager.default.removeItem(at: script)
            }
        }

        if let remoteURL = authenticatedRemoteURL, remoteURL.hasPrefix("https://") {
            let provider: GitProvider? = remoteURL.contains("gitlab.com") ? .gitlab : (remoteURL.contains("github.com") ? .github : nil)
            if let provider = provider, let token = GitAuthProvider.shared.getToken(for: provider) {
                let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("citadel-askpass-\(UUID().uuidString).sh")
                let username = provider == .github ? "x-access-token" : "oauth2"
                let script = """
                #!/bin/sh
                case "$1" in
                  *Username*) printf '%s\\n' "\(username)" ;;
                  *) printf '%s\\n' "$CITADEL_GIT_TOKEN" ;;
                esac
                """
                if (try? script.write(to: scriptURL, atomically: true, encoding: .utf8)) != nil {
                    try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
                    askpassScriptURL = scriptURL
                    env["GIT_ASKPASS"] = scriptURL.path
                    env["CITADEL_GIT_TOKEN"] = token
                }
            }
        }

        process.environment = env
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

