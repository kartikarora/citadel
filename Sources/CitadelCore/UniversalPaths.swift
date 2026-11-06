import Foundation

/// Portable system and platform path resolution adhering to POSIX / XDG / macOS conventions.
public struct UniversalPaths: Sendable {
    public static let shared = UniversalPaths()
    
    public var home: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }
    
    /// Standard application data & config root
    public var appConfigRoot: URL {
        let env = ProcessInfo.processInfo.environment
        if let xdg = env["XDG_CONFIG_HOME"], !xdg.isEmpty {
            return URL(fileURLWithPath: xdg)
        }
        #if os(macOS)
        return home.appendingPathComponent("Library/Application Support")
        #else
        return home.appendingPathComponent(".config")
        #endif
    }
    
    /// Standard cache directory
    public var cacheRoot: URL {
        let env = ProcessInfo.processInfo.environment
        if let xdg = env["XDG_CACHE_HOME"], !xdg.isEmpty {
            return URL(fileURLWithPath: xdg)
        }
        #if os(macOS)
        return home.appendingPathComponent("Library/Caches")
        #else
        return home.appendingPathComponent(".cache")
        #endif
    }
    
    /// Default user hub location: ~/.citadel (or $CITADEL_HOME)
    public var citadelHome: URL {
        if let custom = ProcessInfo.processInfo.environment["CITADEL_HOME"], !custom.isEmpty {
            return URL(fileURLWithPath: custom)
        }
        return home.appendingPathComponent(".citadel")
    }
    
    /// Known client root locations across any POSIX / macOS installation
    public var knownClientRoots: [URL] {
        let candidates: [URL] = [
            // Agents standard location
            home.appendingPathComponent(".agents"),
            // Gemini / Antigravity
            home.appendingPathComponent(".gemini"),
            // Claude
            home.appendingPathComponent(".claude"),
            appConfigRoot.appendingPathComponent("Claude"),
            // Cursor
            home.appendingPathComponent(".cursor"),
            appConfigRoot.appendingPathComponent("Cursor"),
            // Windsurf & Codeium
            home.appendingPathComponent(".windsurf"),
            appConfigRoot.appendingPathComponent("Windsurf"),
            home.appendingPathComponent(".codeium"),
            // Codex & OpenAI
            home.appendingPathComponent(".codex"),
            // Cline & Roo Code
            home.appendingPathComponent(".cline"),
            home.appendingPathComponent(".roo"),
            // Continue.dev
            home.appendingPathComponent(".continue"),
            // Android Studio (~/.android-studio)
            home.appendingPathComponent(".android-studio"),
            // GitHub Copilot (~/.copilot)
            home.appendingPathComponent(".copilot"),
            // Junie (~/.junie)
            home.appendingPathComponent(".junie"),
            // Standard user config
            home.appendingPathComponent(".config"),
            // Common project and development roots
            home.appendingPathComponent("Projects"),
            home.appendingPathComponent("Developer"),
            home.appendingPathComponent("Development"),
            home.appendingPathComponent("Workspace"),
            home.appendingPathComponent("Documents")
        ]
        return candidates.filter { FileManager.default.fileExists(atPath: $0.path) }
    }
    
    /// Default search roots for workspaces: checks current directory and common dev folders if they exist
    public var defaultWorkspaceRoots: [URL] {
        let commonNames = ["Projects", "Developer", "Workspace", "code", "dev", "src"]
        var roots: [URL] = []
        for name in commonNames {
            let candidate = home.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: candidate.path) {
                roots.append(candidate)
            }
        }
        // Always include current directory
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if !roots.contains(where: { $0.path == currentDir.path }) {
            roots.append(currentDir)
        }
        return roots
    }
}
