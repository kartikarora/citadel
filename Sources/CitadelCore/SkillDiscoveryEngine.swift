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
        return [
            home.appendingPathComponent(".agents"),
            home.appendingPathComponent(".gemini"),
            home.appendingPathComponent(".claude"),
            home.appendingPathComponent(".cursor"),
            home.appendingPathComponent(".windsurf"),
            home.appendingPathComponent(".cline"),
            home.appendingPathComponent(".roo"),
            home.appendingPathComponent(".codex"),
            home.appendingPathComponent(".continue"),
            home.appendingPathComponent(".codeium"),
            home.appendingPathComponent(".android-studio"),
            home.appendingPathComponent(".copilot"),
            home.appendingPathComponent(".junie"),
            home.appendingPathComponent(".config"),
            home.appendingPathComponent("Projects"),
            home.appendingPathComponent("Developer"),
            home.appendingPathComponent("Development"),
            home.appendingPathComponent("Workspace"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("src"),
            home.appendingPathComponent("code")
        ].filter { fileManager.fileExists(atPath: $0.path) }
    }
    
    /// Recursively scans search roots for any folder containing a `SKILL.md`
    public func discoverSkills(in roots: [URL]? = nil, maxDepth: Int = 5, includeBuiltin: Bool = false) -> [DiscoveredSkill] {
        let targets = roots ?? defaultScanRoots
        var results: [DiscoveredSkill] = []
        var visitedPaths = Set<String>()
        
        for root in targets {
            scanDirectory(root, currentDepth: 0, maxDepth: maxDepth, includeBuiltin: includeBuiltin, results: &results, visitedPaths: &visitedPaths)
        }
        
        return results.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
    
    private func scanDirectory(_ dir: URL, currentDepth: Int, maxDepth: Int, includeBuiltin: Bool, results: inout [DiscoveredSkill], visitedPaths: inout Set<String>) {
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
                scanDirectory(sub, currentDepth: currentDepth + 1, maxDepth: maxDepth, includeBuiltin: includeBuiltin, results: &results, visitedPaths: &visitedPaths)
            }
        }
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
    }
    
    private func determineKind(for url: URL) -> String {
        let p = url.path
        if p.contains("/.agents/") { return "agents" }
        if p.contains("/plugins/") { return "plugin" }
        if p.contains("/builtin/") { return "builtin" }
        if p.contains("/.android-studio/") { return "android-studio" }
        if p.contains("/.copilot/") { return "copilot" }
        if p.contains("/.junie/") { return "junie" }
        if p.contains("/.claude/") { return "claude" }
        if p.contains("/.cursor/") { return "cursor" }
        if p.contains("/.windsurf/") { return "windsurf" }
        if p.contains("/.cline/") { return "cline" }
        if p.contains("/.roo/") { return "roo" }
        if p.contains("/.codex/") { return "codex" }
        if p.contains("/.continue/") { return "continue" }
        if p.contains("/Projects/") || p.contains("/Developer/") || p.contains("/Development/") || p.contains("/Workspace/") { return "workspace" }
        return "custom"
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
