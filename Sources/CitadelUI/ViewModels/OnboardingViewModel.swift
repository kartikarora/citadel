import SwiftUI
import Combine
import CitadelCore

@MainActor
public final class OnboardingViewModel: ObservableObject {
    private let defaults: UserDefaults
    
    public let totalSteps: Int = 5
    @Published public var currentStep: Int = 1
    @Published public var customHubPath: String
    @Published public var repoName: String = CitadelConstants.Git.defaultRepoName
    @Published public var isPrivateRepo: Bool = true
    @Published public var isOnboardingComplete: Bool
    
    // Auth & Cloud Sync
    @Published public var githubUser: AuthAccount? = nil
    @Published public var gitlabUser: AuthAccount? = nil
    @Published public var isAuthenticating: Bool = false
    @Published public var oauthStatusMessage: String = ""
    @Published public var showAuthModal: Bool = false
    @Published public var authModalProvider: GitProvider = .github
    @Published public var authInputToken: String = ""
    
    // Existing Sync Repo Detection & Re-use Prompt (Identified by SyncMarker, not by name)
    @Published public var foundExistingSyncRepo: Bool = false
    @Published public var existingSyncRepoName: String = ""
    @Published public var existingSyncRepoFullName: String = ""
    @Published public var existingSyncRepoCloneURL: String? = nil
    @Published public var existingSyncRepoProvider: GitProvider? = nil
    @Published public var existingSyncRepoMarker: RemoteSyncManager.SyncMarker? = nil
    @Published public var showReuseRepoPrompt: Bool = false
    
    // Step 3: Key Generation & Keychain Permission
    @Published public var hasAuthorizedSigningKey: Bool = false
    @Published public var signingKeyFingerprint: String = ""
    
    // Step 4: Appearance & Theme
    @Published public var selectedTheme: ThemePreset = .system
    
    // Step 5: Discovery & System Scan with Permission
    @Published public var hasGrantedScanPermission: Bool = false
    @Published public var isScanningSkills: Bool = false
    @Published public var discoverySegment: String = "ai_config"
    @Published public var discoveredSkills: [DiscoveredSkill] = []
    @Published public var discoveredMCPs: [DiscoveredMCP] = []
    @Published public var discoveredWorkspaces: [DiscoveredWorkspace] = []
    
    public init(testDefaults: UserDefaults = .standard) {
        self.defaults = testDefaults
        let hub = testDefaults.string(forKey: CitadelConstants.StorageKeys.customHubPath) ?? CitadelConstants.Paths.defaultCitadelDir
        self.customHubPath = hub
        self.isOnboardingComplete = testDefaults.bool(forKey: CitadelConstants.StorageKeys.isOnboardingComplete)
    }
    
    public func nextStep() {
        if currentStep < totalSteps {
            currentStep += 1
        }
    }
    
    public func previousStep() {
        if currentStep > 1 {
            currentStep -= 1
        }
    }
    
    public func authorizeAndGenerateSigningKey() {
        let expanded = CitadelUtils.expandTildePath(customHubPath)
        let hubURL = URL(fileURLWithPath: expanded)
        let hub = HubManager(customHubURL: hubURL)
        hub.setupSigningKeyAndGitIdentity()
        self.hasAuthorizedSigningKey = true
        
        if let pub = try? String(contentsOf: hub.signingPubKeyFile, encoding: .utf8) {
            let parts = pub.split(separator: " ")
            if parts.count >= 2 {
                self.signingKeyFingerprint = String(parts[1].prefix(16)) + "..."
            }
        }
    }
    
    public func authorizeAndRunSkillScan(customRoots: [URL]? = nil) {
        self.hasGrantedScanPermission = true
        self.isScanningSkills = true
        Task {
            await self.authorizeAndRunSkillScanAsync(customRoots: customRoots)
        }
    }
    
    @MainActor
    public func authorizeAndRunSkillScanAsync(customRoots: [URL]? = nil) async {
        self.hasGrantedScanPermission = true
        self.isScanningSkills = true
        let report = await MultiverseDiscoveryEngine.shared.runFullDiscoveryAsync(
            skillRoots: customRoots,
            workspaceRoots: customRoots
        )
        self.discoveredSkills = report.skills
        self.discoveredMCPs = report.mcps
        self.discoveredWorkspaces = report.workspaces
        self.isScanningSkills = false
    }
    
    public func completeOnboarding() {
        defaults.set(customHubPath, forKey: CitadelConstants.StorageKeys.customHubPath)
        defaults.set(true, forKey: CitadelConstants.StorageKeys.isOnboardingComplete)
        self.isOnboardingComplete = true
        
        let expanded = CitadelUtils.expandTildePath(customHubPath)
        let hubURL = URL(fileURLWithPath: expanded)
        let hub = HubManager(customHubURL: hubURL)
        try? hub.initializeHub()
    }
    
    public func refreshAuthUsers() async {
        let gh = await GitAuthProvider.shared.getAuthenticatedUser(for: .github)
        let gl = await GitAuthProvider.shared.getAuthenticatedUser(for: .gitlab)
        self.githubUser = gh
        self.gitlabUser = gl
        await checkExistingSyncRepo()
    }
    
    public func checkExistingSyncRepo() async {
        // Search across GitHub first, then GitLab for ANY repo bearing the sync marker
        if githubUser != nil {
            if let discovered = await GitAuthProvider.shared.discoverSyncRepository(provider: .github, preferredRepoName: repoName) {
                self.foundExistingSyncRepo = true
                self.existingSyncRepoName = discovered.repoName
                self.existingSyncRepoFullName = discovered.fullName
                self.existingSyncRepoCloneURL = discovered.cloneURL
                self.existingSyncRepoProvider = .github
                self.existingSyncRepoMarker = discovered.marker
                self.showReuseRepoPrompt = true
                return
            }
        }
        
        if gitlabUser != nil {
            if let discovered = await GitAuthProvider.shared.discoverSyncRepository(provider: .gitlab, preferredRepoName: repoName) {
                self.foundExistingSyncRepo = true
                self.existingSyncRepoName = discovered.repoName
                self.existingSyncRepoFullName = discovered.fullName
                self.existingSyncRepoCloneURL = discovered.cloneURL
                self.existingSyncRepoProvider = .gitlab
                self.existingSyncRepoMarker = discovered.marker
                self.showReuseRepoPrompt = true
                return
            }
        }
        
        self.foundExistingSyncRepo = false
        self.existingSyncRepoName = ""
        self.existingSyncRepoFullName = ""
        self.existingSyncRepoCloneURL = nil
        self.existingSyncRepoProvider = nil
        self.existingSyncRepoMarker = nil
        self.showReuseRepoPrompt = false
    }
    
    public func reuseExistingSyncRepo() {
        guard let cloneURL = existingSyncRepoCloneURL else { return }
        _ = RemoteSyncManager.shared.setRemoteURL(cloneURL)
        self.showReuseRepoPrompt = false
    }
    
    public func declineReuseSyncRepo() {
        self.showReuseRepoPrompt = false
    }
}
