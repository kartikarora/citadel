import Foundation

public struct DiscoveredMCP: Identifiable, Sendable {
    public var id: String { "\(name)@\(foundInPath.path)" }
    public let name: String
    public let command: String
    public let args: [String]
    public let env: [String: String]?
    public let foundInPath: URL
    public let clientName: String
    
    public init(name: String, command: String, args: [String], env: [String: String]? = nil, foundInPath: URL, clientName: String) {
        self.name = name
        self.command = command
        self.args = args
        self.env = env
        self.foundInPath = foundInPath
        self.clientName = clientName
    }
}

public struct DiscoveredWorkspace: Identifiable, Sendable {
    public var id: String { path.path }
    public let name: String
    public let path: URL
    public let hasGemini: Bool
    public let hasClaude: Bool
    public let hasCursor: Bool
    public let isAlreadyPortal: Bool
    
    public init(name: String, path: URL, hasGemini: Bool, hasClaude: Bool, hasCursor: Bool, isAlreadyPortal: Bool) {
        self.name = name
        self.path = path
        self.hasGemini = hasGemini
        self.hasClaude = hasClaude
        self.hasCursor = hasCursor
        self.isAlreadyPortal = isAlreadyPortal
    }
}

public struct MultiverseDiscoveryReport: Sendable {
    public let skills: [DiscoveredSkill]
    public let mcps: [DiscoveredMCP]
    public let workspaces: [DiscoveredWorkspace]
    
    public init(skills: [DiscoveredSkill] = [], mcps: [DiscoveredMCP] = [], workspaces: [DiscoveredWorkspace] = []) {
        self.skills = skills
        self.mcps = mcps
        self.workspaces = workspaces
    }
}

public final class MultiverseDiscoveryEngine: @unchecked Sendable {
    public static let shared = MultiverseDiscoveryEngine()
    
    private let fileManager = FileManager.default
    private let paths = UniversalPaths.shared
    
    /// Runs a full discovery pass across skills, MCP servers, and workspaces (Synchronous)
    public func runFullDiscovery(skillRoots: [URL]? = nil, workspaceRoots: [URL]? = nil) -> MultiverseDiscoveryReport {
        let scanRoots = skillRoots ?? paths.knownClientRoots
        let skills = SkillDiscoveryEngine.shared.discoverSkills(in: scanRoots)
        let mcps = discoverMCPServers()
        let workspaces = discoverWorkspaces(searchRoots: workspaceRoots ?? paths.defaultWorkspaceRoots)
        return MultiverseDiscoveryReport(skills: skills, mcps: mcps, workspaces: workspaces)
    }
    
    /// Runs a full discovery pass completely off the main thread with progressive streaming callbacks
    public func runFullDiscoveryAsync(
        skillRoots: [URL]? = nil,
        workspaceRoots: [URL]? = nil,
        onPartialUpdate: (@Sendable (MultiverseDiscoveryReport) -> Void)? = nil
    ) async -> MultiverseDiscoveryReport {
        return await Task.detached(priority: .userInitiated) { [weak self] () -> MultiverseDiscoveryReport in
            guard let self = self else { return MultiverseDiscoveryReport() }
            
            // 1. Fast MCP discovery (reads specific json config files only - takes ~5ms)
            let mcps = self.discoverMCPServers()
            onPartialUpdate?(MultiverseDiscoveryReport(skills: [], mcps: mcps, workspaces: []))
            
            // 2. Client skills discovery
            let scanRoots = skillRoots ?? self.paths.knownClientRoots
            let skills = SkillDiscoveryEngine.shared.discoverSkills(in: scanRoots)
            onPartialUpdate?(MultiverseDiscoveryReport(skills: skills, mcps: mcps, workspaces: []))
            
            // 3. Workspace discovery
            let workspaces = self.discoverWorkspaces(searchRoots: workspaceRoots ?? self.paths.defaultWorkspaceRoots)
            let finalReport = MultiverseDiscoveryReport(skills: skills, mcps: mcps, workspaces: workspaces)
            onPartialUpdate?(finalReport)
            
            return finalReport
        }.value
    }
    
    
    // MARK: - Portable MCP Discovery
    
    public func discoverMCPServers() -> [DiscoveredMCP] {
        var results: [DiscoveredMCP] = []
        
        let candidateFiles: [(URL, String)] = [
            (paths.home.appendingPathComponent(".gemini/config/mcp_config.json"), "Antigravity"),
            (paths.home.appendingPathComponent(".claude.json"), "Claude Code"),
            (paths.appConfigRoot.appendingPathComponent("Claude/claude_desktop_config.json"), "Claude Desktop"),
            (paths.home.appendingPathComponent(".cursor/mcp.json"), "Cursor"),
            (paths.appConfigRoot.appendingPathComponent("Cursor/mcp.json"), "Cursor"),
            (paths.home.appendingPathComponent(".config/github-copilot/intellij/mcp.json"), "GitHub Copilot")
        ]
        
        for (fileURL, client) in candidateFiles {
            guard fileManager.fileExists(atPath: fileURL.path),
                  let data = try? Data(contentsOf: fileURL),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            
            let serversDict = (json["mcpServers"] as? [String: Any]) ?? (json["servers"] as? [String: Any]) ?? [:]
            for (serverName, val) in serversDict {
                guard let config = val as? [String: Any],
                      let cmd = config["command"] as? String else {
                    continue
                }
                let args = (config["args"] as? [String]) ?? []
                let env = config["env"] as? [String: String]
                results.append(DiscoveredMCP(name: serverName, command: cmd, args: args, env: env, foundInPath: fileURL, clientName: client))
            }
        }
        
        // Dynamic scan of ~/.gemini/antigravity/mcp directory if present
        let agyMcpDir = paths.home.appendingPathComponent(".gemini/antigravity/mcp")
        if let subdirs = try? fileManager.contentsOfDirectory(at: agyMcpDir, includingPropertiesForKeys: nil) {
            for sub in subdirs {
                let name = sub.lastPathComponent
                if !name.hasPrefix(".") && !results.contains(where: { $0.name == name }) {
                    results.append(DiscoveredMCP(name: name, command: "builtin", args: [], env: nil, foundInPath: sub, clientName: "Antigravity"))
                }
            }
        }
        
        return results.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
    
    // MARK: - Portable Workspace Discovery
    
    public func discoverWorkspaces(searchRoots: [URL]) -> [DiscoveredWorkspace] {
        var results: [DiscoveredWorkspace] = []
        let existingPortals = Set(HubManager.shared.loadPortals().map { $0.projectPath.path })
        var visited = Set<String>()
        
        for root in searchRoots {
            guard fileManager.fileExists(atPath: root.path) else { continue }
            
            // Check if root itself is a git repository
            if fileManager.fileExists(atPath: root.appendingPathComponent(".git").path) {
                appendWorkspace(at: root, existingPortals: existingPortals, results: &results, visited: &visited)
                continue
            }
            
            // Otherwise scan immediate children
            guard let children = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
                continue
            }
            
            for child in children {
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: child.path, isDirectory: &isDir), isDir.boolValue {
                    if fileManager.fileExists(atPath: child.appendingPathComponent(".git").path) {
                        appendWorkspace(at: child, existingPortals: existingPortals, results: &results, visited: &visited)
                    }
                }
            }
        }
        
        return results.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
    
    private func appendWorkspace(at url: URL, existingPortals: Set<String>, results: inout [DiscoveredWorkspace], visited: inout Set<String>) {
        if visited.contains(url.path) { return }
        visited.insert(url.path)
        
        let hasGemini = fileManager.fileExists(atPath: url.appendingPathComponent(".gemini").path)
        let hasClaude = fileManager.fileExists(atPath: url.appendingPathComponent(".claude").path)
        let hasCursor = fileManager.fileExists(atPath: url.appendingPathComponent(".cursor").path)
        let isPortal = existingPortals.contains(url.path)
        
        results.append(DiscoveredWorkspace(
            name: url.lastPathComponent,
            path: url,
            hasGemini: hasGemini,
            hasClaude: hasClaude,
            hasCursor: hasCursor,
            isAlreadyPortal: isPortal
        ))
    }
    
    // MARK: - Ingestion
    
    public func ingestMCP(_ mcp: DiscoveredMCP) throws {
        let server = MCPServer(name: mcp.name, command: mcp.command, args: mcp.args, env: mcp.env)
        try HubManager.shared.saveMCP(server)
    }
    
    public func connectWorkspaceAsPortal(_ ws: DiscoveredWorkspace) throws {
        var portals = HubManager.shared.loadPortals()
        let allSkills = HubManager.shared.listArmorySkills().map { $0.name }
        let allMCPs = HubManager.shared.listArmoryMCPs().map { $0.name }
        
        if let idx = portals.firstIndex(where: { $0.projectPath.path == ws.path.path }) {
            portals[idx].enabledSkills = allSkills
            portals[idx].enabledMCPs = allMCPs
        } else {
            portals.append(ProjectPortal(projectPath: ws.path, enabledSkills: allSkills, enabledMCPs: allMCPs))
        }
        
        try HubManager.shared.savePortals(portals)
    }
}
