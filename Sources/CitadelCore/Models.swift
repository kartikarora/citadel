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
    public var id: String { projectPath.path }
    public let projectPath: URL
    public var enabledSkills: [String]
    public var enabledMCPs: [String]
    public var targetTools: [ToolTarget]
    public var createdAt: Date
    
    public init(projectPath: URL, enabledSkills: [String] = [], enabledMCPs: [String] = [], targetTools: [ToolTarget] = [.antigravityGlobal, .claudeCode], createdAt: Date = Date()) {
        self.projectPath = projectPath
        self.enabledSkills = enabledSkills
        self.enabledMCPs = enabledMCPs
        self.targetTools = targetTools
        self.createdAt = createdAt
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
