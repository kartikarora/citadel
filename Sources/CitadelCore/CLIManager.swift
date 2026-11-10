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
    
    // MARK: - Shell Autocompletion
    
    public enum Shell: String, CaseIterable, Sendable {
        case zsh
        case bash
        case fish
    }
    
    /// Generates shell completion script by executing the installed binary with `--generate-completion-script <shell>`
    public func generateCompletionScript(shell: Shell, binaryName: String = "citadel") -> String? {
        let bin = preferredInstallDir.appendingPathComponent(binaryName)
        guard fileManager.isExecutableFile(atPath: bin.path) else {
            // Fall back to finding bundled binary if not yet installed
            guard let fallback = (binaryName == "ctdl" ? findCLIBinaries().ctdl : findCLIBinaries().citadel) else {
                return nil
            }
            let res = CitadelUtils.runProcess(executable: fallback.path, arguments: ["--generate-completion-script", shell.rawValue])
            return res.exitCode == 0 && !res.output.isEmpty ? res.output : nil
        }
        
        let res = CitadelUtils.runProcess(executable: bin.path, arguments: ["--generate-completion-script", shell.rawValue])
        return res.exitCode == 0 && !res.output.isEmpty ? res.output : nil
    }
    
    /// Installs autocompletion scripts across zsh (~/.zfunc / ~/.zshrc), fish, and bash
    @discardableResult
    public func installAutocompletion() -> [Shell: Bool] {
        var results: [Shell: Bool] = [:]
        let home = fileManager.homeDirectoryForCurrentUser
        
        // 1. ZSH: ~/.zfunc/_citadel and ~/.zfunc/_ctdl + ensure fpath in ~/.zshrc
        if let zshCitadel = generateCompletionScript(shell: .zsh, binaryName: "citadel"),
           let zshCtdl = generateCompletionScript(shell: .zsh, binaryName: "ctdl") {
            let zfuncDir = home.appendingPathComponent(".zfunc")
            try? fileManager.createDirectory(at: zfuncDir, withIntermediateDirectories: true)
            
            let citadelComp = zfuncDir.appendingPathComponent("_citadel")
            let ctdlComp = zfuncDir.appendingPathComponent("_ctdl")
            let ok1 = (try? zshCitadel.write(to: citadelComp, atomically: true, encoding: .utf8)) != nil
            let ok2 = (try? zshCtdl.write(to: ctdlComp, atomically: true, encoding: .utf8)) != nil
            
            // Also ensure fpath=(~/.zfunc $fpath) is in ~/.zshrc
            let zshrc = home.appendingPathComponent(".zshrc")
            let snippet = """
            
            # Citadel CLI Autocompletion
            if [ -d "$HOME/.zfunc" ]; then
                fpath=("$HOME/.zfunc" $fpath)
                autoload -Uz compinit && compinit -C
            fi
            """
            if fileManager.fileExists(atPath: zshrc.path) {
                if let content = try? String(contentsOf: zshrc, encoding: .utf8), !content.contains(".zfunc") {
                    try? (content + snippet).write(to: zshrc, atomically: true, encoding: .utf8)
                }
            } else {
                try? snippet.write(to: zshrc, atomically: true, encoding: .utf8)
            }
            results[.zsh] = ok1 && ok2
        }
        
        // 2. Fish: ~/.config/fish/completions/citadel.fish and ctdl.fish
        if let fishCitadel = generateCompletionScript(shell: .fish, binaryName: "citadel"),
           let fishCtdl = generateCompletionScript(shell: .fish, binaryName: "ctdl") {
            let fishCompDir = home.appendingPathComponent(".config/fish/completions")
            try? fileManager.createDirectory(at: fishCompDir, withIntermediateDirectories: true)
            let f1 = (try? fishCitadel.write(to: fishCompDir.appendingPathComponent("citadel.fish"), atomically: true, encoding: .utf8)) != nil
            let f2 = (try? fishCtdl.write(to: fishCompDir.appendingPathComponent("ctdl.fish"), atomically: true, encoding: .utf8)) != nil
            results[.fish] = f1 && f2
        }
        
        // 3. Bash: ~/.bash_completion.d/citadel or ~/.bashrc snippet
        if let bashCitadel = generateCompletionScript(shell: .bash, binaryName: "citadel"),
           let bashCtdl = generateCompletionScript(shell: .bash, binaryName: "ctdl") {
            let bashCompDir = home.appendingPathComponent(".bash_completion.d")
            try? fileManager.createDirectory(at: bashCompDir, withIntermediateDirectories: true)
            let b1 = (try? bashCitadel.write(to: bashCompDir.appendingPathComponent("citadel.bash"), atomically: true, encoding: .utf8)) != nil
            let b2 = (try? bashCtdl.write(to: bashCompDir.appendingPathComponent("ctdl.bash"), atomically: true, encoding: .utf8)) != nil
            results[.bash] = b1 && b2
        }
        
        return results
    }
    
    /// Uninstalls citadel & ctdl from ~/.local/bin and cleans up completion files
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
        
        // Remove zsh completions
        let home = fileManager.homeDirectoryForCurrentUser
        let zfunc = home.appendingPathComponent(".zfunc")
        try? fileManager.removeItem(at: zfunc.appendingPathComponent("_citadel"))
        try? fileManager.removeItem(at: zfunc.appendingPathComponent("_ctdl"))
        
        // Remove fish completions
        let fishCompDir = home.appendingPathComponent(".config/fish/completions")
        try? fileManager.removeItem(at: fishCompDir.appendingPathComponent("citadel.fish"))
        try? fileManager.removeItem(at: fishCompDir.appendingPathComponent("ctdl.fish"))
        
        // Remove bash completions
        let bashCompDir = home.appendingPathComponent(".bash_completion.d")
        try? fileManager.removeItem(at: bashCompDir.appendingPathComponent("citadel.bash"))
        try? fileManager.removeItem(at: bashCompDir.appendingPathComponent("ctdl.bash"))
    }
}
