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
    
    /// Finds the npx executable across standard macOS / POSIX path locations
    public func findNpxBinary() -> URL? {
        let candidates = [
            "/usr/local/bin/npx",
            "/opt/homebrew/bin/npx",
            "/usr/bin/npx",
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".nvm/versions/node").path,
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/npx").path
        ]
        
        for c in candidates {
            if fileManager.isExecutableFile(atPath: c) {
                return URL(fileURLWithPath: c)
            }
        }
        
        // Check which npx in PATH via process
        let whichRes = CitadelUtils.runProcess(executable: "/usr/bin/which", arguments: ["npx"])
        if whichRes.exitCode == 0 {
            let path = whichRes.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty && fileManager.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        
        return nil
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
    
    /// Installs citadel & ctdl binaries and shell completions into ~/.local/bin (explicit opt-in via install.sh script)
    @discardableResult
    public func installCLI() throws -> (citadelInstalled: Bool, ctdlInstalled: Bool) {
        let binDir = preferredInstallDir
        if !fileManager.fileExists(atPath: binDir.path) {
            try fileManager.createDirectory(at: binDir, withIntermediateDirectories: true)
        }
        
        // Primary: Run the official install.sh script
        let installScriptURL = "https://citadel.kartikarora.me/install.sh"
        let bashProc = Process()
        bashProc.executableURL = URL(fileURLWithPath: "/bin/bash")
        bashProc.arguments = ["-c", "curl -fsSL \(installScriptURL) | bash"]
        let pipe = Pipe()
        bashProc.standardOutput = pipe
        bashProc.standardError = pipe
        try? bashProc.run()
        bashProc.waitUntilExit()
        
        let citDest = binDir.appendingPathComponent("citadel")
        let ctdlDest = binDir.appendingPathComponent("ctdl")
        
        // Fallback: If network install fails or is offline, install from bundled app binaries
        if !fileManager.isExecutableFile(atPath: citDest.path) || !fileManager.isExecutableFile(atPath: ctdlDest.path) {
            let bins = findCLIBinaries()
            if let citSrc = bins.citadel, let ctdlSrc = bins.ctdl {
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
            } else if !fileManager.isExecutableFile(atPath: citDest.path) {
                let errData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown install error"
                throw NSError(domain: "Citadel", code: 500, userInfo: [NSLocalizedDescriptionKey: "CLI installation failed: \(errMsg)"])
            }
        }
        
        // Always configure shell autocompletions (Zsh, Fish, Bash)
        _ = installAutocompletion()
        
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
