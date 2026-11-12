import Foundation

public struct NPMSkillPackage: Codable, Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let version: String
    public let description: String?
    public let publisher: String?
    public let tarballURL: URL?
    public let keywords: [String]?
    
    public init(
        name: String,
        version: String,
        description: String? = nil,
        publisher: String? = nil,
        tarballURL: URL? = nil,
        keywords: [String]? = nil
    ) {
        self.name = name
        self.version = version
        self.description = description
        self.publisher = publisher
        self.tarballURL = tarballURL
        self.keywords = keywords
    }
}

public final class NPMRegistry: Sendable {
    public static let shared = NPMRegistry()
    
    /// Searches npm via registry.npmjs.org for skills packages matching query
    public func searchSkills(query: String? = nil) async throws -> [NPMSkillPackage] {
        var queryStr = "skills"
        if let q = query, !q.trimmingCharacters(in: .whitespaces).isEmpty {
            queryStr = q.trimmingCharacters(in: .whitespaces)
        }
        
        guard let encoded = queryStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://registry.npmjs.org/-/v1/search?text=\(encoded)&size=40") else {
            return []
        }
        
        var request = URLRequest(url: url)
        request.setValue("Citadel/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
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
            
            // Tarball URL
            var tarball: URL? = nil
            if let dist = (pkg["links"] as? [String: Any])?["npm"] as? String {
                tarball = URL(string: dist)
            }
            
            packages.append(NPMSkillPackage(
                name: name,
                version: version,
                description: desc,
                publisher: publisher,
                tarballURL: tarball,
                keywords: keywords
            ))
        }
        
        return packages
    }
    
    /// Installs a skill package via background npx command (using vercel-labs/skills or direct npm fallback)
    /// Once installed, Citadel discovers the new skill into ~/.citadel/skills and propagates symlinks.
    @discardableResult
    public func install(packageSpec: String) async throws -> String {
        let cleanName = packageSpec.components(separatedBy: "@").filter { !$0.isEmpty }.first ?? packageSpec
        let skillFolder = cleanName.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: "@", with: "")
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
