import Foundation

/// Handles portable path encoding/decoding and git-based workspace stamping
public enum PortablePath {
    
    /// Normalizes an absolute URL or path string to a portable `~/` representation
    public static func toPortable(_ path: String, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> String {
        let homePath = home.path
        if path == homePath {
            return "~"
        }
        if path.hasPrefix(homePath + "/") {
            return "~" + path.dropFirst(homePath.count)
        }
        return path
    }
    
    /// Expands a portable `~/` path to the current machine's home directory URL
    public static func fromPortable(_ path: String, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        if path == "~" {
            return home
        }
        if path.hasPrefix("~/") {
            let relative = String(path.dropFirst(2))
            return home.appendingPathComponent(relative)
        }
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }
    
    /// Reads or generates a Citadel Portal ID stamped inside `.git/config`
    public static func getOrStampGitPortalId(in repoURL: URL) -> String? {
        let gitDir = repoURL.appendingPathComponent(".git")
        guard FileManager.default.fileExists(atPath: gitDir.path) else { return nil }
        
        let readRes = CitadelUtils.runProcess(
            executable: "/usr/bin/git",
            arguments: ["-C", repoURL.path, "config", "--local", "citadel.portal-id"]
        )
        let existing = readRes.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !existing.isEmpty && readRes.exitCode == 0 {
            return existing
        }
        
        // Stamp a new UUID
        let newId = "cproj_" + UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(16)
        let writeRes = CitadelUtils.runProcess(
            executable: "/usr/bin/git",
            arguments: ["-C", repoURL.path, "config", "--local", "citadel.portal-id", newId]
        )
        if writeRes.exitCode == 0 {
            return newId
        }
        return nil
    }
    
    /// Computes the Git remote origin URL and genesis root commit hash for cross-machine matching
    public static func gitFingerprint(in repoURL: URL) -> (remote: String?, rootHash: String?) {
        let gitDir = repoURL.appendingPathComponent(".git")
        guard FileManager.default.fileExists(atPath: gitDir.path) else { return (nil, nil) }
        
        var remote: String? = nil
        let remoteRes = CitadelUtils.runProcess(
            executable: "/usr/bin/git",
            arguments: ["-C", repoURL.path, "config", "--get", "remote.origin.url"]
        )
        let rawRemote = remoteRes.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rawRemote.isEmpty && remoteRes.exitCode == 0 {
            remote = rawRemote
        }
        
        var rootHash: String? = nil
        let rootRes = CitadelUtils.runProcess(
            executable: "/usr/bin/git",
            arguments: ["-C", repoURL.path, "rev-list", "--max-parents=0", "HEAD"]
        )
        let rawHash = rootRes.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rawHash.isEmpty && rootRes.exitCode == 0 {
            // If multiple roots exist, take the first
            rootHash = rawHash.components(separatedBy: .whitespacesAndNewlines).first
        }
        
        return (remote, rootHash)
    }
}
