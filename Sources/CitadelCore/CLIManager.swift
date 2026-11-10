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
        searchPaths.append(bundleURL.appendingPathComponent("Contents/Resources/bin"))
        searchPaths.append(bundleURL.appendingPathComponent("Contents/Resources"))
        
        // 2. Main bundle executable parent directory (when running standalone or in development)
        if let mainExec = Bundle.main.executableURL {
            searchPaths.append(mainExec.deletingLastPathComponent())
        }
        
        // 3. Executable parent directory (when running from .build/debug or .build/release)
        let execDir = bundleURL.deletingLastPathComponent()
        searchPaths.append(execDir)
        
        // 4. Known build output directories relative to current working directory
        let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        searchPaths.append(currentDir.appendingPathComponent(".build/debug"))
        searchPaths.append(currentDir.appendingPathComponent(".build/release"))
        searchPaths.append(currentDir.appendingPathComponent(".build/arm64-apple-macosx/debug"))
        searchPaths.append(currentDir.appendingPathComponent(".build/arm64-apple-macosx/release"))
        
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
        
        // If one is found and the other isn't, they share identical entry points so either can serve as both
        if foundCitadel == nil && foundCtdl != nil {
            foundCitadel = foundCtdl
        } else if foundCtdl == nil && foundCitadel != nil {
            foundCtdl = foundCitadel
        }
        
        return (foundCitadel, foundCtdl)
    }
    
    /// Installs citadel & ctdl binaries or symlinks into ~/.local/bin (explicit opt-in)
    @discardableResult
    public func installCLI() throws -> (citadelInstalled: Bool, ctdlInstalled: Bool) {
        let binDir = preferredInstallDir
        if !fileManager.fileExists(atPath: binDir.path) {
            try fileManager.createDirectory(at: binDir, withIntermediateDirectories: true)
        }
        
        let bins = findCLIBinaries()
        guard let citSrc = bins.citadel, let ctdlSrc = bins.ctdl else {
            throw NSError(domain: "Citadel", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not locate compiled citadel/ctdl binaries to install. Please build or install from the app package."])
        }
        
        let citDest = binDir.appendingPathComponent("citadel")
        let ctdlDest = binDir.appendingPathComponent("ctdl")
        
        if fileManager.fileExists(atPath: citDest.path) {
            try? fileManager.removeItem(at: citDest)
        }
        try fileManager.copyItem(at: citSrc, to: citDest)
        try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: citDest.path)
        
        if fileManager.fileExists(atPath: ctdlDest.path) {
            try? fileManager.removeItem(at: ctdlDest)
        }
        try fileManager.copyItem(at: ctdlSrc, to: ctdlDest)
        try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: ctdlDest.path)
        
        return (true, true)
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
