import Foundation
import Security

/// Secure vault for storing and resolving MCP server environment variables in macOS Keychain
public enum MCPSecretVault {
    public static let serviceName = CitadelConstants.Keychain.mcpSecretsService
    
    /// Detects if an environment variable key or value indicates a sensitive secret
    public static func isSensitive(key: String, value: String) -> Bool {
        let upperKey = key.uppercased()
        let sensitiveKeyPatterns = ["TOKEN", "SECRET", "KEY", "AUTH", "PASS", "CREDENTIAL", "BEARER", "PRIVATE"]
        for pattern in sensitiveKeyPatterns {
            if upperKey.contains(pattern) { return true }
        }
        // Check value heuristics: GitHub token prefixes (gho_, ghp_, etc.) or long base64/hex strings
        if value.hasPrefix("gho_") || value.hasPrefix("ghp_") || value.hasPrefix("ghu_") || value.hasPrefix("github_pat_") || value.hasPrefix("sk-") {
            return true
        }
        return false
    }
    
    /// Keychain account key for a given server and environment variable name
    public static func accountKey(serverName: String, envKey: String) -> String {
        return "mcp.\(serverName).\(envKey)"
    }
    
    /// Placeholder stored in git-synced JSON: e.g. `${KEYCHAIN:mcp.github.GITHUB_PERSONAL_ACCESS_TOKEN}`
    public static func placeholder(serverName: String, envKey: String) -> String {
        return "${KEYCHAIN:\(accountKey(serverName: serverName, envKey: envKey))}"
    }
    
    /// Strips sensitive secrets from an MCP server's env, moving them to Keychain,
    /// and returning a sanitized server definition safe for git commit.
    public static func sanitizeForSync(_ server: MCPServer) -> MCPServer {
        guard let env = server.env, !env.isEmpty else {
            return server
        }
        
        var sanitizedEnv: [String: String] = [:]
        for (k, v) in env {
            if v.hasPrefix("${KEYCHAIN:") {
                // Already sanitized
                sanitizedEnv[k] = v
                continue
            }
            if isSensitive(key: k, value: v) {
                // Save to Keychain
                let account = accountKey(serverName: server.name, envKey: k)
                _ = CitadelUtils.saveKeychainSecret(service: serviceName, account: account, value: v)
                // Replace with placeholder in git
                sanitizedEnv[k] = placeholder(serverName: server.name, envKey: k)
            } else {
                sanitizedEnv[k] = v
            }
        }
        
        // Also normalize any home paths in args (e.g. ~/IdeaProjects/preview/...)
        let sanitizedArgs = server.args.map { PortablePath.toPortable($0) }
        
        return MCPServer(name: server.name, command: server.command, args: sanitizedArgs, env: sanitizedEnv)
    }
    
    /// Resolves placeholders in an MCP server's env and args from Keychain and local environment
    public static func hydrateForRuntime(_ server: MCPServer) -> MCPServer {
        let hydratedArgs = server.args.map { PortablePath.fromPortable($0).path }
        
        guard let env = server.env, !env.isEmpty else {
            return MCPServer(name: server.name, command: server.command, args: hydratedArgs, env: server.env)
        }
        
        var hydratedEnv: [String: String] = [:]
        let processEnv = ProcessInfo.processInfo.environment
        
        for (k, v) in env {
            if v.hasPrefix("${KEYCHAIN:") && v.hasSuffix("}") {
                let account = String(v.dropFirst(11).dropLast(1))
                // 1. Try Citadel MCP Keychain service
                if let secret = CitadelUtils.loadKeychainSecret(service: serviceName, account: account) {
                    hydratedEnv[k] = secret
                    continue
                }
                // 2. Try legacy fallback service if existing
                if let legacySecret = CitadelUtils.loadKeychainSecret(service: "com.kartikarora.citadel.secrets", account: account) {
                    hydratedEnv[k] = legacySecret
                    continue
                }
                // 3. Fallback to process environment matching envKey
                if let envVal = processEnv[k] {
                    hydratedEnv[k] = envVal
                    continue
                }
                // Leave unresolved placeholder if unavailable
                hydratedEnv[k] = v
            } else if v.hasPrefix("${") && v.hasSuffix("}") {
                let envKey = String(v.dropFirst(2).dropLast(1))
                hydratedEnv[k] = processEnv[envKey] ?? v
            } else {
                hydratedEnv[k] = v
            }
        }
        
        return MCPServer(name: server.name, command: server.command, args: hydratedArgs, env: hydratedEnv)
    }
}
