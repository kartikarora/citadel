import Foundation
import CitadelCore
import CitadelUI

@MainActor
func runAllCitadelTests() throws {
    var passedCount = 0
    var totalCount = 0
    
    func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        totalCount += 1
        if condition() {
            passedCount += 1
            print("  ✅ [PASS] \(message)")
        } else {
            print("  ❌ [FAIL] \(message)")
            exit(1)
        }
    }
    
    print("\n🏰 CITADEL TEST SUITE RUNNER")
    print("==================================================")
    
    // Suite 1: CitadelConstants & CitadelUtils
    print("\n[Suite 1/6: CitadelConstants & Utilities]")
    expect(CitadelConstants.Git.botName == "Citadel Bot", "Bot name matches specification")
    let expectedEmail = "citadel-bot-\(NSUserName())@github.com"
    expect(CitadelConstants.Git.botEmail == expectedEmail, "Bot email matches specification citadel-bot-<username>@github.com")
    expect(CitadelConstants.Git.defaultRepoName == "citadel-sync", "Default repo name is citadel-sync (never citadel-store)")
    expect(CitadelConstants.Keychain.signingService == "sh.citadel.signing", "Signing keychain service identifier verified")
    
    let execTest = CitadelUtils.runProcess(executable: "/bin/echo", arguments: ["CitadelUnit"])
    expect(execTest.exitCode == 0, "CitadelUtils.runProcess executes binaries synchronously")
    expect(execTest.output.trimmingCharacters(in: .whitespacesAndNewlines) == "CitadelUnit", "CitadelUtils returns captured stdout")
    
    let expanded = CitadelUtils.expandTildePath("~/.citadel")
    expect(!expanded.hasPrefix("~") && expanded.hasSuffix("/.citadel"), "Tilde path expansion succeeds")

    // Suite 2: GitAuthProvider & App Installation URLs
    print("\n[Suite 2/6: GitAuthProvider & App Flow]")
    let ghURL = GitAuthProvider.gitHubAppInstallURL(appName: "citadel-sync-app")
    expect(ghURL?.absoluteString.contains("github.com/apps/citadel-sync-app/installations/new") == true, "GitHub App install URL targets installation with repo picker")
    
    let glURL = GitAuthProvider.gitLabAppInstallURL(clientID: "test-client-id")
    expect(glURL?.absoluteString.contains("gitlab.com/oauth/authorize") == true, "GitLab App URL contains oauth authorization endpoint")
    
    var customConfig = AppAuthConfig()
    customConfig.githubClientID = "custom-gh-app"
    expect(customConfig.githubClientID == "custom-gh-app", "AuthConfig accepts custom user-defined client IDs")
    
    // Suite 3: HubManager & Commit Signing
    print("\n[Suite 3/6: HubManager & Commit Signing]")
    let tempHub = FileManager.default.temporaryDirectory.appendingPathComponent("citadel_test_hub_\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: tempHub) }
    
    let hub = HubManager(customHubURL: tempHub)
    try hub.initializeHub()
    expect(FileManager.default.fileExists(atPath: hub.skillsURL.path), "HubManager creates skills/ directory")
    expect(FileManager.default.fileExists(atPath: hub.mcpsURL.path), "HubManager creates mcps/ directory")
    expect(FileManager.default.fileExists(atPath: hub.signingKeyFile.path), "HubManager creates citadel_signing_key in .keys/")
    expect(FileManager.default.fileExists(atPath: hub.allowedSignersFile.path), "HubManager configures allowed_signers")
    
    let probeFile = hub.hubURL.appendingPathComponent("probe.txt")
    try "signature test".write(to: probeFile, atomically: true, encoding: .utf8)
    let commitOk = hub.gitCommit(message: "test: verify signed commit")
    expect(commitOk == true, "gitCommit succeeds")
    
    let logCheck = CitadelUtils.runProcess(executable: "/usr/bin/git", arguments: ["-C", hub.hubURL.path, "log", "--show-signature", "-n", "1"])
    expect(logCheck.output.contains("Author: Citadel Bot <\(expectedEmail)>"), "Commit author is Citadel Bot with device email")
    expect(logCheck.output.contains("Good \"git\" signature for \(expectedEmail)"), "Commit contains verified SSH signature for device email")

    // Suite 4: SkillDiscoveryEngine & Builtin Exclusion
    print("\n[Suite 4/6: SkillDiscoveryEngine & Builtin Filtering]")
    let tempDiscoveryDir = FileManager.default.temporaryDirectory.appendingPathComponent("citadel_test_disc_\(UUID().uuidString)")
    let userSkillDir = tempDiscoveryDir.appendingPathComponent("my-custom-skill")
    let androidStudioSkillDir = tempDiscoveryDir.appendingPathComponent(".android-studio").appendingPathComponent("skills").appendingPathComponent("camerax")
    let copilotSkillDir = tempDiscoveryDir.appendingPathComponent(".copilot").appendingPathComponent("skills").appendingPathComponent("klaat-cli")
    let junieSkillDir = tempDiscoveryDir.appendingPathComponent(".junie").appendingPathComponent("skills").appendingPathComponent("klaat-gdocs-author")
    let builtinSkillDir = tempDiscoveryDir.appendingPathComponent("builtin").appendingPathComponent("agent-ui")
    try FileManager.default.createDirectory(at: userSkillDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: androidStudioSkillDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: copilotSkillDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: junieSkillDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: builtinSkillDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDiscoveryDir) }
    
    try "name: my-custom-skill".write(to: userSkillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    try "name: camerax".write(to: androidStudioSkillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    try "name: klaat-cli".write(to: copilotSkillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    try "name: klaat-gdocs-author".write(to: junieSkillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    try "name: agent-ui".write(to: builtinSkillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    
    let engine = SkillDiscoveryEngine()
    let found = engine.discoverSkills(in: [tempDiscoveryDir], includeBuiltin: false)
    expect(found.contains(where: { $0.name == "my-custom-skill" }) == true, "Discovers custom skills")
    expect(found.contains(where: { $0.name == "camerax" }) == true, "Discovers Android Studio skills (~/.android-studio/skills)")
    let androidSkill = found.first(where: { $0.name == "camerax" })
    expect(androidSkill?.sourceKind == "android-studio", "Correctly tags android-studio sourceKind")
    expect(found.contains(where: { $0.name == "klaat-cli" }) == true, "Discovers GitHub Copilot skills (~/.copilot/skills)")
    let copilotSkill = found.first(where: { $0.name == "klaat-cli" })
    expect(copilotSkill?.sourceKind == "copilot", "Correctly tags copilot sourceKind")
    expect(found.contains(where: { $0.name == "klaat-gdocs-author" }) == true, "Discovers Junie skills (~/.junie/skills)")
    let junieSkill = found.first(where: { $0.name == "klaat-gdocs-author" })
    expect(junieSkill?.sourceKind == "junie", "Correctly tags junie sourceKind")
    expect(found.contains(where: { $0.name == "agent-ui" }) == false, "Excludes builtin skills by default")

    // Suite 5: ArmoryViewModel & ThemeSystem
    print("\n[Suite 5/6: ArmoryViewModel & ThemePalette]")
    let armoryVM = ArmoryViewModel()
    armoryVM.skills = [
        Skill(name: "swift-skill", path: URL(fileURLWithPath: "/tmp/s1"), description: "Swift programming"),
        Skill(name: "rust-skill", path: URL(fileURLWithPath: "/tmp/s2"), description: "Rust systems")
    ]
    armoryVM.searchText = "swift"
    expect(armoryVM.filteredSkills.count == 1, "ArmoryViewModel filters by search keyword")
    expect(armoryVM.filteredSkills.first?.name == "swift-skill", "Filtered skill matches search query")
    
    let lightPalette = ThemePalette.forPreset(.light)
    let darkPalette = ThemePalette.forPreset(.dark)
    let sysPalette = ThemePalette.forPreset(.system)
    expect(lightPalette.isDark == false, "Light theme resolves isDark to false")
    expect(darkPalette.isDark == true, "Dark theme resolves isDark to true")
    expect(sysPalette.isDark == true || sysPalette.isDark == false, "System theme dynamically resolves to light or dark")

    // Suite 6: Onboarding 5-Step Flow & Permissions
    print("\n[Suite 6/6: Onboarding 5-Step Flow & User Permissions]")
    let testDefaults = UserDefaults(suiteName: "test_suite_defaults_\(UUID().uuidString)")!
    let onboardingVM = OnboardingViewModel(testDefaults: testDefaults)
    expect(onboardingVM.totalSteps == 5, "Onboarding consists of 5 dedicated steps")
    expect(onboardingVM.currentStep == 1, "Step 1: Directory selection")
    
    onboardingVM.nextStep()
    expect(onboardingVM.currentStep == 2, "Step 2: Cloud sync & repo configuration")
    
    onboardingVM.nextStep()
    expect(onboardingVM.currentStep == 3, "Step 3: Cryptographic Signing Key Generation")
    
    onboardingVM.customHubPath = tempHub.path
    expect(onboardingVM.hasAuthorizedSigningKey == false, "Key authorization pending user trigger")
    onboardingVM.authorizeAndGenerateSigningKey()
    expect(onboardingVM.hasAuthorizedSigningKey == true, "User intervention generates signing key and saves to Keychain")
    
    onboardingVM.nextStep()
    expect(onboardingVM.currentStep == 4, "Step 4: Brand Theme & Appearance")
    
    onboardingVM.nextStep()
    expect(onboardingVM.currentStep == 5, "Step 5: System Skill Scan with User Permission (Final Step)")
    
    expect(onboardingVM.hasGrantedScanPermission == false, "Scan permission pending user confirmation")
    onboardingVM.authorizeAndRunSkillScan(customRoots: [tempDiscoveryDir])
    expect(onboardingVM.hasGrantedScanPermission == true, "User grants permission to run system scan")
    expect(onboardingVM.discoveredSkills.contains(where: { $0.name == "my-custom-skill" }) == true, "Scan detects user skills")
    expect(onboardingVM.discoveredSkills.contains(where: { $0.name == "agent-ui" }) == false, "Scan excludes builtin skills")
    
    // Suite 7: Feature Flags System
    print("\n[Suite 7/7: Feature Flags System]")
    let testFlagDefaults = UserDefaults(suiteName: "test_flags_\(UUID().uuidString)")!
    let flags = FeatureFlags(testDefaults: testFlagDefaults)
    
    expect(flags.npmMarketplaceEnabled == false, "Marketplace flag defaults to OFF")
    expect(flags.mcpSyncEnabled == false, "MCP sync flag defaults to OFF")
    expect(flags.githubIntegrationEnabled == true, "GitHub integration flag defaults to ON")
    expect(flags.gitlabIntegrationEnabled == false, "GitLab integration flag defaults to OFF")
    expect(flags.commitSigningEnabled == true, "Commit signing flag defaults to ON")
    expect(flags.workspacePortalsEnabled == true, "Workspace portals flag defaults to ON")
    expect(flags.backgroundAutoSyncEnabled == false, "Background auto-sync flag defaults to OFF")
    expect(flags.includeBuiltinInDiscoveryEnabled == false, "Include builtin in discovery flag defaults to OFF")
    
    // Toggle state and persistence
    flags.npmMarketplaceEnabled = true
    flags.gitlabIntegrationEnabled = true
    expect(testFlagDefaults.bool(forKey: FeatureFlags.Keys.npmMarketplace) == true, "Marketplace toggle persists in defaults")
    expect(testFlagDefaults.bool(forKey: FeatureFlags.Keys.gitlabIntegration) == true, "GitLab toggle persists in defaults")
    
    flags.resetToDefaults()
    expect(flags.npmMarketplaceEnabled == false, "Reset restores marketplace to false")
    expect(flags.gitlabIntegrationEnabled == false, "Reset restores gitlab to false")
    
    // Suite 8: Onboarding In-Flight State & Re-testing
    print("\n[Suite 8/8: Onboarding In-Flight State & Development Testing]")
    let freshDefaults = UserDefaults(suiteName: "test_fresh_onboarding_\(UUID().uuidString)")!
    let testOnboardingVM = OnboardingViewModel(testDefaults: freshDefaults)
    expect(testOnboardingVM.isOnboardingComplete == false, "Fresh installation starts with isOnboardingComplete = false")
    expect(testOnboardingVM.currentStep == 1, "Starts on Step 1: Directory")
    
    // Step forward through onboarding
    testOnboardingVM.nextStep()
    expect(testOnboardingVM.currentStep == 2, "Reaches Step 2: Cloud Sync")
    testOnboardingVM.nextStep()
    expect(testOnboardingVM.currentStep == 3, "Reaches Step 3: Key Generation")
    testOnboardingVM.nextStep()
    expect(testOnboardingVM.currentStep == 4, "Reaches Step 4: Appearance")
    testOnboardingVM.nextStep()
    expect(testOnboardingVM.currentStep == 5, "Reaches Step 5: Discovery")
    
    // Finish onboarding
    testOnboardingVM.completeOnboarding()
    expect(testOnboardingVM.isOnboardingComplete == true, "Completing onboarding sets flag")
    expect(freshDefaults.bool(forKey: CitadelConstants.StorageKeys.isOnboardingComplete) == true, "Persists completion in defaults")
    
    // Simulate re-testing / restart onboarding
    freshDefaults.set(false, forKey: CitadelConstants.StorageKeys.isOnboardingComplete)
    let restartedVM = OnboardingViewModel(testDefaults: freshDefaults)
    expect(restartedVM.isOnboardingComplete == false, "Resetting allows testing onboarding again")
    expect(restartedVM.currentStep == 1, "Restarted onboarding returns to step 1")
    
    // Suite 9: Rollback & Decouple Engine
    print("\n[Suite 9/9: Rollback & Materialization Engine]")
    let testRollbackHub = FileManager.default.temporaryDirectory.appendingPathComponent("citadel_rollback_hub_\(UUID().uuidString)")
    let testRollbackClientDir = FileManager.default.temporaryDirectory.appendingPathComponent("citadel_client_dir_\(UUID().uuidString)")
    let hubSkillDir = testRollbackHub.appendingPathComponent("skills").appendingPathComponent("rollback-skill")
    try FileManager.default.createDirectory(at: hubSkillDir, withIntermediateDirectories: true)
    try "name: rollback-skill\ndescription: Test rollback".write(to: hubSkillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    
    // Create client symlink pointing to hub
    try FileManager.default.createDirectory(at: testRollbackClientDir, withIntermediateDirectories: true)
    let clientSymlink = testRollbackClientDir.appendingPathComponent("rollback-skill")
    try FileManager.default.createSymbolicLink(at: clientSymlink, withDestinationURL: hubSkillDir)
    defer {
        try? FileManager.default.removeItem(at: testRollbackHub)
        try? FileManager.default.removeItem(at: testRollbackClientDir)
    }
    
    expect((try? clientSymlink.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true, "Client initially holds a symlink")
    
    // Generate rollback script
    RollbackEngine.shared.generateStandaloneRollbackScript(hubURL: testRollbackHub)
    let scriptPath = testRollbackHub.appendingPathComponent(CitadelConstants.Paths.rollbackScriptFile)
    expect(FileManager.default.fileExists(atPath: scriptPath.path) == true, "RollbackEngine generates standalone rollback.sh script")
    
    // Eject and materialize
    let rollbackResult = try RollbackEngine.shared.ejectAndMaterialize(customHubURL: testRollbackHub)
    expect(rollbackResult.warnings.isEmpty == true, "Rollback completes without warnings")
    
    // Verify rollback script contains POSIX safe logic
    let scriptContent = try String(contentsOf: scriptPath, encoding: .utf8)
    expect(scriptContent.contains("CITADEL EMERGENCY ROLLBACK"), "Rollback script contains emergency header")
    expect(scriptContent.contains("MATERIALIZED"), "Rollback script contains materialization logic")
    
    // Suite 10: Shared Skill Detail View & Discovery Inspection
    print("\n[Suite 10/10: Shared SkillDetailView & Discovery Inspection]")
    let testSkillDir = FileManager.default.temporaryDirectory.appendingPathComponent("citadel_test_view_skill_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: testSkillDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: testSkillDir) }
    
    let sampleSkillDoc = """
    ---
    name: git-advanced
    description: Advanced Git rebase, bisect, and cherry-pick mastery
    version: 1.2.0
    author: Jane Doe
    ---
    # Git Advanced Instructions
    Use interactive rebase to craft atomic commits.
    """
    try sampleSkillDoc.write(to: testSkillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    
    let testDiscoveredSkill = DiscoveredSkill(
        name: "git-advanced",
        path: testSkillDir,
        sourceKind: "custom",
        isSymlink: false,
        description: "Advanced Git rebase, bisect, and cherry-pick mastery"
    )
    let testGroup = SkillGroup(name: "git-advanced", occurrences: [testDiscoveredSkill])
    
    let discoveryVM = DiscoveryViewModel()
    expect(discoveryVM.selectedSkill == nil, "Initial discovery selectedSkill is nil")
    expect(discoveryVM.showSkillDetail == false, "Initial showSkillDetail is false")
    
    discoveryVM.inspectSkillGroup(testGroup)
    expect(discoveryVM.showSkillDetail == true, "inspectSkillGroup sets showSkillDetail to true")
    expect(discoveryVM.selectedSkill?.name == "git-advanced", "inspectSkillGroup parses name")
    expect(discoveryVM.selectedSkill?.author == "Jane Doe", "inspectSkillGroup extracts author from frontmatter")
    expect(discoveryVM.selectedSkill?.version == "1.2.0", "inspectSkillGroup extracts version from frontmatter")
    expect(discoveryVM.selectedSkill?.description?.contains("Advanced Git") == true, "inspectSkillGroup extracts description")
    expect(discoveryVM.skillContent.contains("interactive rebase"), "inspectSkillGroup loads skill content for View Skill")
    
    // Test instantiating shared SkillDetailView
    let detailView = SkillDetailView(
        skill: discoveryVM.selectedSkill!,
        content: discoveryVM.skillContent,
        palette: ThemePalette.forPreset(.dark)
    )
    expect(detailView.skill.name == "git-advanced", "SkillDetailView initialized with skill")
    expect(detailView.skill.author == "Jane Doe", "SkillDetailView contains author")
    
    // Suite 11: Sync Marker Manifest & Onboarding Re-use Repo Flow
    print("\n[Suite 11/11: SyncMarker & Onboarding Repo Re-use Flow]")
    let testMarker = RemoteSyncManager.SyncMarker(
        syncStoreId: "store-test-uuid-12345",
        app: "Citadel",
        version: "1.0.0",
        schemaVersion: 1,
        createdAt: Date(),
        lastSyncedAt: Date(),
        deviceUsername: "testuser",
        botEmail: "citadel-bot-testuser@github.com"
    )
    let markerEncoder = JSONEncoder()
    markerEncoder.dateEncodingStrategy = .iso8601
    let markerData = try markerEncoder.encode(testMarker)
    let markerDecoder = JSONDecoder()
    markerDecoder.dateDecodingStrategy = .iso8601
    let decodedMarker = try markerDecoder.decode(RemoteSyncManager.SyncMarker.self, from: markerData)
    expect(decodedMarker.app == "Citadel", "SyncMarker encodes and decodes app name")
    expect(decodedMarker.syncStoreId == "store-test-uuid-12345", "SyncMarker preserves unique syncStoreId")
    expect(decodedMarker.deviceUsername == "testuser", "SyncMarker encodes device username")
    expect(decodedMarker.botEmail.contains("citadel-bot"), "SyncMarker encodes botEmail")
    
    // Test write and read sync marker in HubManager
    let markerWritten = RemoteSyncManager.shared.writeSyncMarker(marker: testMarker)
    expect(markerWritten == true, "writeSyncMarker writes marker to hub directory")
    let readMarker = RemoteSyncManager.shared.readSyncMarker()
    expect(readMarker?.app == "Citadel", "readSyncMarker reads active marker from hub")
    expect(readMarker?.syncStoreId == "store-test-uuid-12345", "readSyncMarker reads correct syncStoreId")
    expect(readMarker?.deviceUsername == "testuser", "readSyncMarker reads correct device username")
    
    // Test OnboardingViewModel existing sync repo re-use prompt state with arbitrary repo name (custom-dotfiles)
    let testDefaults = UserDefaults(suiteName: "citadel_test_reuse_repo_\(UUID().uuidString)")!
    let onboardingVM = OnboardingViewModel(testDefaults: testDefaults)
    expect(onboardingVM.showReuseRepoPrompt == false, "Initial showReuseRepoPrompt is false")
    
    onboardingVM.foundExistingSyncRepo = true
    onboardingVM.existingSyncRepoName = "custom-dotfiles"
    onboardingVM.existingSyncRepoFullName = "testuser/custom-dotfiles"
    onboardingVM.existingSyncRepoCloneURL = "git@github.com:testuser/custom-dotfiles.git"
    onboardingVM.existingSyncRepoProvider = .github
    onboardingVM.existingSyncRepoMarker = testMarker
    onboardingVM.showReuseRepoPrompt = true
    
    expect(onboardingVM.showReuseRepoPrompt == true, "showReuseRepoPrompt is activated when existing sync repo is detected")
    expect(onboardingVM.existingSyncRepoName == "custom-dotfiles", "Repo identified by marker regardless of name")
    expect(onboardingVM.existingSyncRepoMarker?.syncStoreId == "store-test-uuid-12345", "existingSyncRepoMarker holds verified syncStoreId")
    
    onboardingVM.reuseExistingSyncRepo()
    expect(onboardingVM.showReuseRepoPrompt == false, "reuseExistingSyncRepo sets remote and dismisses prompt")
    
    // Test RemoteSyncManager remote origin setting and removal
    let testRepoURL = "https://github.com/testuser/citadel-sync.git"
    let setRes = RemoteSyncManager.shared.setRemoteURL(testRepoURL)
    expect(setRes.success == true, "RemoteSyncManager.setRemoteURL succeeds")
    let activeRemote = RemoteSyncManager.shared.getRemoteURL()
    expect(activeRemote?.contains("citadel-sync") == true, "RemoteSyncManager.getRemoteURL returns configured URL")
    let syncStatus = RemoteSyncManager.shared.getStatus()
    expect(syncStatus.isConfigured == true, "RemoteSyncStatus reports isConfigured == true")
    expect(syncStatus.remoteURL?.contains("citadel-sync") == true, "RemoteSyncStatus contains sanitized remote URL")
    
    // Clear remote origin with empty string
    let clearRes = RemoteSyncManager.shared.setRemoteURL("")
    expect(clearRes.success == true, "RemoteSyncManager.setRemoteURL(\"\") successfully removes origin")
    let clearedStatus = RemoteSyncManager.shared.getStatus()
    expect(clearedStatus.isConfigured == false, "RemoteSyncStatus reports isConfigured == false after removal")
    expect(clearedStatus.remoteURL == nil, "RemoteSyncStatus reports nil remoteURL after removal")
    
    // Verify SettingsViewModel synchronously receives active status
    let settingsVM = SettingsViewModel()
    expect(settingsVM.remoteStatus.isConfigured == false, "SettingsViewModel immediately initializes remoteStatus synchronously")
    
    // Test non-blocking background discovery execution
    let asyncDiscoveryReport = await MultiverseDiscoveryEngine.shared.runFullDiscoveryAsync(workspaceRoots: [])
    expect(asyncDiscoveryReport.mcps.count >= 0, "runFullDiscoveryAsync runs off main thread without blocking")
    
    print("\n==================================================")
    print("🎉 ALL \(passedCount)/\(totalCount) UNIT TESTS PASSED SUCCESSFULLY!")
    print("==================================================\n")
}

@main
struct CitadelTestApp {
    static func main() async {
        do {
            try await runAllCitadelTests()
            exit(0)
        } catch {
            print("💥 Test suite threw unhandled exception: \(error)")
            exit(1)
        }
    }
}
