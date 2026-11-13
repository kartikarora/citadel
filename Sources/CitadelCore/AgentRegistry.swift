import Foundation

/// Defines a known AI coding agent and its project/global skill configuration directories,
/// modeled on `vercel-labs/skills` (`src/agents.ts`) plus Citadel extensions (e.g. `.matilda`, `.android-studio`).
public struct AgentConfig: Identifiable, Sendable {
    public enum Base: Sendable {
        case home(String)
        case xdgConfig(String)
        case envOrHome(envVar: String, defaultSubpath: String)
        
        public func resolve(home: URL, xdgConfig: URL, env: [String: String]) -> URL {
            switch self {
            case .home(let subpath):
                return home.appendingPathComponent(subpath)
            case .xdgConfig(let subpath):
                return xdgConfig.appendingPathComponent(subpath)
            case .envOrHome(let envVar, let defaultSubpath):
                if let custom = env[envVar]?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
                    return URL(fileURLWithPath: custom)
                }
                return home.appendingPathComponent(defaultSubpath)
            }
        }

        var relativeDotPath: String? {
            switch self {
            case .home(let subpath), .envOrHome(_, let subpath):
                return subpath.hasPrefix(".") ? subpath : nil
            case .xdgConfig:
                return nil
            }
        }

        func defaultHomeURL(home: URL) -> URL? {
            switch self {
            case .home(let subpath), .envOrHome(_, let subpath):
                return home.appendingPathComponent(subpath)
            case .xdgConfig:
                return nil
            }
        }
    }
    
    public let id: String
    public let displayName: String
    public let sourceKind: String
    public let skillsDir: String
    public let globalSkillsBase: Base?
    public let globalSkillsSuffix: String
    public let detectBases: [Base]
    
    public init(
        id: String,
        displayName: String,
        sourceKind: String,
        skillsDir: String,
        globalSkillsBase: Base?,
        globalSkillsSuffix: String = "skills",
        detectBases: [Base]
    ) {
        self.id = id
        self.displayName = displayName
        self.sourceKind = sourceKind
        self.skillsDir = skillsDir
        self.globalSkillsBase = globalSkillsBase
        self.globalSkillsSuffix = globalSkillsSuffix
        self.detectBases = detectBases
    }
    
    public func globalSkillsDir(
        home: URL = UniversalPaths.shared.home,
        xdgConfig: URL = UniversalPaths.shared.xdgConfigRoot,
        env: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        guard let base = globalSkillsBase else { return nil }
        let root = base.resolve(home: home, xdgConfig: xdgConfig, env: env)
        return globalSkillsSuffix.isEmpty ? root : root.appendingPathComponent(globalSkillsSuffix)
    }
    
    public func detectDirs(
        home: URL = UniversalPaths.shared.home,
        xdgConfig: URL = UniversalPaths.shared.xdgConfigRoot,
        env: [String: String] = ProcessInfo.processInfo.environment
    ) -> [URL] {
        detectBases.map { $0.resolve(home: home, xdgConfig: xdgConfig, env: env) }
    }
}

/// Central registry of known AI coding agents and their configuration folders.
/// Mirrors `vercel-labs/skills` `src/agents.ts` alongside Citadel-supported tools such as `.matilda`.
public struct AgentRegistry: Sendable {
    public static let shared = AgentRegistry()
    
    public let agents: [AgentConfig]
    
    public init() {
        self.agents = [
            // Citadel-specific / newly added agents
            AgentConfig(id: "matilda", displayName: "Matilda", sourceKind: "matilda", skillsDir: ".matilda/skills", globalSkillsBase: .home(".matilda"), detectBases: [.home(".matilda")]),
            AgentConfig(id: "android-studio", displayName: "Android Studio", sourceKind: "android-studio", skillsDir: ".android-studio/skills", globalSkillsBase: .home(".android-studio"), detectBases: [.home(".android-studio")]),
            
            // vercel-labs/skills agents.ts registry
            AgentConfig(id: "aider-desk", displayName: "AiderDesk", sourceKind: "aider-desk", skillsDir: ".aider-desk/skills", globalSkillsBase: .home(".aider-desk"), detectBases: [.home(".aider-desk")]),
            AgentConfig(id: "amp", displayName: "Amp", sourceKind: "amp", skillsDir: ".agents/skills", globalSkillsBase: .xdgConfig("agents"), detectBases: [.xdgConfig("amp")]),
            AgentConfig(id: "antigravity", displayName: "Antigravity", sourceKind: "antigravity", skillsDir: ".agents/skills", globalSkillsBase: .home(".gemini/config"), detectBases: [.home(".gemini/antigravity"), .home(".gemini")]),
            AgentConfig(id: "antigravity-cli", displayName: "Antigravity CLI", sourceKind: "antigravity", skillsDir: ".agents/skills", globalSkillsBase: .home(".gemini/config"), detectBases: [.home(".gemini/antigravity-cli"), .home(".gemini")]),
            AgentConfig(id: "astrbot", displayName: "AstrBot", sourceKind: "astrbot", skillsDir: "data/skills", globalSkillsBase: .home(".astrbot/data"), detectBases: [.home(".astrbot")]),
            AgentConfig(id: "autohand-code", displayName: "Autohand Code CLI", sourceKind: "autohand", skillsDir: ".autohand/skills", globalSkillsBase: .envOrHome(envVar: "AUTOHAND_HOME", defaultSubpath: ".autohand"), detectBases: [.envOrHome(envVar: "AUTOHAND_HOME", defaultSubpath: ".autohand")]),
            AgentConfig(id: "augment", displayName: "Augment", sourceKind: "augment", skillsDir: ".augment/skills", globalSkillsBase: .home(".augment"), detectBases: [.home(".augment")]),
            AgentConfig(id: "bob", displayName: "IBM Bob", sourceKind: "bob", skillsDir: ".bob/skills", globalSkillsBase: .home(".bob"), detectBases: [.home(".bob")]),
            AgentConfig(id: "claude-code", displayName: "Claude Code", sourceKind: "claude", skillsDir: ".claude/skills", globalSkillsBase: .envOrHome(envVar: "CLAUDE_CONFIG_DIR", defaultSubpath: ".claude"), detectBases: [.envOrHome(envVar: "CLAUDE_CONFIG_DIR", defaultSubpath: ".claude")]),
            AgentConfig(id: "openclaw", displayName: "OpenClaw", sourceKind: "openclaw", skillsDir: "skills", globalSkillsBase: .home(".openclaw"), detectBases: [.home(".openclaw"), .home(".clawdbot"), .home(".moltbot")]),
            AgentConfig(id: "cline", displayName: "Cline", sourceKind: "cline", skillsDir: ".agents/skills", globalSkillsBase: .home(".agents"), detectBases: [.home(".cline")]),
            AgentConfig(id: "codearts-agent", displayName: "CodeArts Agent", sourceKind: "codearts", skillsDir: ".codeartsdoer/skills", globalSkillsBase: .home(".codeartsdoer"), detectBases: [.home(".codeartsdoer")]),
            AgentConfig(id: "codebuddy", displayName: "CodeBuddy", sourceKind: "codebuddy", skillsDir: ".codebuddy/skills", globalSkillsBase: .home(".codebuddy"), detectBases: [.home(".codebuddy")]),
            AgentConfig(id: "codemaker", displayName: "Codemaker", sourceKind: "codemaker", skillsDir: ".codemaker/skills", globalSkillsBase: .home(".codemaker"), detectBases: [.home(".codemaker")]),
            AgentConfig(id: "codestudio", displayName: "Code Studio", sourceKind: "codestudio", skillsDir: ".codestudio/skills", globalSkillsBase: .home(".codestudio"), detectBases: [.home(".codestudio")]),
            AgentConfig(id: "codex", displayName: "Codex", sourceKind: "codex", skillsDir: ".agents/skills", globalSkillsBase: .home(".agents"), detectBases: [.envOrHome(envVar: "CODEX_HOME", defaultSubpath: ".codex")]),
            AgentConfig(id: "command-code", displayName: "Command Code", sourceKind: "commandcode", skillsDir: ".commandcode/skills", globalSkillsBase: .home(".commandcode"), detectBases: [.home(".commandcode")]),
            AgentConfig(id: "continue", displayName: "Continue", sourceKind: "continue", skillsDir: ".continue/skills", globalSkillsBase: .home(".continue"), detectBases: [.home(".continue")]),
            AgentConfig(id: "cortex", displayName: "Cortex Code", sourceKind: "cortex", skillsDir: ".cortex/skills", globalSkillsBase: .home(".snowflake/cortex"), detectBases: [.home(".snowflake/cortex")]),
            AgentConfig(id: "crush", displayName: "Crush", sourceKind: "crush", skillsDir: ".crush/skills", globalSkillsBase: .xdgConfig("crush"), detectBases: [.xdgConfig("crush")]),
            AgentConfig(id: "cursor", displayName: "Cursor", sourceKind: "cursor", skillsDir: ".agents/skills", globalSkillsBase: .home(".cursor"), detectBases: [.home(".cursor")]),
            AgentConfig(id: "deepagents", displayName: "Deep Agents", sourceKind: "deepagents", skillsDir: ".agents/skills", globalSkillsBase: .home(".deepagents/agent"), detectBases: [.home(".deepagents")]),
            AgentConfig(id: "devin", displayName: "Devin for Terminal", sourceKind: "devin", skillsDir: ".devin/skills", globalSkillsBase: .xdgConfig("devin"), detectBases: [.xdgConfig("devin")]),
            AgentConfig(id: "dexto", displayName: "Dexto", sourceKind: "dexto", skillsDir: ".agents/skills", globalSkillsBase: .home(".agents"), detectBases: [.home(".dexto")]),
            AgentConfig(id: "droid", displayName: "Droid", sourceKind: "droid", skillsDir: ".agents/skills", globalSkillsBase: .home(".factory"), detectBases: [.home(".factory")]),
            AgentConfig(id: "eve", displayName: "Eve", sourceKind: "eve", skillsDir: "agent/skills", globalSkillsBase: nil, detectBases: []),
            AgentConfig(id: "firebender", displayName: "Firebender", sourceKind: "firebender", skillsDir: ".agents/skills", globalSkillsBase: .home(".firebender"), detectBases: [.home(".firebender")]),
            AgentConfig(id: "forgecode", displayName: "ForgeCode", sourceKind: "forge", skillsDir: ".forge/skills", globalSkillsBase: .home(".forge"), detectBases: [.home(".forge")]),
            AgentConfig(id: "fx", displayName: "fx", sourceKind: "fx", skillsDir: ".agents/skills", globalSkillsBase: .home(".agents"), detectBases: [.home(".fx")]),
            AgentConfig(id: "gemini-cli", displayName: "Gemini CLI", sourceKind: "gemini-cli", skillsDir: ".agents/skills", globalSkillsBase: .home(".gemini"), detectBases: [.home(".gemini")]),
            AgentConfig(id: "github-copilot", displayName: "GitHub Copilot", sourceKind: "copilot", skillsDir: ".agents/skills", globalSkillsBase: .home(".copilot"), detectBases: [.home(".copilot")]),
            AgentConfig(id: "goose", displayName: "Goose", sourceKind: "goose", skillsDir: ".goose/skills", globalSkillsBase: .xdgConfig("goose"), detectBases: [.xdgConfig("goose")]),
            AgentConfig(id: "grok", displayName: "Grok Build", sourceKind: "grok", skillsDir: ".grok/skills", globalSkillsBase: .envOrHome(envVar: "GROK_HOME", defaultSubpath: ".grok"), detectBases: [.envOrHome(envVar: "GROK_HOME", defaultSubpath: ".grok")]),
            AgentConfig(id: "hermes-agent", displayName: "Hermes Agent", sourceKind: "hermes", skillsDir: ".hermes/skills", globalSkillsBase: .envOrHome(envVar: "HERMES_HOME", defaultSubpath: ".hermes"), detectBases: [.envOrHome(envVar: "HERMES_HOME", defaultSubpath: ".hermes")]),
            AgentConfig(id: "inference-sh", displayName: "inference.sh", sourceKind: "inferencesh", skillsDir: ".inferencesh/skills", globalSkillsBase: .home(".inferencesh"), detectBases: [.home(".inferencesh")]),
            AgentConfig(id: "jazz", displayName: "Jazz", sourceKind: "jazz", skillsDir: ".jazz/skills", globalSkillsBase: .home(".jazz"), detectBases: [.home(".jazz")]),
            AgentConfig(id: "junie", displayName: "Junie", sourceKind: "junie", skillsDir: ".junie/skills", globalSkillsBase: .home(".junie"), detectBases: [.home(".junie")]),
            AgentConfig(id: "iflow-cli", displayName: "iFlow CLI", sourceKind: "iflow", skillsDir: ".iflow/skills", globalSkillsBase: .home(".iflow"), detectBases: [.home(".iflow")]),
            AgentConfig(id: "kilo", displayName: "Kilo Code", sourceKind: "kilo", skillsDir: ".agents/skills", globalSkillsBase: .home(".kilo"), detectBases: [.home(".kilo"), .home(".kilocode")]),
            AgentConfig(id: "kimchi", displayName: "Kimchi", sourceKind: "kimchi", skillsDir: ".kimchi/skills", globalSkillsBase: .xdgConfig("kimchi/harness"), detectBases: [.xdgConfig("kimchi")]),
            AgentConfig(id: "kimi-code-cli", displayName: "Kimi Code CLI", sourceKind: "kimi", skillsDir: ".agents/skills", globalSkillsBase: .home(".agents"), detectBases: [.home(".kimi-code"), .home(".kimi")]),
            AgentConfig(id: "kiro-cli", displayName: "Kiro CLI", sourceKind: "kiro", skillsDir: ".kiro/skills", globalSkillsBase: .home(".kiro"), detectBases: [.home(".kiro")]),
            AgentConfig(id: "kode", displayName: "Kode", sourceKind: "kode", skillsDir: ".kode/skills", globalSkillsBase: .home(".kode"), detectBases: [.home(".kode")]),
            AgentConfig(id: "lingma", displayName: "Lingma", sourceKind: "lingma", skillsDir: ".lingma/skills", globalSkillsBase: .home(".lingma"), detectBases: [.home(".lingma")]),
            AgentConfig(id: "loaf", displayName: "Loaf", sourceKind: "loaf", skillsDir: ".agents/skills", globalSkillsBase: .home(".agents"), detectBases: [.home(".loaf")]),
            AgentConfig(id: "mcpjam", displayName: "MCPJam", sourceKind: "mcpjam", skillsDir: ".mcpjam/skills", globalSkillsBase: .home(".mcpjam"), detectBases: [.home(".mcpjam")]),
            AgentConfig(id: "minimax-code", displayName: "MiniMax Code", sourceKind: "minimax", skillsDir: ".minimax/skills", globalSkillsBase: .home(".minimax"), detectBases: [.home(".minimax")]),
            AgentConfig(id: "mistral-vibe", displayName: "Mistral Vibe", sourceKind: "vibe", skillsDir: ".vibe/skills", globalSkillsBase: .envOrHome(envVar: "VIBE_HOME", defaultSubpath: ".vibe"), detectBases: [.envOrHome(envVar: "VIBE_HOME", defaultSubpath: ".vibe")]),
            AgentConfig(id: "moxby", displayName: "Moxby", sourceKind: "moxby", skillsDir: ".moxby/skills", globalSkillsBase: .home(".moxby"), detectBases: [.home(".moxby")]),
            AgentConfig(id: "mux", displayName: "Mux", sourceKind: "mux", skillsDir: ".mux/skills", globalSkillsBase: .home(".mux"), detectBases: [.home(".mux")]),
            AgentConfig(id: "opencode", displayName: "OpenCode", sourceKind: "opencode", skillsDir: ".agents/skills", globalSkillsBase: .xdgConfig("opencode"), detectBases: [.xdgConfig("opencode")]),
            AgentConfig(id: "openhands", displayName: "OpenHands", sourceKind: "openhands", skillsDir: ".openhands/skills", globalSkillsBase: .home(".openhands"), detectBases: [.home(".openhands")]),
            AgentConfig(id: "ona", displayName: "Ona", sourceKind: "ona", skillsDir: ".ona/skills", globalSkillsBase: .home(".ona"), detectBases: [.home(".ona")]),
            AgentConfig(id: "pi", displayName: "Pi", sourceKind: "pi", skillsDir: ".agents/skills", globalSkillsBase: .home(".agents"), detectBases: [.home(".pi")]),
            AgentConfig(id: "posit-assistant", displayName: "Posit Assistant", sourceKind: "posit", skillsDir: ".posit/assistant/skills", globalSkillsBase: .home(".posit/assistant"), detectBases: [.home(".posit/assistant"), .home(".positai")]),
            AgentConfig(id: "qoder", displayName: "Qoder", sourceKind: "qoder", skillsDir: ".qoder/skills", globalSkillsBase: .home(".qoder"), detectBases: [.home(".qoder")]),
            AgentConfig(id: "qoder-cn", displayName: "Qoder CN", sourceKind: "qoder", skillsDir: ".qoder/skills", globalSkillsBase: .home(".qoder-cn"), detectBases: [.home(".qoder-cn")]),
            AgentConfig(id: "qwen-code", displayName: "Qwen Code", sourceKind: "qwen", skillsDir: ".qwen/skills", globalSkillsBase: .home(".qwen"), detectBases: [.home(".qwen")]),
            AgentConfig(id: "replit", displayName: "Replit", sourceKind: "replit", skillsDir: ".agents/skills", globalSkillsBase: .xdgConfig("agents"), detectBases: [.xdgConfig("agents")]),
            AgentConfig(id: "reasonix", displayName: "Reasonix", sourceKind: "reasonix", skillsDir: ".reasonix/skills", globalSkillsBase: .envOrHome(envVar: "REASONIX_HOME", defaultSubpath: ".reasonix"), detectBases: [.envOrHome(envVar: "REASONIX_HOME", defaultSubpath: ".reasonix")]),
            AgentConfig(id: "rovodev", displayName: "Rovo Dev", sourceKind: "rovodev", skillsDir: ".rovodev/skills", globalSkillsBase: .home(".rovodev"), detectBases: [.home(".rovodev")]),
            AgentConfig(id: "roo", displayName: "Roo Code", sourceKind: "roo", skillsDir: ".roo/skills", globalSkillsBase: .home(".roo"), detectBases: [.home(".roo")]),
            AgentConfig(id: "sarvam-code", displayName: "Sarvam Code", sourceKind: "sarvam", skillsDir: ".agents/skills", globalSkillsBase: .home(".agents"), detectBases: [.envOrHome(envVar: "SARVAM_HOME", defaultSubpath: ".sarvam")]),
            AgentConfig(id: "tabnine-cli", displayName: "Tabnine CLI", sourceKind: "tabnine", skillsDir: ".tabnine/agent/skills", globalSkillsBase: .home(".tabnine/agent"), detectBases: [.home(".tabnine")]),
            AgentConfig(id: "terramind", displayName: "Terramind", sourceKind: "terramind", skillsDir: ".terramind/skills", globalSkillsBase: .home(".terramind"), detectBases: [.home(".terramind")]),
            AgentConfig(id: "tinycloud", displayName: "Tinycloud", sourceKind: "tinycloud", skillsDir: ".tinycloud/skills", globalSkillsBase: .home(".tinycloud"), detectBases: [.home(".tinycloud")]),
            AgentConfig(id: "trae", displayName: "Trae", sourceKind: "trae", skillsDir: ".trae/skills", globalSkillsBase: .home(".trae"), detectBases: [.home(".trae")]),
            AgentConfig(id: "trae-cn", displayName: "Trae CN", sourceKind: "trae", skillsDir: ".trae/skills", globalSkillsBase: .home(".trae-cn"), detectBases: [.home(".trae-cn")]),
            AgentConfig(id: "warp", displayName: "Warp", sourceKind: "warp", skillsDir: ".agents/skills", globalSkillsBase: .home(".agents"), detectBases: [.home(".warp")]),
            AgentConfig(id: "windsurf", displayName: "Windsurf", sourceKind: "windsurf", skillsDir: ".windsurf/skills", globalSkillsBase: .home(".codeium/windsurf"), detectBases: [.home(".codeium"), .home(".windsurf")]),
            AgentConfig(id: "zed", displayName: "Zed", sourceKind: "zed", skillsDir: ".agents/skills", globalSkillsBase: .home(".agents"), detectBases: [.home(".zed"), .xdgConfig("zed")]),
            AgentConfig(id: "zcode", displayName: "ZCode", sourceKind: "zcode", skillsDir: ".zcode/skills", globalSkillsBase: .home(".zcode"), detectBases: [.home(".zcode")]),
            AgentConfig(id: "zencoder", displayName: "Zencoder", sourceKind: "zencoder", skillsDir: ".zencoder/skills", globalSkillsBase: .home(".zencoder"), detectBases: [.home(".zencoder")]),
            AgentConfig(id: "zenflow", displayName: "Zenflow", sourceKind: "zenflow", skillsDir: ".zencoder/skills", globalSkillsBase: .home(".zencoder"), detectBases: [.home(".zencoder")]),
            AgentConfig(id: "neovate", displayName: "Neovate", sourceKind: "neovate", skillsDir: ".neovate/skills", globalSkillsBase: .home(".neovate"), detectBases: [.home(".neovate")]),
            AgentConfig(id: "pochi", displayName: "Pochi", sourceKind: "pochi", skillsDir: ".pochi/skills", globalSkillsBase: .home(".pochi"), detectBases: [.home(".pochi")]),
            AgentConfig(id: "promptscript", displayName: "PromptScript", sourceKind: "promptscript", skillsDir: ".agents/skills", globalSkillsBase: nil, detectBases: []),
            AgentConfig(id: "adal", displayName: "AdaL", sourceKind: "adal", skillsDir: ".adal/skills", globalSkillsBase: .home(".adal"), detectBases: [.home(".adal")]),
            AgentConfig(id: "universal", displayName: "Universal", sourceKind: "agents", skillsDir: ".agents/skills", globalSkillsBase: .xdgConfig("agents"), detectBases: [.home(".agents"), .xdgConfig("agents")])
        ]
    }
    
    /// Unique global detection/root directories across all known agents,
    /// including suffixed profile directories (e.g. `~/.claude-bilue`, `~/.claude-qantas`).
    public func allGlobalRootDirs(
        home: URL = UniversalPaths.shared.home,
        xdgConfig: URL = UniversalPaths.shared.xdgConfigRoot,
        env: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []
        var dirCache: [String: [URL]] = [:]
        for agent in agents {
            for base in agent.detectBases {
                let resolved = base.resolve(home: home, xdgConfig: xdgConfig, env: env)
                if seen.insert(resolved.path).inserted {
                    result.append(resolved)
                }
                for profileRoot in profileDirectories(matching: resolved, fileManager: fileManager, cache: &dirCache) {
                    if seen.insert(profileRoot.path).inserted {
                        result.append(profileRoot)
                    }
                }
                if let fallback = base.defaultHomeURL(home: home), fallback.path != resolved.path {
                    if fileManager.fileExists(atPath: fallback.path), seen.insert(fallback.path).inserted {
                        result.append(fallback)
                    }
                    for profileRoot in profileDirectories(matching: fallback, fileManager: fileManager, cache: &dirCache) {
                        if seen.insert(profileRoot.path).inserted {
                            result.append(profileRoot)
                        }
                    }
                }
            }
        }
        return result
    }
    
    /// Unique global skills directories across all known agents,
    /// including suffixed profile directories (e.g. `~/.claude-bilue/skills`).
    public func allGlobalSkillsDirs(
        home: URL = UniversalPaths.shared.home,
        xdgConfig: URL = UniversalPaths.shared.xdgConfigRoot,
        env: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []
        var dirCache: [String: [URL]] = [:]
        for agent in agents {
            if let dir = agent.globalSkillsDir(home: home, xdgConfig: xdgConfig, env: env),
               seen.insert(dir.path).inserted {
                result.append(dir)
            }
            for profile in profileSkillTargets(for: agent, home: home, xdgConfig: xdgConfig, env: env, fileManager: fileManager, cache: &dirCache) {
                if seen.insert(profile.path).inserted {
                    result.append(profile)
                }
            }
        }
        return result
    }
    
    /// Unique project-relative skills directories across all known agents (e.g. `.claude/skills`, `.matilda/skills`, `.agents/skills`).
    public var allProjectSkillDirs: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for agent in agents {
            if seen.insert(agent.skillsDir).inserted {
                result.append(agent.skillsDir)
            }
        }
        return result
    }
    
    /// Unique project-level hidden config folder names (e.g. `.claude`, `.matilda`, `.agents`, `.cursor`).
    public var allProjectConfigFolderNames: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for agent in agents {
            if let first = agent.skillsDir.split(separator: "/").first, first.hasPrefix(".") {
                let folder = String(first)
                if seen.insert(folder).inserted {
                    result.append(folder)
                }
            }
        }
        return result
    }
    
    /// Resolves a source kind label for a discovered skill path using the registry.
    public func sourceKind(
        for url: URL,
        home: URL = UniversalPaths.shared.home,
        xdgConfig: URL = UniversalPaths.shared.xdgConfigRoot,
        env: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        let p = url.path
        if p.contains("/plugins/") { return "plugin" }
        if p.contains("/builtin/") { return "builtin" }
        
        // Match against known agent global detectDirs or project config folder segments (including suffixed profiles like .claude-bilue)
        for agent in agents {
            for dir in agent.detectDirs(home: home, xdgConfig: xdgConfig, env: env) {
                if p == dir.path || p.hasPrefix(dir.path + "/") || p.hasPrefix(dir.path + "-") {
                    return agent.sourceKind
                }
            }
            if let dotBase = agent.globalSkillsBase?.relativeDotPath, dotBase != ".agents",
               p.contains("/\(dotBase)/") || p.contains("/\(dotBase)-") {
                return agent.sourceKind
            }
            for base in agent.detectBases {
                if let dotBase = base.relativeDotPath, dotBase != ".agents",
                   p.contains("/\(dotBase)/") || p.contains("/\(dotBase)-") {
                    return agent.sourceKind
                }
            }
            if let topFolder = agent.skillsDir.split(separator: "/").first, topFolder.hasPrefix("."),
               topFolder != ".agents",
               p.contains("/\(topFolder)/") || p.contains("/\(topFolder)-") {
                return agent.sourceKind
            }
        }
        
        if p.contains("/.agents/") { return "agents" }
        if p.contains("/Projects/") || p.contains("/Developer/") || p.contains("/Development/") || p.contains("/Workspace/") {
            return "workspace"
        }
        return "custom"
    }
    
    /// Returns deduplicated `(agent, globalSkillsDir)` pairs for all agents currently detected on disk,
    /// including suffixed profile directories (e.g. `~/.claude-bilue`, `~/.claude-qantas`).
    public func detectedGlobalSyncTargets(
        home: URL = UniversalPaths.shared.home,
        xdgConfig: URL = UniversalPaths.shared.xdgConfigRoot,
        env: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> [(agent: AgentConfig, skillsDir: URL)] {
        var seenSkillsDirs = Set<String>()
        var targets: [(agent: AgentConfig, skillsDir: URL)] = []
        var dirCache: [String: [URL]] = [:]
        
        for agent in agents {
            if let skillsDir = agent.globalSkillsDir(home: home, xdgConfig: xdgConfig, env: env) {
                let isInstalled = agent.detectDirs(home: home, xdgConfig: xdgConfig, env: env)
                    .contains { fileManager.fileExists(atPath: $0.path) }
                if isInstalled, seenSkillsDirs.insert(skillsDir.path).inserted {
                    targets.append((agent, skillsDir))
                }
            }
            
            for profileSkillsDir in profileSkillTargets(for: agent, home: home, xdgConfig: xdgConfig, env: env, fileManager: fileManager, cache: &dirCache) {
                if seenSkillsDirs.insert(profileSkillsDir.path).inserted {
                    targets.append((agent, profileSkillsDir))
                }
            }
        }
        return targets
    }

    /// Returns existing project-level `(folderLabel, skillsDir)` pairs inside `projectPath`,
    /// covering both standard agent directories (e.g. `.matilda`, `.claude`) and suffixed profiles (e.g. `.claude-bilue`).
    public func detectedProjectSkillDirs(
        in projectPath: URL,
        fileManager: FileManager = .default
    ) -> [(label: String, skillsDir: URL)] {
        var seen = Set<String>()
        var results: [(label: String, skillsDir: URL)] = []

        for relativeSkillsDir in allProjectSkillDirs {
            let folderName = relativeSkillsDir.split(separator: "/").first.map(String.init) ?? relativeSkillsDir
            let agentRoot = projectPath.appendingPathComponent(folderName)
            if fileManager.fileExists(atPath: agentRoot.path) {
                let targetDir = projectPath.appendingPathComponent(relativeSkillsDir)
                if seen.insert(targetDir.path).inserted {
                    results.append((folderName, targetDir))
                }
            }
        }

        if let entries = try? fileManager.contentsOfDirectory(
            at: projectPath,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) {
            let knownPrefixes = allProjectConfigFolderNames.filter { $0 != ".agents" }
            for entry in entries {
                let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard isDir else { continue }
                let name = entry.lastPathComponent
                guard knownPrefixes.contains(where: { name.hasPrefix("\($0)-") }) else { continue }
                let targetDir = entry.appendingPathComponent("skills")
                if seen.insert(targetDir.path).inserted {
                    results.append((name, targetDir))
                }
            }
        }

        return results
    }

    // MARK: - Profile Directory Helpers

    private func profileDirectories(
        matching baseDir: URL,
        fileManager: FileManager,
        cache: inout [String: [URL]]
    ) -> [URL] {
        let baseName = baseDir.lastPathComponent
        guard baseName != ".agents", !baseName.isEmpty else { return [] }
        let parent = baseDir.deletingLastPathComponent()
        let children: [URL]
        if let cached = cache[parent.path] {
            children = cached
        } else {
            let names = (try? fileManager.contentsOfDirectory(atPath: parent.path)) ?? []
            let listed = names.map { parent.appendingPathComponent($0) }
            cache[parent.path] = listed
            children = listed
        }

        let prefix = "\(baseName)-"
        return children.filter { child in
            let name = child.lastPathComponent
            guard name.hasPrefix(prefix), name.count > prefix.count else { return false }
            var isDir: ObjCBool = false
            return fileManager.fileExists(atPath: child.path, isDirectory: &isDir) && isDir.boolValue
        }
    }

    private func profileSkillTargets(
        for agent: AgentConfig,
        home: URL,
        xdgConfig: URL,
        env: [String: String],
        fileManager: FileManager,
        cache: inout [String: [URL]]
    ) -> [URL] {
        guard let canonicalSkillsDir = agent.globalSkillsDir(home: home, xdgConfig: xdgConfig, env: env) else {
            return []
        }
        var results: [URL] = []
        for base in agent.detectBases {
            let resolved = base.resolve(home: home, xdgConfig: xdgConfig, env: env)
            var candidateBases = [resolved]
            if let fallback = base.defaultHomeURL(home: home), fallback.path != resolved.path {
                candidateBases.append(fallback)
                if fileManager.fileExists(atPath: fallback.path) {
                    results.append(fallback.appendingPathComponent("skills"))
                }
            }
            for detectDir in candidateBases {
                let skillsSubpath: String
                if canonicalSkillsDir.path.hasPrefix(detectDir.path + "/") {
                    skillsSubpath = String(canonicalSkillsDir.path.dropFirst(detectDir.path.count + 1))
                } else {
                    skillsSubpath = "skills"
                }
                for profileRoot in profileDirectories(matching: detectDir, fileManager: fileManager, cache: &cache) {
                    results.append(profileRoot.appendingPathComponent(skillsSubpath))
                }
            }
        }
        return results
    }
}
