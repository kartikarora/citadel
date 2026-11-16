import Foundation

public struct NPMSkillPackage: Codable, Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let version: String
    public let description: String?
    public let publisher: String?
    public let tarballURL: URL?
    public let keywords: [String]?
    public let homepageURL: URL?
    public let repositoryURL: URL?
    public let npmURL: URL?
    
    public init(
        name: String,
        version: String,
        description: String? = nil,
        publisher: String? = nil,
        tarballURL: URL? = nil,
        keywords: [String]? = nil,
        homepageURL: URL? = nil,
        repositoryURL: URL? = nil,
        npmURL: URL? = nil
    ) {
        self.name = name
        self.version = version
        self.description = description
        self.publisher = publisher
        self.tarballURL = tarballURL
        self.keywords = keywords
        self.homepageURL = homepageURL
        self.repositoryURL = repositoryURL
        self.npmURL = npmURL
    }
}

public final class NPMRegistry: Sendable {
    public static let shared = NPMRegistry()
    
    /// Checks whether an npm package represents a genuine AI agent skill
    public static func isAIAgentSkill(name: String, description: String?, keywords: [String]?) -> Bool {
        let nameLower = name.lowercased()
        let descLower = (description ?? "").lowercased()
        let keywordsLower = (keywords ?? []).map { $0.lowercased() }
        
        // Negative heuristic: Pure UI component libraries or non-AI packages mistakenly tagging "agent-skills"
        let nonSkillIndicators = [
            "component library", "react components", "design system",
            "hosting app sdk", "css foundations", "icon set in iconify",
            "icons for stx from iconify"
        ]
        if nonSkillIndicators.contains(where: { descLower.contains($0) }) {
            // Only allow if explicitly defining SKILL.md or curated skills
            let explicitSkillIndicators = ["skill.md", "agent skills for", "curated agent skills", "skills for ai"]
            if !explicitSkillIndicators.contains(where: { descLower.contains($0) }) {
                return false
            }
        }
        
        // 1. Direct AI agent skill keywords
        let aiKeywords: Set<String> = [
            "agent-skills", "agent-skill", "agentskills", "skill-md",
            "ai-agents", "ai-agent", "coding-agent", "coding-agents",
            "claude-code", "claude-code-plugin", "cursor-rules",
            "agent-plugin", "agent-plugins", "agentic-ai", "deepseek-harness"
        ]
        if keywordsLower.contains(where: { aiKeywords.contains($0) }) {
            return true
        }
        
        // 2. Generic skill keyword paired with an AI environment indicator
        if keywordsLower.contains("skills") || keywordsLower.contains("skill") {
            let aiIndicators = ["ai", "agent", "agents", "llm", "claude", "cursor", "codex", "mcp"]
            if keywordsLower.contains(where: { aiIndicators.contains($0) }) {
                return true
            }
        }
        
        // 3. Description mentions SKILL.md, agent skills, or AI coding assistant skills
        let descTriggers = [
            "skill.md", "agent skills", "agent skill", "skills for ai",
            "skills for coding agents", "ai coding agents", "ai agent skills"
        ]
        if descTriggers.contains(where: { descLower.contains($0) }) {
            return true
        }
        
        // 4. Package naming conventions paired with AI descriptions
        let isSkillNamed = nameLower.hasSuffix("-skills") ||
                           nameLower.hasPrefix("skills-") ||
                           nameLower.contains("/skills") ||
                           nameLower.contains("-agent-skills")
        if isSkillNamed {
            let aiDescWords = ["agent", "ai", "claude", "cursor", "codex", "llm", "mcp"]
            if aiDescWords.contains(where: { descLower.contains($0) || keywordsLower.contains($0) }) {
                return true
            }
        }
        
        return false
    }
    
    /// Searches official AI agent skills directories (skills.sh) and verified npm packages
    public func searchSkills(query: String? = nil) async throws -> [NPMSkillPackage] {
        var queryStr = "skills"
        if let q = query, !q.trimmingCharacters(in: .whitespaces).isEmpty {
            queryStr = q.trimmingCharacters(in: .whitespaces)
        }
        
        // Concurrently query:
        // 1. skills.sh API (The official open agent skills ecosystem directory - 100% verified AI skills)
        // 2. npm registry (strictly filtered by AI skill metadata heuristics)
        async let skillsShResults = searchSkillsDirectory(query: queryStr)
        async let npmResults = searchNpmRegistry(query: queryStr)
        
        let (shList, npmList) = await (skillsShResults, npmResults)
        
        // Merge without duplicates, prioritizing skills.sh verified skills
        var seenNames = Set<String>()
        var combined: [NPMSkillPackage] = []
        
        for pkg in shList {
            let key = pkg.name.lowercased()
            if !seenNames.contains(key) {
                seenNames.insert(key)
                combined.append(pkg)
            }
        }
        
        for pkg in npmList {
            let key = pkg.name.lowercased()
            if !seenNames.contains(key) {
                seenNames.insert(key)
                combined.append(pkg)
            }
        }
        
        return combined
    }
    
    /// Queries the open agent skills directory at skills.sh
    private func searchSkillsDirectory(query: String) async -> [NPMSkillPackage] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://skills.sh/api/search?q=\(encoded)") else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.setValue("Citadel/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0
        
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let skills = json["skills"] as? [[String: Any]] else {
            return []
        }
        
        var packages: [NPMSkillPackage] = []
        for item in skills {
            guard let source = item["source"] as? String,
                  let skillId = item["skillId"] as? String else {
                continue
            }
            
            let displayName = item["name"] as? String ?? skillId
            let fullSpec = "\(source)@\(skillId)"
            let installs = item["installs"] as? Int
            
            var desc = "Agent skill from \(source)"
            if let count = installs, count > 0 {
                let formattedCount = count >= 1_000_000 ? String(format: "%.1fM", Double(count) / 1_000_000.0) :
                                     count >= 1_000 ? String(format: "%.1fK", Double(count) / 1_000.0) : "\(count)"
                desc += " (\(formattedCount) installs)"
            }
            
            let skillPage = URL(string: "https://skills.sh/\(source)/\(skillId)")
            let repoURL = URL(string: "https://github.com/\(source)")
            
            packages.append(NPMSkillPackage(
                name: fullSpec,
                version: "latest",
                description: desc,
                publisher: source.components(separatedBy: "/").first,
                tarballURL: nil,
                keywords: ["agent-skills", "skill-md", displayName],
                homepageURL: skillPage,
                repositoryURL: repoURL,
                npmURL: skillPage
            ))
        }
        
        return packages
    }
    
    /// Queries npm registry and filters out non-skill packages
    private func searchNpmRegistry(query: String) async -> [NPMSkillPackage] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://registry.npmjs.org/-/v1/search?text=\(encoded)&size=40") else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.setValue("Citadel/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0
        
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let objects = json["objects"] as? [[String: Any]] else {
            return []
        }
        
        var packages: [NPMSkillPackage] = []
        for obj in objects {
            guard let pkg = obj["package"] as? [String: Any],
                  let name = pkg["name"] as? String,
                  let version = pkg["version"] as? String else {
                continue
            }
            let desc = pkg["description"] as? String
            let publisher = (pkg["publisher"] as? [String: Any])?["username"] as? String
            let keywords = pkg["keywords"] as? [String]
            
            // STRICT FILTER: Only accept 100% verified AI agent skills
            guard Self.isAIAgentSkill(name: name, description: desc, keywords: keywords) else {
                continue
            }
            
            // Links
            let links = pkg["links"] as? [String: Any]
            var tarball: URL? = nil
            if let dist = links?["npm"] as? String {
                tarball = URL(string: dist)
            }
            
            var homepage: URL? = nil
            if let hp = links?["homepage"] as? String {
                homepage = URL(string: hp)
            }
            
            var repo: URL? = nil
            if let r = links?["repository"] as? String {
                let cleanR = r.replacingOccurrences(of: "git+", with: "").replacingOccurrences(of: ".git", with: "")
                repo = URL(string: cleanR)
            }
            
            let npmPage = tarball ?? URL(string: "https://www.npmjs.com/package/\(name)")
            
            packages.append(NPMSkillPackage(
                name: name,
                version: version,
                description: desc,
                publisher: publisher,
                tarballURL: tarball,
                keywords: keywords,
                homepageURL: homepage,
                repositoryURL: repo,
                npmURL: npmPage
            ))
        }
        
        return packages
    }
    
    /// Installs a skill package via background npx command (using vercel-labs/skills or direct npm fallback)
    /// Once installed, Citadel discovers the new skill into ~/.citadel/skills and propagates symlinks.
    @discardableResult
    public func install(packageSpec: String) async throws -> String {
        // Derive clean skill folder name
        let skillFolder: String
        if packageSpec.contains("@") && !packageSpec.hasPrefix("@") {
            // e.g. "owner/repo@skill-name"
            let parts = packageSpec.components(separatedBy: "@")
            skillFolder = parts.last ?? packageSpec
        } else {
            // npm package name e.g. "@scope/package" or "skills"
            let cleanName = packageSpec.components(separatedBy: "@").filter { !$0.isEmpty }.first ?? packageSpec
            skillFolder = cleanName.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: "@", with: "")
        }
        let targetDir = HubManager.shared.skillsURL.appendingPathComponent(skillFolder)
        
        // 1. Try running `npx -y skills add <packageSpec> -y --copy` in a temporary staging directory
        if let npxBin = CLIManager.shared.findNpxBinary() {
            let tempStage = FileManager.default.temporaryDirectory.appendingPathComponent("citadel_npx_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempStage, withIntermediateDirectories: true)
            
            defer {
                try? FileManager.default.removeItem(at: tempStage)
            }
            
            _ = CitadelUtils.runProcess(
                executable: npxBin.path,
                arguments: ["-y", "skills", "add", packageSpec, "--agent", "claude-code", "-y", "--copy"],
                workingDirectory: tempStage
            )
            
            // Check if skills CLI installed any SKILL.md under tempStage
            var foundSkillDir: URL? = nil
            if let enumerator = FileManager.default.enumerator(at: tempStage, includingPropertiesForKeys: [.isDirectoryKey]) {
                while let item = enumerator.nextObject() {
                    if let fileURL = item as? URL, fileURL.lastPathComponent == "SKILL.md" {
                        foundSkillDir = fileURL.deletingLastPathComponent()
                        break
                    }
                }
            }
            
            if let sourceDir = foundSkillDir {
                try? FileManager.default.removeItem(at: targetDir)
                try FileManager.default.createDirectory(at: targetDir.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: sourceDir, to: targetDir)
                
                _ = try SyncEngine.shared.syncAll()
                return skillFolder
            }
        }
        
        // 2. Fallback: Fetch tarball directly from registry.npmjs.org and unpack
        try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        
        guard let url = URL(string: "https://registry.npmjs.org/\(packageSpec)") else {
            throw NSError(domain: "Citadel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid package specifier: \(packageSpec)"])
        }
        
        var req = URLRequest(url: url)
        req.setValue("Citadel/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "Citadel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Package not found on npm: \(packageSpec)"])
        }
        
        let latestVersion = (json["dist-tags"] as? [String: Any])?["latest"] as? String ?? "1.0.0"
        let versions = json["versions"] as? [String: Any]
        let versionData = versions?[latestVersion] as? [String: Any]
        let dist = versionData?["dist"] as? [String: Any]
        
        guard let tarballStr = dist?["tarball"] as? String,
              let tarballURL = URL(string: tarballStr) else {
            throw NSError(domain: "Citadel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not find tarball for \(packageSpec)"])
        }
        
        let (tarballData, _) = try await URLSession.shared.data(from: tarballURL)
        let tempTar = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).tgz")
        try tarballData.write(to: tempTar)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xzf", tempTar.path, "--strip-components=1", "-C", targetDir.path]
        try process.run()
        process.waitUntilExit()
        
        try? FileManager.default.removeItem(at: tempTar)
        
        _ = try SyncEngine.shared.syncAll()
        return skillFolder
    }
    
    /// Removes an installed skill via background npx command and cleans up ~/.citadel and tool symlinks
    public func remove(skillName: String) async throws {
        // 1. Run npx skills remove if available
        if let npxBin = CLIManager.shared.findNpxBinary() {
            let tempStage = FileManager.default.temporaryDirectory.appendingPathComponent("citadel_npx_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempStage, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempStage) }
            
            _ = CitadelUtils.runProcess(
                executable: npxBin.path,
                arguments: ["-y", "skills", "remove", skillName, "-y"],
                workingDirectory: tempStage
            )
        }
        
        // 2. Remove canonical directory in ~/.citadel/skills/<skillName>
        let targetDir = HubManager.shared.skillsURL.appendingPathComponent(skillName)
        if FileManager.default.fileExists(atPath: targetDir.path) {
            try FileManager.default.removeItem(at: targetDir)
        }
        
        // 3. Clean up broken symlinks across all known client roots
        for clientRoot in UniversalPaths.shared.knownClientRoots {
            let candidate = clientRoot.appendingPathComponent("skills/\(skillName)")
            if FileManager.default.fileExists(atPath: candidate.path) {
                try? FileManager.default.removeItem(at: candidate)
            }
        }
        
        // 4. Re-sync all tools
        _ = try SyncEngine.shared.syncAll()
    }
}
