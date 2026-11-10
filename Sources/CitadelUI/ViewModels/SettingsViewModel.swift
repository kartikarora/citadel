import SwiftUI
import Combine
import CitadelCore

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var themePreset: ThemePreset {
        didSet { UserDefaults.standard.set(themePreset.rawValue, forKey: CitadelConstants.StorageKeys.themePreset) }
    }
    @Published public var customHubPath: String {
        didSet { UserDefaults.standard.set(customHubPath, forKey: CitadelConstants.StorageKeys.customHubPath) }
    }
    
    // Auth & Remote Sync
    @Published public var githubUser: AuthAccount? = nil
    @Published public var gitlabUser: AuthAccount? = nil
    @Published public var remoteStatus: RemoteSyncStatus = RemoteSyncStatus(remoteURL: nil, isConfigured: false, hasUncommittedChanges: false)
    @Published public var rollbackNotice: String = ""
    
    // Feature flags
    @Published public var marketplaceEnabled: Bool
    @Published public var gitlabEnabled: Bool
    @Published public var githubEnabled: Bool
    @Published public var signingEnabled: Bool
    @Published public var portalsEnabled: Bool
    @Published public var backgroundSyncEnabled: Bool
    
    public init() {
        let presetRaw = UserDefaults.standard.string(forKey: CitadelConstants.StorageKeys.themePreset) ?? ThemePreset.system.rawValue
        self.themePreset = ThemePreset(rawValue: presetRaw) ?? .system
        self.customHubPath = UserDefaults.standard.string(forKey: CitadelConstants.StorageKeys.customHubPath) ?? CitadelConstants.Paths.defaultCitadelDir
        
        let flags = FeatureFlags.shared
        self.marketplaceEnabled = flags.npmMarketplaceEnabled
        self.gitlabEnabled = flags.gitlabIntegrationEnabled
        self.githubEnabled = flags.githubIntegrationEnabled
        self.signingEnabled = flags.commitSigningEnabled
        self.portalsEnabled = flags.workspacePortalsEnabled
        self.backgroundSyncEnabled = flags.backgroundAutoSyncEnabled
        
        self.remoteStatus = RemoteSyncManager.shared.getStatus()
    }
    
    public func reloadAuthAndStatus() async {
        let gh = await GitAuthProvider.shared.getAuthenticatedUser(for: .github)
        let gl = await GitAuthProvider.shared.getAuthenticatedUser(for: .gitlab)
        let status = RemoteSyncManager.shared.getStatus()
        self.githubUser = gh
        self.gitlabUser = gl
        self.remoteStatus = status
    }
    
    public func executeRollback(onComplete: @escaping () -> Void) {
        do {
            let res = try RollbackEngine.shared.ejectAndMaterialize()
            self.rollbackNotice = "Ejected (\(res.materializedSkills.count) copied)"
            onComplete()
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                self.rollbackNotice = ""
            }
        } catch {
            self.rollbackNotice = "Rollback error: \(error.localizedDescription)"
        }
    }
    
    public func updateFeatureFlag(marketplace: Bool? = nil, gitlab: Bool? = nil) {
        let flags = FeatureFlags.shared
        if let m = marketplace {
            flags.npmMarketplaceEnabled = m
            self.marketplaceEnabled = m
        }
        if let g = gitlab {
            flags.gitlabIntegrationEnabled = g
            self.gitlabEnabled = g
        }
    }
}
