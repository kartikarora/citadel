import Foundation
import Combine

/// Centralized configuration of feature toggles for Citadel
public final class FeatureFlags: ObservableObject, @unchecked Sendable {
    public static let shared = FeatureFlags()
    
    private let defaults: UserDefaults
    
    // MARK: - Storage Keys
    public enum Keys {
        public static let npmMarketplace = "ff_npmMarketplaceEnabled"
        public static let mcpSync = "ff_mcpSyncEnabled"
        public static let githubIntegration = "ff_githubIntegrationEnabled"
        public static let gitlabIntegration = "ff_gitlabIntegrationEnabled"
        public static let commitSigning = "ff_commitSigningEnabled"
        public static let workspacePortals = "ff_workspacePortalsEnabled"
        public static let backgroundAutoSync = "ff_backgroundAutoSyncEnabled"
        public static let includeBuiltinInDiscovery = "ff_includeBuiltinInDiscoveryEnabled"
    }
    
    // MARK: - Published Flags
    @Published public var npmMarketplaceEnabled: Bool {
        didSet { defaults.set(npmMarketplaceEnabled, forKey: Keys.npmMarketplace) }
    }
    @Published public var mcpSyncEnabled: Bool {
        didSet { defaults.set(mcpSyncEnabled, forKey: Keys.mcpSync) }
    }
    @Published public var githubIntegrationEnabled: Bool {
        didSet { defaults.set(githubIntegrationEnabled, forKey: Keys.githubIntegration) }
    }
    @Published public var gitlabIntegrationEnabled: Bool {
        didSet { defaults.set(gitlabIntegrationEnabled, forKey: Keys.gitlabIntegration) }
    }
    @Published public var commitSigningEnabled: Bool {
        didSet { defaults.set(commitSigningEnabled, forKey: Keys.commitSigning) }
    }
    @Published public var workspacePortalsEnabled: Bool {
        didSet { defaults.set(workspacePortalsEnabled, forKey: Keys.workspacePortals) }
    }
    @Published public var backgroundAutoSyncEnabled: Bool {
        didSet { defaults.set(backgroundAutoSyncEnabled, forKey: Keys.backgroundAutoSync) }
    }
    @Published public var includeBuiltinInDiscoveryEnabled: Bool {
        didSet { defaults.set(includeBuiltinInDiscoveryEnabled, forKey: Keys.includeBuiltinInDiscovery) }
    }
    
    public init(testDefaults: UserDefaults = .standard) {
        self.defaults = testDefaults
        
        let env = ProcessInfo.processInfo.environment
        
        // 1. NPM Skills Management (Default: ON)
        if let envVal = env["CITADEL_ENABLE_MARKETPLACE"] {
            self.npmMarketplaceEnabled = (envVal == "1" || envVal.lowercased() == "true")
        } else if testDefaults.object(forKey: Keys.npmMarketplace) != nil {
            self.npmMarketplaceEnabled = testDefaults.bool(forKey: Keys.npmMarketplace)
        } else {
            self.npmMarketplaceEnabled = true
        }
        
        // 2. MCP Sync (Default: OFF)
        if let envVal = env["CITADEL_ENABLE_MCP_SYNC"] {
            self.mcpSyncEnabled = (envVal == "1" || envVal.lowercased() == "true")
        } else if testDefaults.object(forKey: Keys.mcpSync) != nil {
            self.mcpSyncEnabled = testDefaults.bool(forKey: Keys.mcpSync)
        } else {
            self.mcpSyncEnabled = false
        }
        
        // 3. GitHub Integration (Default: ON)
        if let envVal = env["CITADEL_ENABLE_GITHUB"] {
            self.githubIntegrationEnabled = (envVal == "1" || envVal.lowercased() == "true")
        } else if testDefaults.object(forKey: Keys.githubIntegration) != nil {
            self.githubIntegrationEnabled = testDefaults.bool(forKey: Keys.githubIntegration)
        } else {
            self.githubIntegrationEnabled = true
        }
        
        // 4. GitLab Integration (Default: OFF)
        if let envVal = env["CITADEL_ENABLE_GITLAB"] {
            self.gitlabIntegrationEnabled = (envVal == "1" || envVal.lowercased() == "true")
        } else if testDefaults.object(forKey: Keys.gitlabIntegration) != nil {
            self.gitlabIntegrationEnabled = testDefaults.bool(forKey: Keys.gitlabIntegration)
        } else {
            self.gitlabIntegrationEnabled = false
        }
        
        // 5. Commit Signing (Default: ON)
        if let envVal = env["CITADEL_ENABLE_COMMIT_SIGNING"] {
            self.commitSigningEnabled = (envVal == "1" || envVal.lowercased() == "true")
        } else if testDefaults.object(forKey: Keys.commitSigning) != nil {
            self.commitSigningEnabled = testDefaults.bool(forKey: Keys.commitSigning)
        } else {
            self.commitSigningEnabled = true
        }
        
        // 6. Workspace Portals (Default: ON)
        if let envVal = env["CITADEL_ENABLE_PORTALS"] {
            self.workspacePortalsEnabled = (envVal == "1" || envVal.lowercased() == "true")
        } else if testDefaults.object(forKey: Keys.workspacePortals) != nil {
            self.workspacePortalsEnabled = testDefaults.bool(forKey: Keys.workspacePortals)
        } else {
            self.workspacePortalsEnabled = true
        }
        
        // 7. Background Auto Sync (Default: OFF)
        if let envVal = env["CITADEL_ENABLE_AUTO_SYNC"] {
            self.backgroundAutoSyncEnabled = (envVal == "1" || envVal.lowercased() == "true")
        } else if testDefaults.object(forKey: Keys.backgroundAutoSync) != nil {
            self.backgroundAutoSyncEnabled = testDefaults.bool(forKey: Keys.backgroundAutoSync)
        } else {
            self.backgroundAutoSyncEnabled = false
        }
        
        // 8. Include Builtin in Discovery (Default: OFF)
        if let envVal = env["CITADEL_INCLUDE_BUILTIN"] {
            self.includeBuiltinInDiscoveryEnabled = (envVal == "1" || envVal.lowercased() == "true")
        } else if testDefaults.object(forKey: Keys.includeBuiltinInDiscovery) != nil {
            self.includeBuiltinInDiscoveryEnabled = testDefaults.bool(forKey: Keys.includeBuiltinInDiscovery)
        } else {
            self.includeBuiltinInDiscoveryEnabled = false
        }
    }
    
    public func resetToDefaults() {
        self.npmMarketplaceEnabled = true
        self.mcpSyncEnabled = false
        self.githubIntegrationEnabled = true
        self.gitlabIntegrationEnabled = false
        self.commitSigningEnabled = true
        self.workspacePortalsEnabled = true
        self.backgroundAutoSyncEnabled = false
        self.includeBuiltinInDiscoveryEnabled = false
    }
}
