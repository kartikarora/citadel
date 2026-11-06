import Foundation

public struct NPMSkillPackage: Codable, Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let version: String
    public let description: String?
    public let publisher: String?
    public let tarballURL: URL?
    
    public init(name: String, version: String, description: String? = nil, publisher: String? = nil, tarballURL: URL? = nil) {
        self.name = name
        self.version = version
        self.description = description
        self.publisher = publisher
        self.tarballURL = tarballURL
    }
}

public final class NPMRegistry: Sendable {
    public static let shared = NPMRegistry()
    
    /// Searches npm for packages tagged with 'citadel-skill' or matching query
    public func searchSkills(query: String? = nil) async throws -> [NPMSkillPackage] {
        var queryStr = "keywords:citadel-skill"
        if let q = query, !q.trimmingCharacters(in: .whitespaces).isEmpty {
            queryStr += " \(q)"
        }
        
        guard let encoded = queryStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://registry.npmjs.org/-/v1/search?text=\(encoded)&size=25") else {
            return []
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
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
            
            // Tarball URL
            var tarball: URL? = nil
            if let dist = (pkg["links"] as? [String: Any])?["npm"] as? String {
                tarball = URL(string: dist)
            }
            
            packages.append(NPMSkillPackage(name: name, version: version, description: desc, publisher: publisher, tarballURL: tarball))
        }
        
        return packages
    }
    
    /// Installs a skill directly from npm by name or package specifier (e.g. '@user/skill' or 'pkg@version')
    public func install(packageSpec: String) async throws -> String {
        let cleanName = packageSpec.components(separatedBy: "@").filter { !$0.isEmpty }.first ?? packageSpec
        let skillFolder = cleanName.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: "@", with: "")
        
        let targetDir = HubManager.shared.skillsURL.appendingPathComponent(skillFolder)
        try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        
        // Fetch package metadata from registry.npmjs.org
        guard let url = URL(string: "https://registry.npmjs.org/\(packageSpec)") else {
            throw NSError(domain: "Citadel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid package specifier: \(packageSpec)"])
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
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
        
        // Download tarball to temporary location
        let (tarballData, _) = try await URLSession.shared.data(from: tarballURL)
        let tempTar = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).tgz")
        try tarballData.write(to: tempTar)
        
        // Extract tarball using native macOS /usr/bin/tar
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xzf", tempTar.path, "--strip-components=1", "-C", targetDir.path]
        try process.run()
        process.waitUntilExit()
        
        try? FileManager.default.removeItem(at: tempTar)
        
        // Run sync
        _ = try SyncEngine.shared.syncAll()
        
        return skillFolder
    }
}
