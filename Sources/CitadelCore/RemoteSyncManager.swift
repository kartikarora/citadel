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
    
    private let hub: HubManager

    public init(hub: HubManager = .shared) {
        self.hub = hub
    }
    
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
    
    // MARK: - Two-way Smart Sync

    public struct SmartSyncResult: Sendable {
        public let success: Bool
        public let pulled: Bool
        public let pushed: Bool
        public let conflictStrategy: String?
        public let message: String
        /// True when conflicts were too large to settle by timestamp and the user must resolve them
        public var needsManualResolution: Bool = false
        public var conflictFiles: [String] = []
    }

    /// Reads the sync marker as committed on a given ref (e.g. `origin/main`)
    private func readSyncMarker(atRef ref: String) -> SyncMarker? {
        let res = runGit(["show", "\(ref):\(CitadelConstants.Paths.syncMarkerFile)"])
        guard res.exitCode == 0, let data = res.output.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SyncMarker.self, from: data)
    }

    /// Two-way sync: commits local changes, fetches remote, rebases (resolving conflicts in favour of
    /// whichever side has the newer `lastSyncedAt`), pushes, and re-syncs AI tools when remote changes arrive.
    /// No-op (local only) when no remote is configured.
    public func smartSync(remote: String = "origin", branch: String = "main", resyncTools: Bool = true) -> SmartSyncResult {
        guard let rawRemote = getRemoteURL(remote: remote) else {
            return SmartSyncResult(success: true, pulled: false, pushed: false, conflictStrategy: nil, message: "No remote configured — local sync only.")
        }
        let cleanRemote = GitAuthProvider.shared.sanitizedRemoteURL(rawRemote)
        if cleanRemote != rawRemote {
            _ = setRemoteURL(cleanRemote, remote: remote)
        }

        // Never touch a rebase/merge the user is resolving in their own git client
        if isResolutionInProgress {
            return manualResolutionResult(files: unmergedFiles().map { $0.path },
                                          reason: "A rebase or merge is in progress in ~/.citadel.")
        }

        // 1. Commit local changes (only bump marker when something actually changed)
        let dirty = !runGit(["status", "--porcelain"]).output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if dirty || readSyncMarker() == nil {
            writeSyncMarker()
            _ = hub.gitCommit(message: "chore(sync): snapshot armory and portal links")
        }

        // 2. Fetch
        let fetch = runGit(["fetch", remote], authenticatedRemoteURL: cleanRemote)
        guard fetch.exitCode == 0 else {
            return SmartSyncResult(success: false, pulled: false, pushed: false, conflictStrategy: nil, message: "Fetch failed: \(fetch.output)")
        }

        let remoteRef = "\(remote)/\(branch)"
        let remoteExists = runGit(["rev-parse", "--verify", "--quiet", remoteRef]).exitCode == 0
        let localHasCommits = runGit(["rev-parse", "--verify", "--quiet", "HEAD"]).exitCode == 0

        var ahead = localHasCommits ? 1 : 0
        var behind = 0
        if remoteExists && localHasCommits {
            let counts = runGit(["rev-list", "--left-right", "--count", "HEAD...\(remoteRef)"]).output
                .split(whereSeparator: { $0.isWhitespace }).compactMap { Int($0) }
            if counts.count == 2 { ahead = counts[0]; behind = counts[1] }
        } else if remoteExists {
            behind = 1
        }

        var pulled = false
        var strategy: String?

        // 3. Integrate remote changes
        if behind > 0 {
            if !localHasCommits || ahead == 0 {
                let ff = localHasCommits
                    ? runGit(["merge", "--ff-only", remoteRef])
                    : runGit(["reset", "--hard", remoteRef])
                guard ff.exitCode == 0 else {
                    return SmartSyncResult(success: false, pulled: false, pushed: false, conflictStrategy: nil, message: "Fast-forward failed: \(ff.output)")
                }
            } else if runGit(["merge-base", "HEAD", remoteRef]).exitCode != 0 {
                // Unrelated histories (e.g. first sync of a fresh device against an existing remote):
                // merge, preferring whichever side synced most recently.
                let localDate = readSyncMarker()?.lastSyncedAt ?? .distantPast
                let remoteDate = readSyncMarker(atRef: remoteRef)?.lastSyncedAt ?? .distantPast
                let localWins = localDate >= remoteDate
                strategy = localWins ? "local (newer lastSyncedAt)" : "remote (newer lastSyncedAt)"
                let merge = runGit(["merge", "--allow-unrelated-histories", "--no-edit",
                                    "-X", localWins ? "ours" : "theirs", remoteRef])
                if merge.exitCode != 0 {
                    let files = unmergedFiles().map { $0.path }
                    _ = runGit(["merge", "--abort"])
                    return manualResolutionResult(files: files, reason: "Local and remote histories are unrelated and could not be merged automatically.")
                }
            } else {
                // Diverged from a common base (A → B on remote, A → C locally): rebase local commits
                // onto remote, auto-resolving small "race" conflicts by most recent commit timestamp.
                let outcome = rebaseResolvingRaces(onto: remoteRef)
                switch outcome {
                case .clean:
                    break
                case .resolved(let files):
                    strategy = "newest edit kept for \(files.count) file\(files.count == 1 ? "" : "s"): \(files.joined(separator: ", "))"
                case .needsUser(let files, let reason):
                    return manualResolutionResult(files: files, reason: reason)
                }
            }
            pulled = true
            if resyncTools { _ = try? SyncEngine.shared.syncAll() }
        }

        // 4. Push if we have anything the remote doesn't
        var pushed = false
        let needsPush: Bool = {
            guard runGit(["rev-parse", "--verify", "--quiet", "HEAD"]).exitCode == 0 else { return false }
            guard remoteExists else { return true }
            let out = runGit(["rev-list", "--count", "\(remoteRef)..HEAD"]).output.trimmingCharacters(in: .whitespacesAndNewlines)
            return (Int(out) ?? 0) > 0
        }()
        if needsPush {
            let push = runGit(["push", "-u", remote, "HEAD:\(branch)"], authenticatedRemoteURL: cleanRemote)
            guard push.exitCode == 0 else {
                return SmartSyncResult(success: false, pulled: pulled, pushed: false, conflictStrategy: strategy, message: "Push failed: \(push.output)")
            }
            pushed = true
        }

        let summary: String
        switch (pulled, pushed) {
        case (true, true): summary = "Pulled and pushed changes"
        case (true, false): summary = "Pulled remote changes"
        case (false, true): summary = "Pushed local changes"
        default: summary = "Already up to date"
        }
        return SmartSyncResult(success: true, pulled: pulled, pushed: pushed, conflictStrategy: strategy,
                               message: strategy.map { "\(summary) (conflicts resolved: \($0))" } ?? summary)
    }

    // MARK: - Conflict Handling

    /// Files that may always be auto-resolved by timestamp — they are regenerated by Citadel on every sync.
    private static let autoResolvableMetadataFiles: Set<String> = [
        CitadelConstants.Paths.syncMarkerFile,
        CitadelConstants.Paths.portalsFile,
        CitadelConstants.Paths.configFile
    ]
    /// A conflict larger than this is treated as a real content conflict that needs a human.
    private static let maxAutoResolveHunks = 3
    private static let maxAutoResolveLines = 40

    private enum RebaseOutcome {
        case clean
        case resolved([String])
        case needsUser(files: [String], reason: String)
    }

    private struct UnmergedFile {
        let path: String
        let code: String   // porcelain XY, e.g. "UU", "AA", "UD"
    }

    private var gitDirURL: URL { hub.hubURL.appendingPathComponent(".git") }

    /// True when a rebase or merge is in progress (e.g. the user is resolving conflicts in their git client).
    public var isResolutionInProgress: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: gitDirURL.appendingPathComponent("rebase-merge").path) ||
            fm.fileExists(atPath: gitDirURL.appendingPathComponent("rebase-apply").path) ||
            fm.fileExists(atPath: gitDirURL.appendingPathComponent("MERGE_HEAD").path)
    }

    private func unmergedFiles() -> [UnmergedFile] {
        let codes: Set<String> = ["DD", "AU", "UD", "UA", "DU", "AA", "UU"]
        return runGit(["status", "--porcelain"]).output
            .split(separator: "\n")
            .compactMap { line -> UnmergedFile? in
                let s = String(line)
                guard s.count > 3 else { return nil }
                let code = String(s.prefix(2))
                guard codes.contains(code) else { return nil }
                return UnmergedFile(path: String(s.dropFirst(3)).trimmingCharacters(in: .whitespaces), code: code)
            }
    }

    private func commitTime(_ ref: String, path: String) -> Int {
        Int(runGit(["log", "-1", "--format=%ct", ref, "--", path]).output
            .trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    /// Whether a conflicted file is a small, same-region "race" edit that is safe to settle by timestamp.
    private func isRaceConflict(_ file: UnmergedFile) -> Bool {
        guard file.code == "UU" || file.code == "AA" else { return false }  // delete/rename conflicts need a human
        if Self.autoResolvableMetadataFiles.contains(file.path) { return true }
        let url = hub.hubURL.appendingPathComponent(file.path)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false } // binary
        var hunks = 0
        var conflictLines = 0
        var inside = false
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("<<<<<<<") { hunks += 1; inside = true; continue }
            if line.hasPrefix(">>>>>>>") { inside = false; continue }
            if inside && !line.hasPrefix("=======") { conflictLines += 1 }
        }
        return hunks <= Self.maxAutoResolveHunks && conflictLines <= Self.maxAutoResolveLines
    }

    /// Rebases local commits onto `upstream`. At each conflicting step, if every conflict is a small race,
    /// keeps the side whose last commit to that file is newer; otherwise aborts and hands off to the user.
    private func rebaseResolvingRaces(onto upstream: String) -> RebaseOutcome {
        var rebase = runGit(["rebase", upstream])
        if rebase.exitCode == 0 { return .clean }

        var resolved: [String] = []
        for _ in 0..<100 {
            guard isResolutionInProgress else {
                return .needsUser(files: [], reason: "Rebase failed: \(rebase.output)")
            }
            let conflicts = unmergedFiles()
            if conflicts.isEmpty {
                // Nothing conflicted but the step stopped (e.g. the commit became empty)
                rebase = runGit(["diff", "--cached", "--quiet"]).exitCode == 0
                    ? runGit(["rebase", "--skip"])
                    : runGit(["-c", "core.editor=true", "rebase", "--continue"])
            } else {
                let hard = conflicts.filter { !isRaceConflict($0) }
                if !hard.isEmpty {
                    let files = conflicts.map { $0.path }
                    _ = runGit(["rebase", "--abort"])
                    return .needsUser(files: files, reason: "Local and remote both made substantial changes to the same files.")
                }
                // During rebase: --ours = upstream (remote), --theirs = local commit being replayed
                for file in conflicts {
                    let remoteTime = commitTime(upstream, path: file.path)
                    let localTime = commitTime("REBASE_HEAD", path: file.path)
                    _ = runGit(["checkout", localTime >= remoteTime ? "--theirs" : "--ours", "--", file.path])
                    _ = runGit(["add", "--", file.path])
                    if !resolved.contains(file.path) { resolved.append(file.path) }
                }
                rebase = runGit(["diff", "--cached", "--quiet"]).exitCode == 0
                    ? runGit(["rebase", "--skip"])
                    : runGit(["-c", "core.editor=true", "rebase", "--continue"])
            }
            if rebase.exitCode == 0 && !isResolutionInProgress {
                return resolved.isEmpty ? .clean : .resolved(resolved)
            }
        }
        _ = runGit(["rebase", "--abort"])
        return .needsUser(files: resolved, reason: "Rebase did not converge.")
    }

    private func manualResolutionResult(files: [String], reason: String) -> SmartSyncResult {
        SmartSyncResult(
            success: false, pulled: false, pushed: false, conflictStrategy: nil,
            message: "\(reason) Your local changes are safe and were not pushed. Resolve the conflict in ~/.citadel with your git client (e.g. `git pull --rebase`), then sync again.",
            needsManualResolution: true, conflictFiles: files
        )
    }

    private func runGit(_ args: [String], authenticatedRemoteURL: String? = nil) -> (exitCode: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        // Isolate Citadel's git operations from global/system gitconfig, `gh auth git-credential`, and osxkeychain
        process.arguments = [
            "-c", "credential.helper=",
            "-c", "user.name=\(hub.effectiveCommitName)",
            "-c", "user.email=\(hub.effectiveCommitEmail)",
            "-C", hub.hubURL.path
        ] + args
        var env = ProcessInfo.processInfo.environment
        env["GIT_TERMINAL_PROMPT"] = "0"
        env["GIT_EDITOR"] = "true"
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

