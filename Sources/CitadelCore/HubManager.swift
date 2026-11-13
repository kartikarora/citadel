import Foundation

public final class HubManager: @unchecked Sendable {
    public static let shared = HubManager()
    
    public let fileManager = FileManager.default
    public let hubURL: URL
    public let skillsURL: URL
    public let mcpsURL: URL
    public let portalsFile: URL
    public let configFile: URL
    public let keysDir: URL
    public let signingKeyFile: URL
    public let signingPubKeyFile: URL
    public let allowedSignersFile: URL
    
    public init(customHubURL: URL? = nil) {
        let base = customHubURL ?? UniversalPaths.shared.citadelHome
        self.hubURL = base
        self.skillsURL = base.appendingPathComponent("skills")
        self.mcpsURL = base.appendingPathComponent("mcps")
        self.portalsFile = base.appendingPathComponent("portals.json")
        self.configFile = base.appendingPathComponent("config.json")
        self.keysDir = base.appendingPathComponent(".keys")
        self.signingKeyFile = keysDir.appendingPathComponent("citadel_signing_key")
        self.signingPubKeyFile = keysDir.appendingPathComponent("citadel_signing_key.pub")
        self.allowedSignersFile = keysDir.appendingPathComponent("allowed_signers")
    }
    
    /// Initializes the central ~/.citadel repository structure and signing identity
    public func initializeHub() throws {
        try fileManager.createDirectory(at: hubURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: skillsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: mcpsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: keysDir, withIntermediateDirectories: true)
        
        if !fileManager.fileExists(atPath: portalsFile.path) {
            let emptyPortals: [ProjectPortal] = []
            let data = try JSONEncoder().encode(emptyPortals)
            try data.write(to: portalsFile)
        }
        
        // Ensure signing key and Git identity exist
        setupSigningKeyAndGitIdentity()
        
        // Generate or refresh standalone rollback script
        RollbackEngine.shared.generateStandaloneRollbackScript(hubURL: hubURL)
        
        // Initialize Git repo if missing
        let gitDir = hubURL.appendingPathComponent(".git")
        if !fileManager.fileExists(atPath: gitDir.path) {
            _ = runGit(["init"])
            let gitignoreFile = hubURL.appendingPathComponent(".gitignore")
            if !fileManager.fileExists(atPath: gitignoreFile.path) {
                try? ".DS_Store\n*.swp\n.env*\n.keys/\n".write(to: gitignoreFile, atomically: true, encoding: .utf8)
            }
            configureGitIdentityAndSigning()
            gitCommit(message: "feat: initialize Citadel hub repository")
        } else {
            configureGitIdentityAndSigning()
        }
    }
    
    // MARK: - Commit Signing & Keychain Key Management
    
    public static var botName: String { CitadelConstants.Git.botName }
    public static var botEmail: String { CitadelConstants.Git.botEmail }
    public static var keychainSigningService: String { CitadelConstants.Keychain.signingService }

    private static let commitEmailDefaultsKey = "citadel.git.verifiedCommitEmail"
    private static let commitNameDefaultsKey = "citadel.git.verifiedCommitName"

    public var effectiveCommitEmail: String {
        let stored = UserDefaults.standard.string(forKey: Self.commitEmailDefaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let stored = stored, !stored.isEmpty {
            return stored
        }
        return Self.botEmail
    }

    public var effectiveCommitName: String {
        let stored = UserDefaults.standard.string(forKey: Self.commitNameDefaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let stored = stored, !stored.isEmpty {
            return stored
        }
        return Self.botName
    }

    /// Updates the local Git commit identity (e.g., to the user's primary verified GitHub email)
    /// and refreshes `allowed_signers` + `.git/config` so commits verify cleanly on GitHub.
    public func updateCommitIdentity(email: String, name: String? = nil) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { return }
        UserDefaults.standard.set(trimmedEmail, forKey: Self.commitEmailDefaultsKey)
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            UserDefaults.standard.set(name, forKey: Self.commitNameDefaultsKey)
        }
        setupSigningKeyAndGitIdentity()
        configureGitIdentityAndSigning()
    }
    
    /// Ensures ed25519 signing key exists in .keys/ and Keychain, and allowed_signers is configured
    public func setupSigningKeyAndGitIdentity() {
        try? fileManager.createDirectory(at: keysDir, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: signingKeyFile.path) {
            // Generate ed25519 SSH signing key pair
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
            proc.arguments = ["-t", "ed25519", "-N", "", "-f", signingKeyFile.path, "-C", Self.botEmail]
            try? proc.run()
            proc.waitUntilExit()
            
            if let privKey = try? String(contentsOf: signingKeyFile, encoding: .utf8) {
                saveSigningKeyToKeychain(privKey)
            }
        }
        
        // Generate or verify public key
        if !fileManager.fileExists(atPath: signingPubKeyFile.path) && fileManager.fileExists(atPath: signingKeyFile.path) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
            proc.arguments = ["-y", "-f", signingKeyFile.path]
            let pipe = Pipe()
            proc.standardOutput = pipe
            try? proc.run()
            proc.waitUntilExit()
            let pubData = pipe.fileHandleForReading.readDataToEndOfFile()
            if let pubStr = String(data: pubData, encoding: .utf8), !pubStr.isEmpty {
                try? pubStr.write(to: signingPubKeyFile, atomically: true, encoding: .utf8)
            }
        }
        
        // Configure allowed_signers file
        if let pubKey = try? String(contentsOf: signingPubKeyFile, encoding: .utf8) {
            let trimmed = pubKey.trimmingCharacters(in: .whitespacesAndNewlines)
            var lines = ["\(effectiveCommitEmail) \(trimmed)"]
            if effectiveCommitEmail != Self.botEmail {
                lines.append("\(Self.botEmail) \(trimmed)")
            }
            let allowedContent = lines.joined(separator: "\n") + "\n"
            try? allowedContent.write(to: allowedSignersFile, atomically: true, encoding: .utf8)
        }
    }
    
    public func configureGitIdentityAndSigning() {
        _ = runGit(["config", "user.name", effectiveCommitName])
        _ = runGit(["config", "user.email", effectiveCommitEmail])
        _ = runGit(["config", "gpg.format", "ssh"])
        _ = runGit(["config", "user.signingkey", signingPubKeyFile.path])
        _ = runGit(["config", "commit.gpgsign", "true"])
        if fileManager.fileExists(atPath: allowedSignersFile.path) {
            _ = runGit(["config", "gpg.ssh.allowedSignersFile", allowedSignersFile.path])
        }
    }
    
    private func saveSigningKeyToKeychain(_ key: String) {
        _ = CitadelUtils.saveKeychainSecret(
            service: Self.keychainSigningService,
            account: Self.botEmail,
            value: key
        )
    }
    
    private func loadSigningKeyFromKeychain() -> String? {
        return CitadelUtils.loadKeychainSecret(
            service: Self.keychainSigningService,
            account: Self.botEmail
        )
    }
    
    // MARK: - Git Sync Operations
    
    @discardableResult
    public func gitCommit(message: String) -> Bool {
        // Don't commit while the user is resolving a rebase/merge in their git client
        let gitDir = hubURL.appendingPathComponent(".git")
        for marker in ["rebase-merge", "rebase-apply", "MERGE_HEAD"] where fileManager.fileExists(atPath: gitDir.appendingPathComponent(marker).path) {
            return false
        }
        _ = runGit(["add", "."])
        var commitArgs = ["commit"]
        if FeatureFlags.shared.commitSigningEnabled {
            commitArgs.append("-S")
        }
        commitArgs.append("--author=\(effectiveCommitName) <\(effectiveCommitEmail)>")
        commitArgs.append("-m")
        commitArgs.append(message)
        let res = runGit(commitArgs)
        return res.exitCode == 0
    }
    
    public func gitPush(remote: String = "origin", branch: String = "main") -> (success: Bool, output: String) {
        let res = RemoteSyncManager.shared.push(remote: remote, branch: branch)
        return (res.success, res.message)
    }
    
    public func gitPull(remote: String = "origin", branch: String = "main") -> (success: Bool, output: String) {
        do {
            let res = try RemoteSyncManager.shared.pull(remote: remote, branch: branch)
            return (res.success, res.message)
        } catch {
            return (false, error.localizedDescription)
        }
    }
    
    public func gitStatus() -> String {
        return runGit(["status", "-s"]).output
    }
    
    private func runGit(_ args: [String]) -> (exitCode: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = [
            "-c", "credential.helper=",
            "-c", "user.name=\(effectiveCommitName)",
            "-c", "user.email=\(effectiveCommitEmail)",
            "-C", hubURL.path
        ] + args
        var env = ProcessInfo.processInfo.environment
        env["GIT_TERMINAL_PROMPT"] = "0"
        env["GIT_CONFIG_GLOBAL"] = "/dev/null"
        env["GIT_CONFIG_NOSYSTEM"] = "1"
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
    
    /// Scans ~/.citadel/skills for all available central skills
    public func listArmorySkills() -> [Skill] {
        guard fileManager.fileExists(atPath: skillsURL.path) else { return [] }
        guard let entries = try? fileManager.contentsOfDirectory(at: skillsURL, includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey]) else {
            return []
        }
        
        var results: [Skill] = []
        for entry in entries {
            let name = entry.lastPathComponent
            if name.hasPrefix(".") { continue }
            
            // Check for SKILL.md or metadata
            let skillFile = entry.appendingPathComponent("SKILL.md")
            var meta = ParsedSkillMeta()
            if fileManager.fileExists(atPath: skillFile.path),
               let content = try? String(contentsOf: skillFile, encoding: .utf8) {
                meta = parseSkillFrontmatter(from: content)
            }
            
            let isLink = (try? entry.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false
            results.append(Skill(
                name: meta.name ?? name,
                path: entry,
                description: meta.description,
                isSymlink: isLink,
                version: meta.version,
                author: meta.author,
                argumentHint: meta.argumentHint,
                icon: meta.icon
            ))
        }
        
        return results.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
    
    /// Scans ~/.citadel/mcps for all registered canonical MCP definitions
    public func listArmoryMCPs() -> [MCPServer] {
        guard fileManager.fileExists(atPath: mcpsURL.path) else { return [] }
        guard let files = try? fileManager.contentsOfDirectory(at: mcpsURL, includingPropertiesForKeys: nil) else {
            return []
        }
        
        var results: [MCPServer] = []
        let decoder = JSONDecoder()
        
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let server = try? decoder.decode(MCPServer.self, from: data) {
                results.append(server)
            }
        }
        
        return results.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
    
    /// Saves or updates an MCP server into the Armory
    public func saveMCP(_ server: MCPServer) throws {
        try fileManager.createDirectory(at: mcpsURL, withIntermediateDirectories: true)
        let file = mcpsURL.appendingPathComponent("\(server.name).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(server)
        try data.write(to: file)
    }
    
    /// Reads registered portals
    public func loadPortals() -> [ProjectPortal] {
        guard fileManager.fileExists(atPath: portalsFile.path),
              let data = try? Data(contentsOf: portalsFile),
              let portals = try? JSONDecoder().decode([ProjectPortal].self, from: data) else {
            return []
        }
        return portals
    }
    
    /// Saves registered portals
    public func savePortals(_ portals: [ProjectPortal]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(portals)
        try data.write(to: portalsFile)
    }
    
    // MARK: - Helpers
    public struct ParsedSkillMeta {
        public var name: String? = nil
        public var description: String? = nil
        public var version: String? = nil
        public var author: String? = nil
        public var argumentHint: String? = nil
        public var icon: String? = nil
        
        public init() {}
    }
    
    public func parseSkillFrontmatter(from markdown: String) -> ParsedSkillMeta {
        var meta = ParsedSkillMeta()
        let lines = markdown.components(separatedBy: .newlines)
        
        var inFrontmatter = false
        var frontmatterLines: [String] = []
        var pastFrontmatter = false
        
        for (idx, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if idx == 0 && line == "---" {
                inFrontmatter = true
                continue
            }
            if inFrontmatter {
                if line == "---" {
                    inFrontmatter = false
                    pastFrontmatter = true
                    break
                }
                frontmatterLines.append(rawLine)
            }
        }
        
        if !frontmatterLines.isEmpty {
            for rawLine in frontmatterLines {
                let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
                let cleanVal: (String) -> String = { str in
                    str.trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
                }
                
                if trimmed.starts(with: "name:") {
                    let v = cleanVal(trimmed.replacingOccurrences(of: "name:", with: ""))
                    if !v.isEmpty { meta.name = v }
                } else if trimmed.starts(with: "description:") {
                    let v = cleanVal(trimmed.replacingOccurrences(of: "description:", with: ""))
                    if !v.isEmpty && v != ">" && v != "|" { meta.description = v }
                } else if trimmed.starts(with: "version:") {
                    let v = cleanVal(trimmed.replacingOccurrences(of: "version:", with: ""))
                    if !v.isEmpty { meta.version = v }
                } else if trimmed.starts(with: "maintained-by:") || trimmed.starts(with: "author:") {
                    let v = cleanVal(trimmed.replacingOccurrences(of: "maintained-by:", with: "").replacingOccurrences(of: "author:", with: ""))
                    if !v.isEmpty { meta.author = v }
                } else if trimmed.starts(with: "argument-hint:") {
                    let v = cleanVal(trimmed.replacingOccurrences(of: "argument-hint:", with: ""))
                    if !v.isEmpty { meta.argumentHint = v }
                } else if trimmed.starts(with: "icon:") {
                    let v = cleanVal(trimmed.replacingOccurrences(of: "icon:", with: ""))
                    if !v.isEmpty { meta.icon = v }
                }
            }
        }
        
        // Fallback for description if empty or folded block
        if meta.description == nil {
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty && !trimmed.starts(with: "#") && !trimmed.starts(with: "---") && !trimmed.contains(":") {
                    meta.description = String(trimmed.prefix(160))
                    break
                }
            }
        }
        
        return meta
    }
}
