import Foundation
import ArgumentParser

@available(macOS 14.0, *)
public struct CitadelCLI: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "citadel",
        abstract: "The Council of Skills & MCPs: Bringing order to an unruly multiverse of AI tools.",
        subcommands: [
            InitCommand.self,
            SyncCommand.self,
            ListCommand.self,
            DiscoverCommand.self,
            IngestCommand.self,
            UnifyCommand.self,
            RemoteCommand.self,
            AuthCommand.self,
            PortalCommand.self,
            AddCommand.self,
            SearchCommand.self,
            InstallCommand.self,
            RemoveCommand.self,
            PushCommand.self,
            PullCommand.self,
            StatusCommand.self,
            DocsCommand.self,
            AppCommand.self
        ],
        defaultSubcommand: ListCommand.self
    )
    
    public init() {}
}

// MARK: - Subcommands

struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "init", abstract: "Initialize the central ~/.citadel repository.")
    
    func run() throws {
        let hub = HubManager.shared
        print("🌌 Initializing the Citadel at \(hub.hubURL.path)...")
        try hub.initializeHub()
        print("✅ Citadel initialized.")
        print("   Skills: \(hub.skillsURL.path)")
        print("   MCPs:   \(hub.mcpsURL.path)")
    }
}

struct SyncCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "sync", abstract: "Synchronize all skills & MCPs across all AI dimensions.")
    
    func run() throws {
        print("🌀 Opening the portals and syncing across the Multiverse...")
        let result = try SyncEngine.shared.syncAll()
        
        let hub = HubManager.shared
        _ = hub.gitCommit(message: "chore(sync): synchronize skills and portals")
        
        if result.createdSymlinks.isEmpty && result.updatedConfigs.isEmpty && result.warnings.isEmpty {
            print("✨ Everything is already in sync with the Citadel.")
            return
        }
        
        for link in result.createdSymlinks {
            print("  🟢 Linked: \(link)")
        }
        for config in result.updatedConfigs {
            print("  ⚡ Config updated: \(config)")
        }
        for warn in result.warnings {
            print("  ⚠️  Notice: \(warn)")
        }
        print("🚀 Sync complete!")
    }
}

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List all skills, MCPs, and active project portals.")
    
    func run() throws {
        let hub = HubManager.shared
        let skills = hub.listArmorySkills()
        let mcps = hub.listArmoryMCPs()
        let portals = hub.loadPortals()
        
        print("🏰 THE CITADEL ARMORY")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📦 SKILLS (\(skills.count)):")
        if skills.isEmpty {
            print("   (No skills found in ~/.citadel/skills/)")
        } else {
            for skill in skills {
                let desc = skill.description != nil ? " - \(skill.description!)" : ""
                print("   • \(skill.name)\(desc)")
            }
        }
        
        print("\n🔌 MCP SERVERS (\(mcps.count)):")
        if mcps.isEmpty {
            print("   (No MCPs registered in ~/.citadel/mcps/)")
        } else {
            for mcp in mcps {
                print("   • \(mcp.name) [\(mcp.command) \(mcp.args.joined(separator: " "))]")
            }
        }
        
        print("\n🚪 PROJECT PORTALS (\(portals.count)):")
        if portals.isEmpty {
            print("   (No active project portals)")
        } else {
            for portal in portals {
                print("   • \(portal.projectPath.path) (\(portal.enabledSkills.count) skills, \(portal.enabledMCPs.count) MCPs)")
            }
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
}

struct DiscoverCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "discover", abstract: "Scan filesystem to discover scattered skills, MCP servers, and workspaces.")
    
    @Argument(help: "Custom directory to scan for workspaces (optional, defaults to ~/Projects)")
    var workspacePath: String?
    
    func run() throws {
        print("🔍 Scanning your system across all AI dimensions...")
        let roots = workspacePath != nil ? [URL(fileURLWithPath: workspacePath!)] : nil
        let report = MultiverseDiscoveryEngine.shared.runFullDiscovery(workspaceRoots: roots)
        
        // 1. Skills
        print("\n📦 DISCOVERED SKILLS (\(report.skills.count)):")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        if report.skills.isEmpty {
            print("  (No external skills found)")
        } else {
            for s in report.skills {
                let tag = s.isSymlink ? " [symlink]" : ""
                print("  • \(s.name) (\(s.sourceKind))\(tag) -> \(s.path.path)")
            }
        }
        
        // 2. MCP Servers
        print("\n🔌 DISCOVERED MCP SERVERS (\(report.mcps.count)):")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        if report.mcps.isEmpty {
            print("  (No external MCP servers found)")
        } else {
            for m in report.mcps {
                print("  • \(m.name) [from \(m.clientName)] -> \(m.command) \(m.args.joined(separator: " "))")
                print("    Source: \(m.foundInPath.path)")
            }
        }
        
        // 3. Workspaces
        print("\n📁 DISCOVERED WORKSPACES (\(report.workspaces.count)):")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        if report.workspaces.isEmpty {
            print("  (No git workspaces found in ~/Projects)")
        } else {
            for w in report.workspaces {
                let pTag = w.isAlreadyPortal ? " [connected portal]" : ""
                var tools: [String] = []
                if w.hasGemini { tools.append(".gemini") }
                if w.hasClaude { tools.append(".claude") }
                if w.hasCursor { tools.append(".cursor") }
                let toolsStr = tools.isEmpty ? "no AI configs" : tools.joined(separator: ", ")
                print("  • \(w.name) (\(toolsStr))\(pTag) -> \(w.path.path)")
            }
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("💡 Run 'ctdl ingest' to interactively review and approve importing these into ~/.citadel.")
    }
}

struct IngestCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "ingest", abstract: "Import discovered skills and MCP servers into ~/.citadel with user permission.")
    
    @Flag(name: .shortAndLong, help: "Automatic yes to prompt (skip interactive confirmation)")
    var yes: Bool = false
    
    @Option(name: .shortAndLong, help: "Filter kind: 'skills', 'mcps', or 'all'")
    var kind: String = "all"
    
    func run() throws {
        let engine = MultiverseDiscoveryEngine.shared
        let report = engine.runFullDiscovery()
        
        let skillsToIngest = (kind == "mcps") ? [] : report.skills.filter { !$0.isSymlink }
        let mcpsToIngest = (kind == "skills") ? [] : report.mcps
        
        if skillsToIngest.isEmpty && mcpsToIngest.isEmpty {
            print("✨ Nothing new to ingest. All items are already managed by Citadel.")
            return
        }
        
        print("\n📋 INGESTION PLAN (Items to be unified into ~/.citadel):")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        if !skillsToIngest.isEmpty {
            print("📦 Skills to import & symlink (\(skillsToIngest.count)):")
            for s in skillsToIngest {
                print("   + \(s.name) (\(s.path.path))")
            }
        }
        if !mcpsToIngest.isEmpty {
            print("\n🔌 MCP Servers to register (\(mcpsToIngest.count)):")
            for m in mcpsToIngest {
                print("   + \(m.name) (\(m.clientName): \(m.command))")
            }
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("⚠️  PERMISSION REQUEST:")
        print("   This will copy the configurations into ~/.citadel and create symlinks")
        print("   at their original paths so all tools share the same canonical source.")
        
        if !yes {
            print("\nDo you approve these changes? [y/N]: ", terminator: "")
            guard let response = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                  response == "y" || response == "yes" else {
                print("❌ Ingestion canceled by user. No files were modified.")
                return
            }
        }
        
        print("\n🚀 Executing approved ingestion plan...")
        
        // Ingest skills
        for s in skillsToIngest {
            try? SkillDiscoveryEngine.shared.ingest(skill: s)
        }
        
        // Ingest MCPs
        for m in mcpsToIngest {
            try? engine.ingestMCP(m)
        }
        
        // Multiverse sync
        let res = try SyncEngine.shared.syncAll()
        print("✅ Ingestion complete!")
        print("   Created \(res.createdSymlinks.count) symlinks and updated \(res.updatedConfigs.count) tool configs.")
        print("   All changes committed to Git in ~/.citadel.")
    }
}

struct UnifyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "unify", abstract: "Group duplicate skill occurrences across multiple locations and unify into symlinks.")
    
    @Flag(name: .shortAndLong, help: "Unify all multi-location skill groups")
    var all: Bool = false
    
    @Argument(help: "Specific skill name to unify across its locations")
    var skillName: String?
    
    func run() throws {
        let skills = SkillDiscoveryEngine.shared.discoverSkills()
        let groups = SkillGroupManager.shared.groupDiscoveredSkills(skills)
        let multiLocationGroups = groups.filter { $0.occurrences.count > 1 }
        
        if multiLocationGroups.isEmpty {
            print("✨ No scattered duplicate skills found across your system.")
            return
        }
        
        print("\n📦 MULTI-LOCATION SKILL GROUPS:")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        for g in multiLocationGroups {
            let status = g.isFullyUnified ? " [unified]" : " [divergent]"
            print("• \(g.name) (\(g.occurrences.count) locations)\(status)")
            for occ in g.occurrences {
                let tag = occ.isSymlink ? "symlink" : "real copy"
                print("    - [\(tag)] \(occ.path.path)")
            }
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        if all {
            print("🌀 Unifying all divergent skill groups into ~/.citadel/skills...")
            var totalUnified = 0
            for g in multiLocationGroups {
                let count = (try? SkillGroupManager.shared.unifyGroup(g)) ?? 0
                totalUnified += count
            }
            _ = try SyncEngine.shared.syncAll()
            print("✅ Unified \(totalUnified) scattered locations into shared symlinks!")
        } else if let name = skillName {
            guard let group = multiLocationGroups.first(where: { $0.name == name }) else {
                print("❌ No multi-location skill group named '\(name)'")
                return
            }
            let count = try SkillGroupManager.shared.unifyGroup(group)
            _ = try SyncEngine.shared.syncAll()
            print("✅ Unified \(count) locations for '\(name)'. All tools now point to ~/.citadel/skills/\(name).")
        } else {
            print("💡 Run 'ctdl unify --all' to unify all duplicate skills into shared symlinks.")
        }
    }
}

struct RemoteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "remote", abstract: "Manage Git remote repository for multi-device sync.")
    
    @Argument(help: "Subaction: 'get', 'set <url>', 'push', or 'pull'")
    var action: String = "status"
    
    @Argument(help: "Remote Git URL (used with 'set')")
    var url: String?
    
    func run() throws {
        let manager = RemoteSyncManager.shared
        
        if action == "set" {
            guard let remoteURL = url else {
                print("Usage: ctdl remote set <git-url>")
                return
            }
            let res = manager.setRemoteURL(remoteURL)
            if res.success {
                print("✅ Configured remote origin: \(remoteURL)")
            } else {
                print("❌ Failed: \(res.error ?? "unknown error")")
            }
        } else if action == "push" {
            print("🚀 Pushing Citadel to remote...")
            let res = manager.push()
            print(res.success ? "✅ \(res.message)" : "⚠️ \(res.message)")
        } else if action == "pull" {
            print("📥 Pulling Citadel from remote...")
            let res = try manager.pull()
            print(res.success ? "✅ \(res.message)" : "⚠️ \(res.message)")
        } else {
            let status = manager.getStatus()
            print("🏰 CITADEL REMOTE SYNC STATUS")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            if let remote = status.remoteURL {
                print("Remote URL: \(remote)")
                print("Branch:     \(status.currentBranch)")
                print("State:      \(status.hasUncommittedChanges ? "🟡 Local modifications pending" : "🟢 Clean")")
            } else {
                print("Remote:     None configured")
                print("💡 Run 'ctdl remote set <url>' to connect a private GitHub repository.")
            }
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }
    }
}

struct AuthCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "auth", abstract: "Manage optional GitHub/GitLab authentication for multi-device sync.")
    
    @Argument(help: "Action: 'status', 'login <provider>', or 'logout <provider>'")
    var action: String = "status"
    
    @Argument(help: "Provider: 'github' or 'gitlab'")
    var provider: String?
    
    @Option(name: .shortAndLong, help: "Personal Access Token (with repo scope)")
    var token: String?
    
    func run() async throws {
        let auth = GitAuthProvider.shared
        let prov: GitProvider = (provider?.lowercased() == "gitlab") ? .gitlab : .github
        
        if action == "login" {
            var tok = token
            if tok == nil {
                print("Enter your \(prov.rawValue) Personal Access Token (PAT with 'repo' scope): ", terminator: "")
                tok = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            guard let validToken = tok, !validToken.isEmpty else {
                print("❌ No token provided.")
                return
            }
            
            _ = auth.saveToken(validToken, for: prov)
            print("🔐 Token securely saved to macOS Keychain.")
            
            if let user = await auth.getAuthenticatedUser(for: prov) {
                print("✅ Signed in as @\(user.username) (\(prov.rawValue)).")
                
                let repoCheck = await auth.checkRepoExists(provider: prov, repoName: "citadel-sync")
                if repoCheck.exists, let cloneURL = repoCheck.cloneURL {
                    _ = RemoteSyncManager.shared.setRemoteURL(cloneURL)
                    print("🔗 Connected to existing repository: \(cloneURL)")
                    print("💡 Run 'ctdl remote push' or 'ctdl remote pull' to sync.")
                } else {
                    print("\n⚠️  No existing repository 'citadel-sync' found on your \(prov.rawValue) account.")
                    print("Would you like Citadel to create a new private repository 'citadel-sync' on @\(user.username)? [y/N]: ", terminator: "")
                    let ans = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if ans == "y" || ans == "yes" {
                        do {
                            let cloneURL = try await auth.createPrivateRepo(provider: prov, repoName: "citadel-sync")
                            print("🚀 Created and linked private repository: \(cloneURL)")
                            print("💡 Run 'ctdl remote push' to back up your hub.")
                        } catch {
                            print("❌ Repository creation failed: \(error.localizedDescription)")
                        }
                    } else {
                        print("ℹ️  No remote repository created. You can link any existing repository anytime using:")
                        print("   ctdl remote set <git-url>")
                    }
                }
            } else {
                print("❌ Invalid token. Authentication failed.")
                auth.deleteToken(for: prov)
            }
        } else if action == "logout" {
            auth.deleteToken(for: prov)
            print("✅ Signed out from \(prov.rawValue). Token removed from Keychain.")
        } else {
            // Status
            print("🔐 CITADEL AUTHENTICATION (Optional Cloud Sync)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            let ghUser = await auth.getAuthenticatedUser(for: .github)
            let glUser = await auth.getAuthenticatedUser(for: .gitlab)
            
            print("GitHub: " + (ghUser != nil ? "✅ Signed in as @\(ghUser!.username)" : "Not signed in"))
            print("GitLab: " + (glUser != nil ? "✅ Signed in as @\(glUser!.username)" : "Not signed in"))
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            if ghUser == nil && glUser == nil {
                print("💡 Run 'ctdl auth login github' to sign in and auto-sync across your Macs.")
            }
        }
    }
}

struct PortalCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "portal", abstract: "Open a portal to inject skills into a project workspace.")
    
    @Argument(help: "Target project directory path (defaults to current directory)")
    var path: String?
    
    func run() throws {
        let currentDir = path != nil ? URL(fileURLWithPath: path!) : URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        print("🌀 Opening portal to project: \(currentDir.path)")
        
        var portals = HubManager.shared.loadPortals()
        let allSkills = HubManager.shared.listArmorySkills().map { $0.name }
        let allMCPs = HubManager.shared.listArmoryMCPs().map { $0.name }
        
        if let idx = portals.firstIndex(where: { $0.projectPath.path == currentDir.path }) {
            portals[idx].enabledSkills = allSkills
            portals[idx].enabledMCPs = allMCPs
        } else {
            let newPortal = ProjectPortal(projectPath: currentDir, enabledSkills: allSkills, enabledMCPs: allMCPs)
            portals.append(newPortal)
        }
        
        try HubManager.shared.savePortals(portals)
        let result = try SyncEngine.shared.syncAll()
        for link in result.createdSymlinks {
            print("  🟢 Linked: \(link)")
        }
        print("✅ Portal opened! Project is now synced with the Citadel.")
    }
}

struct AddCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add", abstract: "Add a skill or MCP server to the Citadel.")
    
    @Argument(help: "Type to add: 'skill' or 'mcp'")
    var kind: String
    
    @Argument(help: "Path to skill directory or MCP server name")
    var target: String
    
    func run() throws {
        let hub = HubManager.shared
        try hub.initializeHub()
        
        if kind.lowercased() == "skill" {
            let source = URL(fileURLWithPath: target)
            guard FileManager.default.fileExists(atPath: source.path) else {
                print("❌ Source directory does not exist: \(target)")
                return
            }
            let name = source.lastPathComponent
            let dest = hub.skillsURL.appendingPathComponent(name)
            
            if FileManager.default.fileExists(atPath: dest.path) {
                try? FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: source, to: dest)
            print("✅ Skill '\(name)' added to Citadel Armory.")
        } else if kind.lowercased() == "mcp" {
            let server = MCPServer(name: target, command: "npx", args: ["-y", target])
            try hub.saveMCP(server)
            print("✅ MCP '\(target)' registered in Citadel Armory.")
        }
        
        print("💡 Run 'citadel sync' to beam it across your tools.")
    }
}

struct SearchCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "search", abstract: "Search npm for community agent skill packages (installable via NPX).")
    
    @Argument(help: "Keyword search query (defaults to 'skills')")
    var query: String?
    
    func run() async throws {
        let q = query ?? "skills"
        print("🔍 Searching npm for skills matching '\(q)'...")
        let packages = try await NPMRegistry.shared.searchSkills(query: query)
        if packages.isEmpty {
            print("No packages found on npm for query: '\(q)'")
            return
        }
        
        print("\n✨ FOUND \(packages.count) PACKAGES ON NPM:")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        for pkg in packages {
            let author = pkg.publisher != nil ? " by @\(pkg.publisher!)" : ""
            print("📦 \(pkg.name) (v\(pkg.version))\(author)")
            if let desc = pkg.description {
                print("   \(desc)")
            }
            print("   👉 Install with: ctdl install \(pkg.name)\n")
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
}

struct InstallCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install", abstract: "Install a skill package via background NPX and link it into all AI tools.")
    
    @Argument(help: "Package name or specifier on npm (e.g. 'vercel-labs/agent-skills' or '@user/skill')")
    var packageName: String
    
    func run() async throws {
        print("📥 Installing '\(packageName)' via NPX...")
        let installedFolder = try await NPMRegistry.shared.install(packageSpec: packageName)
        print("✅ Installed '\(installedFolder)' into ~/.citadel/skills/\(installedFolder)")
        print("🚀 Automatically propagated and linked across Antigravity, Claude, and active workspaces!")
    }
}

struct RemoveCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "remove", abstract: "Remove an installed skill package via background NPX and clean up all symlinks.")
    
    @Argument(help: "Name of the skill to remove (e.g. 'web-design-guidelines')")
    var skillName: String
    
    func run() async throws {
        print("🗑️ Removing '\(skillName)' via NPX...")
        try await NPMRegistry.shared.remove(skillName: skillName)
        print("✅ Removed '\(skillName)' from ~/.citadel/skills and cleaned up AI tool links.")
    }
}

struct PushCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "push", abstract: "Push ~/.citadel hub changes to remote git repository.")
    
    @Option(name: .shortAndLong, help: "Git remote (default: origin)")
    var remote: String = "origin"
    
    @Option(name: .shortAndLong, help: "Git branch (default: main)")
    var branch: String = "main"
    
    func run() throws {
        print("🚀 Pushing Citadel to remote (\(remote)/\(branch))...")
        let hub = HubManager.shared
        hub.gitCommit(message: "chore: update Citadel armory and portals")
        let res = hub.gitPush(remote: remote, branch: branch)
        if res.success {
            print("✅ Citadel successfully backed up to remote.")
        } else {
            print("⚠️ Push output: \(res.output)")
        }
    }
}

struct PullCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "pull", abstract: "Pull changes from remote git repository and re-sync across all AI tools.")
    
    @Option(name: .shortAndLong, help: "Git remote (default: origin)")
    var remote: String = "origin"
    
    @Option(name: .shortAndLong, help: "Git branch (default: main)")
    var branch: String = "main"
    
    func run() throws {
        print("📥 Pulling latest Citadel updates from remote (\(remote)/\(branch))...")
        let hub = HubManager.shared
        let res = hub.gitPull(remote: remote, branch: branch)
        if res.success {
            print("✅ Pulled latest changes.")
            print("🌀 Triggering automatic Multiverse sync...")
            _ = try SyncEngine.shared.syncAll()
            print("🚀 Everything is up to date!")
        } else {
            print("⚠️ Pull output: \(res.output)")
        }
    }
}

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status", abstract: "Show git status and synchronization state of the Citadel hub.")
    
    func run() throws {
        let hub = HubManager.shared
        print("🏰 Citadel Hub: \(hub.hubURL.path)")
        let diff = hub.gitStatus().trimmingCharacters(in: .whitespacesAndNewlines)
        if diff.isEmpty {
            print("✅ Git working tree clean. All local modifications committed.")
        } else {
            print("🟡 Uncommitted changes in ~/.citadel:")
            print(diff)
        }
    }
}

struct DocsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "docs", abstract: "Open the Citadel documentation web page in your default browser.")
    
    func run() throws {
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let docsFile = currentDir.appendingPathComponent("docs/index.html")
        let targetURL = FileManager.default.fileExists(atPath: docsFile.path) ? docsFile : URL(string: "https://citadel-ai.dev")!
        
        print("🌐 Opening Citadel Docs: \(targetURL.path)...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [targetURL.path]
        try? process.run()
    }
}

struct AppCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "app",
        abstract: "Launch the native macOS Citadel frontend, or download and install the DMG bundle."
    )
    
    @Flag(name: [.customShort("i"), .customLong("install")], help: "Download and install the latest Citadel.app DMG release if not already installed.")
    var install: Bool = false
    
    func run() throws {
        let appPaths = [
            "/Applications/Citadel.app",
            CitadelUtils.expandTildePath("~/Applications/Citadel.app")
        ]
        
        let existingApp = appPaths.first { FileManager.default.fileExists(atPath: $0) }
        
        if let app = existingApp {
            print("🚀 Launching native Citadel UI from \(app)...")
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            proc.arguments = [app]
            try? proc.run()
            return
        }
        
        if !install {
            print("🏰 Citadel is primarily a native macOS frontend application.")
            print("⚠️  Citadel.app is not currently installed in /Applications.")
            print("\nTo automatically download and install the latest DMG frontend release, run:")
            print("   citadel app --install")
            print("\nOr download directly from: https://citadel.kartikarora.me/#downloads")
            return
        }
        
        print("📦 Downloading latest Citadel macOS DMG release from GitHub...")
        let tempDMG = FileManager.default.temporaryDirectory.appendingPathComponent("Citadel-macOS.dmg")
        let releaseURL = "https://github.com/kartikarora/citadel/releases/latest/download/Citadel-0.1.0-macOS-arm64.dmg"
        
        let curlProc = Process()
        curlProc.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        curlProc.arguments = ["-fsSL", releaseURL, "-o", tempDMG.path]
        try? curlProc.run()
        curlProc.waitUntilExit()
        
        guard FileManager.default.fileExists(atPath: tempDMG.path) else {
            print("❌ Failed to download Citadel DMG from \(releaseURL).")
            print("Please visit https://citadel.kartikarora.me/#downloads to download manually.")
            return
        }
        
        print("💿 Mounting DMG and installing Citadel.app to /Applications...")
        let mountProc = Process()
        mountProc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        mountProc.arguments = ["attach", tempDMG.path, "-nobrowse", "-mountpoint", "/Volumes/CitadelInstaller"]
        try? mountProc.run()
        mountProc.waitUntilExit()
        
        let mountedApp = "/Volumes/CitadelInstaller/Citadel.app"
        if FileManager.default.fileExists(atPath: mountedApp) {
            _ = CitadelUtils.runProcess(executable: "/bin/cp", arguments: ["-R", mountedApp, "/Applications/Citadel.app"])
            print("✅ Successfully installed Citadel.app into /Applications!")
        }
        
        let unmountProc = Process()
        unmountProc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        unmountProc.arguments = ["detach", "/Volumes/CitadelInstaller", "-quiet"]
        try? unmountProc.run()
        unmountProc.waitUntilExit()
        try? FileManager.default.removeItem(at: tempDMG)
        
        print("🚀 Opening Citadel.app...")
        let openProc = Process()
        openProc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        openProc.arguments = ["/Applications/Citadel.app"]
        try? openProc.run()
    }
}
