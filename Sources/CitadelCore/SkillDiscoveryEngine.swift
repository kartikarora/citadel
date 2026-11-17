import Foundation

public struct DiscoveredSkill: Identifiable, Sendable {
    public var id: String { path.path }
    public let name: String
    public let path: URL
    public let sourceKind: String // "plugin", "builtin", "custom", "workspace"
    public let isSymlink: Bool
    public let description: String?
    
    public init(name: String, path: URL, sourceKind: String, isSymlink: Bool, description: String? = nil) {
        self.name = name
        self.path = path
        self.sourceKind = sourceKind
        self.isSymlink = isSymlink
        self.description = description
    }
}

public final class SkillDiscoveryEngine: @unchecked Sendable {
    public static let shared = SkillDiscoveryEngine()
    
    private let fileManager = FileManager.default
    
    public init() {}
    
    /// Known directories where AI tools and projects hide skills on macOS / POSIX
    public var defaultScanRoots: [URL] {
        let home = fileManager.homeDirectoryForCurrentUser
        var candidates = AgentRegistry.shared.allGlobalRootDirs(home: home)
        candidates.append(contentsOf: [
            home.appendingPathComponent(".config"),
            home.appendingPathComponent("Projects"),
            home.appendingPathComponent("Developer"),
            home.appendingPathComponent("Development"),
            home.appendingPathComponent("Workspace"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("src"),
            home.appendingPathComponent("code")
        ])
        var seen = Set<String>()
        return candidates.filter { url in
            seen.insert(url.path).inserted && fileManager.fileExists(atPath: url.path)
        }
    }
    
    /// Recursively scans search roots for any folder containing a `SKILL.md`
    public func discoverSkills(in roots: [URL]? = nil, maxDepth: Int = 5, includeBuiltin: Bool = false, includeProjectShipped: Bool = false) -> [DiscoveredSkill] {
        let targets = roots ?? defaultScanRoots
        var results: [DiscoveredSkill] = []
        var visitedPaths = Set<String>()
        
        for root in targets {
            scanDirectory(root, currentDepth: 0, maxDepth: maxDepth, includeBuiltin: includeBuiltin, includeProjectShipped: includeProjectShipped, results: &results, visitedPaths: &visitedPaths)
        }
        
        return results.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
    
    private func scanDirectory(_ dir: URL, currentDepth: Int, maxDepth: Int, includeBuiltin: Bool, includeProjectShipped: Bool = false, results: inout [DiscoveredSkill], visitedPaths: inout Set<String>) {
        if currentDepth > maxDepth { return }
        
        // Skip noise & heavyweight folders
        let baseName = dir.lastPathComponent
        if baseName == ".git" || baseName == "node_modules" || baseName == ".build" || baseName == ".Trash" || baseName == ".cache" || baseName == "DerivedData" || baseName == ".gradle" {
            return
        }
        
        let pathString = dir.path
        if !includeBuiltin && pathString.contains("/builtin/") {
            return
        }
        if visitedPaths.contains(pathString) { return }
        visitedPaths.insert(pathString)
        
        // Check for SKILL.md (standard) or skill.md / prompt.md / agent-skill definitions
        var skillFileURL: URL? = nil
        let candidateSkillFilenames = ["SKILL.md", "skill.md", "Skill.md"]
        for candidate in candidateSkillFilenames {
            let u = dir.appendingPathComponent(candidate)
            if fileManager.fileExists(atPath: u.path) {
                skillFileURL = u
                break
            }
        }
        
        if let skillFile = skillFileURL {
            // Check if this is a project-shipped or exportable repository skill
            if !includeProjectShipped && isProjectShippedSkill(dir: dir) {
                return
            }
            
            let isLink = (try? dir.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false
            let kind = determineKind(for: dir)
            if !includeBuiltin && kind == "builtin" {
                return
            }
            var desc: String? = nil
            if let content = try? String(contentsOf: skillFile, encoding: .utf8) {
                desc = extractDescription(from: content)
            }
            results.append(DiscoveredSkill(name: baseName, path: dir, sourceKind: kind, isSymlink: isLink, description: desc))
            return // Don't scan children of a skill directory
        }
        
        // Traverse subdirectories
        // If within depth <= 1, allow discovering hidden dot-folders like .agents, .gemini, .claude, .cursor, .skills
        let options: FileManager.DirectoryEnumerationOptions = (currentDepth <= 1) ? [] : [.skipsHiddenFiles]
        guard let subdirs = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: options) else {
            return
        }
        
        for sub in subdirs {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: sub.path, isDirectory: &isDir), isDir.boolValue {
                scanDirectory(sub, currentDepth: currentDepth + 1, maxDepth: maxDepth, includeBuiltin: includeBuiltin, includeProjectShipped: includeProjectShipped, results: &results, visitedPaths: &visitedPaths)
            }
        }
    }
    
    /// Identifies whether a directory contains a project-shipped, author-source, or exportable skill
    /// (e.g. inside `skills/`, `src/skills/`, or repository root with package.json/Package.swift)
    /// rather than an installed agent configuration directory.
    public func isProjectShippedSkill(dir: URL) -> Bool {
        let path = dir.path
        
        // 1. If it's located in an installed agent config directory (e.g. ~/.gemini, ~/.claude, .cursor/skills, .agents/skills)
        // or inside ~/.citadel, it is an active user skill, not a project-shipped export.
        if path.contains("/.citadel/") { return false }
        
        for agent in AgentRegistry.shared.agents {
            let relSkillsDir = agent.skillsDir
            // If the path ends with or contains the exact agent relative skills directory
            if path.contains("/" + relSkillsDir) {
                return false
            }
            if let dotBase = agent.globalSkillsBase?.relativeDotPath, dotBase != ".agents",
               path.contains("/\(dotBase)/skills") || path.contains("/\(dotBase)-") {
                return false
            }
        }
        
        // Also check universal .agents/skills or .agents/
        if path.contains("/.agents/skills") || path.contains("/.agents/") {
            return false
        }
        
        // 2. Walk up parent directories to check if it lives inside a codebase repository
        var current = dir.deletingLastPathComponent()
        var foundRepoRoot: URL? = nil
        let repoIndicators = [".git", "package.json", "Package.swift", "Cargo.toml", "pyproject.toml", "go.mod", "pom.xml"]
        
        for _ in 0..<5 {
            if current.path == "/" || current.path == fileManager.homeDirectoryForCurrentUser.path {
                break
            }
            for indicator in repoIndicators {
                if fileManager.fileExists(atPath: current.appendingPathComponent(indicator).path) {
                    foundRepoRoot = current
                    break
                }
            }
            if foundRepoRoot != nil { break }
            current = current.deletingLastPathComponent()
        }
        
        guard let repo = foundRepoRoot else {
            return false
        }
        
        // If it's inside a repo and NOT in a known dot-folder agent path (like .claude/, .gemini/, .cursor/),
        // then it is a project-shipped/source skill (e.g. <repo>/skills/<name>, <repo>/plugins/<name>, or the repo itself).
        let relativeToRepo = path.replacingOccurrences(of: repo.path + "/", with: "")
        
        // If it's in a hidden dot-folder at repo root (like .claude/skills, .gemini/skills, .agents/skills),
        // that's a workspace-injected skill or agent folder, so not a shipped repo skill
        if relativeToRepo.hasPrefix(".") {
            return false
        }
        
        // Any skill residing in a project repo under non-hidden directories (e.g. `skills/`, `src/`, `templates/`, or root)
        // is considered a project-shipped skill!
        return true
    }
    
    /// Ingests a discovered skill into ~/.citadel/skills and replaces original with symlink
    public func ingest(skill: DiscoveredSkill) throws {
        let hub = HubManager.shared
        try hub.initializeHub()
        
        let dest = hub.skillsURL.appendingPathComponent(skill.name)
        
        // If not already in Citadel:
        if dest.path != skill.path.path {
            if fileManager.fileExists(atPath: dest.path) {
                try? fileManager.removeItem(at: dest)
            }
            try fileManager.copyItem(at: skill.path, to: dest)
        }
        
        // If original was not a symlink, replace original with symlink to Citadel
        if !skill.isSymlink && skill.path.path != dest.path {
            try? fileManager.removeItem(at: skill.path)
            try fileManager.createSymbolicLink(at: skill.path, withDestinationURL: dest)
        }
        
        // Ensure each ingested skill is immediately symlinked to global skills dirs across the Multiverse
        _ = try? SyncEngine.shared.syncAll()
    }
    
    private func determineKind(for url: URL) -> String {
        AgentRegistry.shared.sourceKind(for: url)
    }
    
    private func extractDescription(from markdown: String) -> String? {
        let lines = markdown.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: "description:") {
                let val = trimmed.replacingOccurrences(of: "description:", with: "").trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
                return val.isEmpty ? nil : val
            }
        }
        return nil
    }
}
