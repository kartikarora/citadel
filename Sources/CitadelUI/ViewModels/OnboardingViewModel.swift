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
    
    // Step 3: Key Generation & Keychain Permission
    @Published public var hasAuthorizedSigningKey: Bool = false
    @Published public var signingKeyFingerprint: String = ""
    
    // Step 4: Appearance & Theme
    @Published public var selectedTheme: ThemePreset = .system
    
    // Step 5: Discovery & System Scan with Permission
    @Published public var hasGrantedScanPermission: Bool = false
    @Published public var isScanningSkills: Bool = false
    @Published public var discoveredSkills: [DiscoveredSkill] = []
    
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
        let engine = SkillDiscoveryEngine.shared
        let skills = engine.discoverSkills(in: customRoots, includeBuiltin: false)
        self.discoveredSkills = skills
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
    }
}
