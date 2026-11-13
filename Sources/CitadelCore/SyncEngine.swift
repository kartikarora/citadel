import Foundation

public final class SyncEngine: @unchecked Sendable {
    public static let shared = SyncEngine()
    
    private let hub: HubManager
    private let fileManager = FileManager.default
    
    public init(hub: HubManager = .shared) {
        self.hub = hub
    }
    
    // MARK: - Global Multiverse Sync
    
    /// Synchronizes all skills and MCPs into active global tool configurations
    public func syncAll() throws -> SyncResult {
        var createdLinks: [String] = []
        var updatedConfigs: [String] = []
        var warnings: [String] = []
        let errors: [String] = []
        
        let skills = hub.listArmorySkills()
        let mcps = hub.listArmoryMCPs()
        let paths = UniversalPaths.shared
        
        // Global skills sync across all installed agents from AgentRegistry
        let syncTargets = AgentRegistry.shared.detectedGlobalSyncTargets(
            home: paths.home,
            xdgConfig: paths.xdgConfigRoot,
            fileManager: fileManager
        )
        for target in syncTargets {
            do {
                try fileManager.createDirectory(at: target.skillsDir, withIntermediateDirectories: true)
                for skill in skills {
                    let destination = target.skillsDir.appendingPathComponent(skill.name)
                    if link(source: skill.path, destination: destination) {
                        createdLinks.append("\(target.agent.displayName): \(skill.name)")
                    }
                }
            } catch {
                warnings.append("Could not link to \(target.agent.displayName) skills: \(error.localizedDescription)")
            }
        }
        
        // 3. Claude Desktop MCP Config (Platform-dependent)
        if FeatureFlags.shared.mcpSyncEnabled {
            let claudeDesktopDir = paths.appConfigRoot.appendingPathComponent("Claude")
            let claudeConfigFile = claudeDesktopDir.appendingPathComponent("claude_desktop_config.json")
            if fileManager.fileExists(atPath: claudeDesktopDir.path) {
                do {
                    if try injectMCPsIntoJSONFile(filePath: claudeConfigFile, mcps: mcps, rootKey: "mcpServers") {
                        updatedConfigs.append("Claude Desktop Config")
                    }
                } catch {
                    warnings.append("Claude Desktop MCP update failed: \(error.localizedDescription)")
                }
            }
        }
        
        // 4. Sync Active Project Portals
        if FeatureFlags.shared.workspacePortalsEnabled {
            let portals = hub.loadPortals()
            for portal in portals {
                if fileManager.fileExists(atPath: portal.projectPath.path) {
                    let portalResult = syncProjectPortal(portal)
                    createdLinks.append(contentsOf: portalResult.createdSymlinks)
                    updatedConfigs.append(contentsOf: portalResult.updatedConfigs)
                } else {
                    warnings.append("Portal path not found: \(portal.projectPath.path)")
                }
            }
        }
        
        return SyncResult(
            createdSymlinks: createdLinks,
            updatedConfigs: updatedConfigs,
            warnings: warnings,
            errors: errors
        )
    }
    
    // MARK: - Project Portal Sync
    
    /// Synchronizes a specific project portal
    public func syncProjectPortal(_ portal: ProjectPortal) -> SyncResult {
        var createdLinks: [String] = []
        var updatedConfigs: [String] = []
        var warnings: [String] = []
        
        let allSkills = Dictionary(uniqueKeysWithValues: hub.listArmorySkills().map { ($0.name, $0) })
        let allMCPs = Dictionary(uniqueKeysWithValues: hub.listArmoryMCPs().map { ($0.name, $0) })
        
        let selectedSkills = portal.enabledSkills.compactMap { allSkills[$0] }
        let selectedMCPs = portal.enabledMCPs.compactMap { allMCPs[$0] }
        
        var syncedDirs = Set<String>()

        // For Antigravity (.gemini/skills in repo)
        if portal.targetTools.contains(.antigravityGlobal) {
            let repoAgyDir = portal.projectPath.appendingPathComponent(".gemini/skills")
            syncSkillLinks(into: repoAgyDir, label: "\(portal.projectPath.lastPathComponent)/.gemini", selectedSkills: selectedSkills, createdLinks: &createdLinks)
            syncedDirs.insert(".gemini/skills")
        }
        
        // For Claude (.claude/skills in repo)
        if portal.targetTools.contains(.claudeCode) {
            let repoClaudeDir = portal.projectPath.appendingPathComponent(".claude/skills")
            syncSkillLinks(into: repoClaudeDir, label: "\(portal.projectPath.lastPathComponent)/.claude", selectedSkills: selectedSkills, createdLinks: &createdLinks)
            syncedDirs.insert(".claude/skills")
        }

        // Sync any existing project-level agent directories and suffixed profiles (e.g. .matilda, .claude-bilue, .agents)
        for detected in AgentRegistry.shared.detectedProjectSkillDirs(in: portal.projectPath, fileManager: fileManager) {
            let relativePath = detected.skillsDir.path.replacingOccurrences(of: portal.projectPath.path + "/", with: "")
            guard !syncedDirs.contains(relativePath) else { continue }
            syncSkillLinks(into: detected.skillsDir, label: "\(portal.projectPath.lastPathComponent)/\(detected.label)", selectedSkills: selectedSkills, createdLinks: &createdLinks)
            syncedDirs.insert(relativePath)
        }
        
        // In-repo MCP configuration (.mcp.json or similar)
        if !selectedMCPs.isEmpty {
            let repoMCPFile = portal.projectPath.appendingPathComponent(".mcp.json")
            if (try? injectMCPsIntoJSONFile(filePath: repoMCPFile, mcps: selectedMCPs, rootKey: "mcpServers")) == true {
                updatedConfigs.append("\(portal.projectPath.lastPathComponent)/.mcp.json")
            }
        }
        
        return SyncResult(createdSymlinks: createdLinks, updatedConfigs: updatedConfigs, warnings: warnings, errors: [])
    }
    
    // MARK: - Safe Symlinker & MCP Compiler

    /// Creates/prunes symlinks for `selectedSkills` inside a single project-level skills directory.
    private func syncSkillLinks(
        into targetDir: URL,
        label: String,
        selectedSkills: [Skill],
        createdLinks: inout [String]
    ) {
        guard (try? fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)) != nil else {
            return
        }
        let enabledNames = Set(selectedSkills.map { $0.name })
        if let existingItems = try? fileManager.contentsOfDirectory(at: targetDir, includingPropertiesForKeys: nil) {
            for item in existingItems where !enabledNames.contains(item.lastPathComponent) {
                try? fileManager.removeItem(at: item)
            }
        }
        for skill in selectedSkills {
            let dest = targetDir.appendingPathComponent(skill.name)
            if link(source: skill.path, destination: dest) {
                createdLinks.append("\(label): \(skill.name)")
            }
        }
    }
    
    @discardableResult
    private func link(source: URL, destination: URL) -> Bool {
        // Remove existing destination if it exists
        if fileManager.fileExists(atPath: destination.path) {
            // If already pointing to the exact target, skip
            if let destTarget = try? fileManager.destinationOfSymbolicLink(atPath: destination.path),
               destTarget == source.path {
                return false
            }
            try? fileManager.removeItem(at: destination)
        }
        
        do {
            try fileManager.createSymbolicLink(at: destination, withDestinationURL: source)
            return true
        } catch {
            return false
        }
    }
    
    private func injectMCPsIntoJSONFile(filePath: URL, mcps: [MCPServer], rootKey: String) throws -> Bool {
        var rootDict: [String: Any] = [:]
        
        if fileManager.fileExists(atPath: filePath.path),
           let data = try? Data(contentsOf: filePath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            rootDict = json
        }
        
        var mcpServersDict: [String: Any] = (rootDict[rootKey] as? [String: Any]) ?? [:]
        
        for mcp in mcps {
            var item: [String: Any] = [
                "command": mcp.command,
                "args": mcp.args
            ]
            if let env = mcp.env, !env.isEmpty {
                // Expand environment variables like ${GITHUB_TOKEN}
                var expandedEnv: [String: String] = [:]
                let processEnv = ProcessInfo.processInfo.environment
                for (k, v) in env {
                    var val = v
                    if val.hasPrefix("${") && val.hasSuffix("}") {
                        let envKey = String(val.dropFirst(2).dropLast(1))
                        val = processEnv[envKey] ?? val
                    }
                    expandedEnv[k] = val
                }
                item["env"] = expandedEnv
            }
            mcpServersDict[mcp.name] = item
        }
        
        rootDict[rootKey] = mcpServersDict
        
        let outData = try JSONSerialization.data(withJSONObject: rootDict, options: [.prettyPrinted, .sortedKeys])
        try outData.write(to: filePath)
        return true
    }
}
