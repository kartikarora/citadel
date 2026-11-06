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
        
        // 1. Antigravity Global Skills (~/.gemini/config/skills)
        let agySkillsDir = paths.home.appendingPathComponent(".gemini/config/skills")
        if fileManager.fileExists(atPath: paths.home.appendingPathComponent(".gemini").path) {
            do {
                try fileManager.createDirectory(at: agySkillsDir, withIntermediateDirectories: true)
                for skill in skills {
                    let target = agySkillsDir.appendingPathComponent(skill.name)
                    if link(source: skill.path, destination: target) {
                        createdLinks.append("Antigravity: \(skill.name)")
                    }
                }
            } catch {
                warnings.append("Could not link to Antigravity global skills: \(error.localizedDescription)")
            }
        }
        
        // 2. Claude Code CLI Skills (~/.claude/skills)
        let claudeSkillsDir = paths.home.appendingPathComponent(".claude/skills")
        if fileManager.fileExists(atPath: paths.home.appendingPathComponent(".claude").path) {
            do {
                try fileManager.createDirectory(at: claudeSkillsDir, withIntermediateDirectories: true)
                for skill in skills {
                    let target = claudeSkillsDir.appendingPathComponent(skill.name)
                    if link(source: skill.path, destination: target) {
                        createdLinks.append("Claude Code: \(skill.name)")
                    }
                }
            } catch {
                warnings.append("Could not link to Claude Code skills: \(error.localizedDescription)")
            }
        }
        
        // 3. Android Studio Skills (~/.android-studio/skills)
        let androidStudioSkillsDir = paths.home.appendingPathComponent(".android-studio/skills")
        if fileManager.fileExists(atPath: paths.home.appendingPathComponent(".android-studio").path) {
            do {
                try fileManager.createDirectory(at: androidStudioSkillsDir, withIntermediateDirectories: true)
                for skill in skills {
                    let target = androidStudioSkillsDir.appendingPathComponent(skill.name)
                    if link(source: skill.path, destination: target) {
                        createdLinks.append("Android Studio: \(skill.name)")
                    }
                }
            } catch {
                warnings.append("Could not link to Android Studio skills: \(error.localizedDescription)")
            }
        }
        
        // 4. GitHub Copilot Skills (~/.copilot/skills)
        let copilotSkillsDir = paths.home.appendingPathComponent(".copilot/skills")
        if fileManager.fileExists(atPath: paths.home.appendingPathComponent(".copilot").path) {
            do {
                try fileManager.createDirectory(at: copilotSkillsDir, withIntermediateDirectories: true)
                for skill in skills {
                    let target = copilotSkillsDir.appendingPathComponent(skill.name)
                    if link(source: skill.path, destination: target) {
                        createdLinks.append("GitHub Copilot: \(skill.name)")
                    }
                }
            } catch {
                warnings.append("Could not link to GitHub Copilot skills: \(error.localizedDescription)")
            }
        }
        
        // 5. Junie Skills (~/.junie/skills)
        let junieSkillsDir = paths.home.appendingPathComponent(".junie/skills")
        if fileManager.fileExists(atPath: paths.home.appendingPathComponent(".junie").path) {
            do {
                try fileManager.createDirectory(at: junieSkillsDir, withIntermediateDirectories: true)
                for skill in skills {
                    let target = junieSkillsDir.appendingPathComponent(skill.name)
                    if link(source: skill.path, destination: target) {
                        createdLinks.append("Junie: \(skill.name)")
                    }
                }
            } catch {
                warnings.append("Could not link to Junie skills: \(error.localizedDescription)")
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
        
        // For Antigravity (.gemini/skills in repo)
        if portal.targetTools.contains(.antigravityGlobal) {
            let repoAgyDir = portal.projectPath.appendingPathComponent(".gemini/skills")
            if (try? fileManager.createDirectory(at: repoAgyDir, withIntermediateDirectories: true)) != nil {
                for skill in selectedSkills {
                    let dest = repoAgyDir.appendingPathComponent(skill.name)
                    if link(source: skill.path, destination: dest) {
                        createdLinks.append("\(portal.projectPath.lastPathComponent)/.gemini: \(skill.name)")
                    }
                }
            }
        }
        
        // For Claude (.claude/skills in repo)
        if portal.targetTools.contains(.claudeCode) {
            let repoClaudeDir = portal.projectPath.appendingPathComponent(".claude/skills")
            if (try? fileManager.createDirectory(at: repoClaudeDir, withIntermediateDirectories: true)) != nil {
                for skill in selectedSkills {
                    let dest = repoClaudeDir.appendingPathComponent(skill.name)
                    if link(source: skill.path, destination: dest) {
                        createdLinks.append("\(portal.projectPath.lastPathComponent)/.claude: \(skill.name)")
                    }
                }
            }
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
