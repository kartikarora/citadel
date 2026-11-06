import Foundation

public final class CLIManager: @unchecked Sendable {
    public static let shared = CLIManager()
    
    private let fileManager = FileManager.default
    
    /// User's ~/.local/bin or /usr/local/bin
    public var preferredInstallDir: URL {
        let home = fileManager.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".local/bin")
    }
    
    public var isInstalled: Bool {
        let binDir = preferredInstallDir
        let citadel = binDir.appendingPathComponent("citadel")
        let ctdl = binDir.appendingPathComponent("ctdl")
        return fileManager.fileExists(atPath: citadel.path) || fileManager.fileExists(atPath: ctdl.path)
    }
    
    /// Finds built CLI binaries from the running app bundle or build folder
    public func findCLIBinaries() -> (citadel: URL?, ctdl: URL?) {
        var searchPaths: [URL] = []
        
        // 1. App Bundle Resources / MacOS
        let bundleURL = Bundle.main.bundleURL
        searchPaths.append(bundleURL.appendingPathComponent("Contents/MacOS"))
        searchPaths.append(bundleURL.appendingPathComponent("Contents/Resources"))
        
        // 2. Executable parent directory (when running from .build/debug or .build/release)
        let execDir = bundleURL.deletingLastPathComponent()
        searchPaths.append(execDir)
        
        // 3. Known build output directories
        let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        searchPaths.append(currentDir.appendingPathComponent(".build/debug"))
        searchPaths.append(currentDir.appendingPathComponent(".build/release"))
        
        var foundCitadel: URL? = nil
        var foundCtdl: URL? = nil
        
        for dir in searchPaths {
            let cit = dir.appendingPathComponent("citadel")
            let ct = dir.appendingPathComponent("ctdl")
            if foundCitadel == nil && fileManager.isExecutableFile(atPath: cit.path) {
                foundCitadel = cit
            }
            if foundCtdl == nil && fileManager.isExecutableFile(atPath: ct.path) {
                foundCtdl = ct
            }
        }
        
        return (foundCitadel, foundCtdl)
    }
    
    /// Installs citadel & ctdl symlinks into ~/.local/bin (explicit opt-in)
    public func installCLI() throws {
        let binDir = preferredInstallDir
        if !fileManager.fileExists(atPath: binDir.path) {
            try fileManager.createDirectory(at: binDir, withIntermediateDirectories: true)
        }
        
        let bins = findCLIBinaries()
        guard let citSrc = bins.citadel, let ctdlSrc = bins.ctdl else {
            throw NSError(domain: "Citadel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not locate compiled citadel/ctdl binaries to install."])
        }
        
        let citDest = binDir.appendingPathComponent("citadel")
        let ctdlDest = binDir.appendingPathComponent("ctdl")
        
        if fileManager.fileExists(atPath: citDest.path) {
            try? fileManager.removeItem(at: citDest)
        }
        try fileManager.copyItem(at: citSrc, to: citDest)
        
        if fileManager.fileExists(atPath: ctdlDest.path) {
            try? fileManager.removeItem(at: ctdlDest)
        }
        try fileManager.copyItem(at: ctdlSrc, to: ctdlDest)
    }
    
    /// Uninstalls citadel & ctdl from ~/.local/bin
    public func uninstallCLI() throws {
        let binDir = preferredInstallDir
        let citDest = binDir.appendingPathComponent("citadel")
        let ctdlDest = binDir.appendingPathComponent("ctdl")
        
        if fileManager.fileExists(atPath: citDest.path) {
            try fileManager.removeItem(at: citDest)
        }
        if fileManager.fileExists(atPath: ctdlDest.path) {
            try fileManager.removeItem(at: ctdlDest)
        }
    }
}
