import Foundation

/// Supported AI targets across the multiverse
public enum ToolTarget: String, CaseIterable, Codable, Sendable {
    case antigravityGlobal = "antigravity"
    case antigravityPlugin = "antigravity-plugin"
    case claudeCode = "claude-code"
    case claudeDesktop = "claude-desktop"
    case cursor = "cursor"
    case codex = "codex"
    case androidStudio = "android-studio"
    case githubCopilot = "github-copilot"
    case junie = "junie"
    
    public var displayName: String {
        switch self {
        case .antigravityGlobal: return "Antigravity (Global)"
        case .antigravityPlugin: return "Antigravity (Plugins)"
        case .claudeCode: return "Claude Code CLI"
        case .claudeDesktop: return "Claude Desktop"
        case .cursor: return "Cursor"
        case .codex: return "Codex"
        case .androidStudio: return "Android Studio"
        case .githubCopilot: return "GitHub Copilot"
        case .junie: return "Junie"
        }
    }
    
    public var sfSymbol: String {
        switch self {
        case .antigravityGlobal, .antigravityPlugin: return "sparkles"
        case .claudeCode, .claudeDesktop: return "terminal.fill"
        case .cursor: return "cursorarrow.rays"
        case .codex: return "doc.text.fill"
        case .androidStudio: return "hammer.fill"
        case .githubCopilot: return "airplane.departure"
        case .junie: return "bolt.shield.fill"
        }
    }
    
    public var relativeProjectSkillsDir: String {
        switch self {
        case .antigravityGlobal, .antigravityPlugin: return ".gemini/skills"
        case .claudeCode, .claudeDesktop: return ".claude/skills"
        case .cursor: return ".cursor/skills"
        case .codex: return ".agents/skills"
        case .androidStudio: return ".android-studio/skills"
        case .githubCopilot: return ".github/skills"
        case .junie: return ".junie/skills"
        }
    }
    
    /// Maps from an AgentConfig identifier or sourceKind to a ToolTarget if known
    public static func from(agentId: String) -> ToolTarget? {
        let lower = agentId.lowercased()
        if lower.contains("claude") { return .claudeCode }
        if lower.contains("antigravity") || lower.contains("gemini") { return .antigravityGlobal }
        if lower.contains("cursor") { return .cursor }
        if lower.contains("codex") || lower == "agents" || lower == "universal" { return .codex }
        if lower.contains("android-studio") { return .androidStudio }
        if lower.contains("copilot") { return .githubCopilot }
        if lower.contains("junie") { return .junie }
        return nil
    }
}

/// A skill representing an instruction set or bundle of capabilities
public struct Skill: Identifiable, Codable, Sendable, Hashable {
    public var id: String { name }
    public let name: String
    public let path: URL
    public let description: String?
    public var isSymlink: Bool
    public var version: String?
    public var author: String?
    public var argumentHint: String?
    public var icon: String?
    
    public init(
        name: String,
        path: URL,
        description: String? = nil,
        isSymlink: Bool = false,
        version: String? = nil,
        author: String? = nil,
        argumentHint: String? = nil,
        icon: String? = nil
    ) {
        self.name = name
        self.path = path
        self.description = description
        self.isSymlink = isSymlink
        self.version = version
        self.author = author
        self.argumentHint = argumentHint
        self.icon = icon
    }
    
    /// Immediate accompanying files or directories inside the skill package (excluding SKILL.md and hidden files)
    public var accompanyingFiles: [String] {
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: path.path) else { return [] }
        return items.filter { !$0.hasPrefix(".") && $0.lowercased() != "skill.md" }.sorted()
    }
}

/// An MCP Server definition (Canonical)
public struct MCPServer: Identifiable, Codable, Sendable, Hashable {
    public var id: String { name }
    public let name: String
    public let command: String
    public let args: [String]
    public let env: [String: String]?
    
    public init(name: String, command: String, args: [String], env: [String: String]? = nil) {
        self.name = name
        self.command = command
        self.args = args
        self.env = env
    }
}

/// Project-level Portal link
public struct ProjectPortal: Identifiable, Codable, Sendable, Hashable {
    public var id: String { citadelId ?? projectPath.path }
    public var citadelId: String?
    public var gitRemote: String?
    public var gitRootHash: String?
    public let projectPath: URL
    public var enabledSkills: [String]
    public var enabledMCPs: [String]
    public var targetTools: [ToolTarget]
    public var targetAgentIds: [String]
    public var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case citadelId
        case gitRemote
        case gitRootHash
        case projectPath
        case portablePath
        case enabledSkills
        case enabledMCPs
        case targetTools
        case targetAgentIds
        case createdAt
    }
    
    public init(
        projectPath: URL,
        citadelId: String? = nil,
        gitRemote: String? = nil,
        gitRootHash: String? = nil,
        enabledSkills: [String] = [],
        enabledMCPs: [String] = [],
        targetTools: [ToolTarget] = [.antigravityGlobal, .claudeCode],
        targetAgentIds: [String]? = nil,
        createdAt: Date = Date()
    ) {
        self.projectPath = projectPath
        
        // Auto-detect git stamp and fingerprint if available
        if let stampedId = citadelId ?? PortablePath.getOrStampGitPortalId(in: projectPath) {
            self.citadelId = stampedId
        } else {
            self.citadelId = "cproj_" + UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(16)
        }
        
        let fp = PortablePath.gitFingerprint(in: projectPath)
        self.gitRemote = gitRemote ?? fp.remote
        self.gitRootHash = gitRootHash ?? fp.rootHash
        
        self.enabledSkills = enabledSkills
        self.enabledMCPs = enabledMCPs
        self.targetTools = targetTools
        if let agentIds = targetAgentIds {
            self.targetAgentIds = agentIds
        } else {
            // Seed from targetTools if not specified
            self.targetAgentIds = targetTools.map { $0.rawValue }
        }
        self.createdAt = createdAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.citadelId = try container.decodeIfPresent(String.self, forKey: .citadelId)
            ?? container.decodeIfPresent(String.self, forKey: .id)
        self.gitRemote = try container.decodeIfPresent(String.self, forKey: .gitRemote)
        self.gitRootHash = try container.decodeIfPresent(String.self, forKey: .gitRootHash)
        
        // Resolve projectPath from portablePath or projectPath URL
        if let port = try container.decodeIfPresent(String.self, forKey: .portablePath) {
            self.projectPath = PortablePath.fromPortable(port)
        } else if let rawURL = try? container.decode(URL.self, forKey: .projectPath) {
            // If projectPath was an absolute URL like file:///Users/foo/bar, convert through portable expansion
            let p = rawURL.path
            self.projectPath = PortablePath.fromPortable(PortablePath.toPortable(p))
        } else if let strPath = try? container.decode(String.self, forKey: .projectPath) {
            self.projectPath = PortablePath.fromPortable(strPath)
        } else {
            self.projectPath = URL(fileURLWithPath: "/")
        }
        
        self.enabledSkills = try container.decodeIfPresent([String].self, forKey: .enabledSkills) ?? []
        self.enabledMCPs = try container.decodeIfPresent([String].self, forKey: .enabledMCPs) ?? []
        self.targetTools = try container.decodeIfPresent([ToolTarget].self, forKey: .targetTools) ?? []
        let decodedAgentIds = try container.decodeIfPresent([String].self, forKey: .targetAgentIds)
        if let explicit = decodedAgentIds, !explicit.isEmpty {
            self.targetAgentIds = explicit
        } else {
            self.targetAgentIds = self.targetTools.map { $0.rawValue }
        }
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(citadelId, forKey: .citadelId)
        try container.encode(gitRemote, forKey: .gitRemote)
        try container.encode(gitRootHash, forKey: .gitRootHash)
        
        // Save portable representation (~/...) so it cleanly transfers across computers
        let portable = PortablePath.toPortable(projectPath.path)
        try container.encode(portable, forKey: .portablePath)
        try container.encode(projectPath, forKey: .projectPath)
        
        try container.encode(enabledSkills, forKey: .enabledSkills)
        try container.encode(enabledMCPs, forKey: .enabledMCPs)
        try container.encode(targetTools, forKey: .targetTools)
        try container.encode(targetAgentIds, forKey: .targetAgentIds)
        try container.encode(createdAt, forKey: .createdAt)
    }
    
    /// Checks if a given agent identifier is targeted for this workspace portal
    public func isAgentActive(_ agentId: String) -> Bool {
        if targetAgentIds.contains(agentId) { return true }
        if let tool = ToolTarget.from(agentId: agentId), targetTools.contains(tool) { return true }
        if let directTool = ToolTarget(rawValue: agentId), targetTools.contains(directTool) { return true }
        return false
    }
}

/// Sync action event reported to UI and CLI
public struct SyncResult: Sendable {
    public let createdSymlinks: [String]
    public let updatedConfigs: [String]
    public let warnings: [String]
    public let errors: [String]
    
    public init(createdSymlinks: [String] = [], updatedConfigs: [String] = [], warnings: [String] = [], errors: [String] = []) {
        self.createdSymlinks = createdSymlinks
        self.updatedConfigs = updatedConfigs
        self.warnings = warnings
        self.errors = errors
    }
}
