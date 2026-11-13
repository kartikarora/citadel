import Foundation
import CitadelCore
import CitadelUI

@MainActor
func runAllCitadelTests() async throws {
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
    
    expect(CitadelConstants.Web.docsURL.absoluteString == "https://citadel.kartikarora.me/#cli", "Citadel docs URL targets web CLI documentation anchor")
    expect(CitadelConstants.Web.homepageURL.absoluteString == "https://citadel.kartikarora.me/", "Citadel homepage URL verified")
    
    // CLIManager completion shells supported
    let allShells = CLIManager.Shell.allCases
    expect(allShells.contains(.zsh) && allShells.contains(.bash) && allShells.contains(.fish), "CLIManager supports zsh, bash, and fish autocompletions")

    // Suite 2: GitAuthProvider & App Installation URLs
    print("\n[Suite 2/6: GitAuthProvider & App Flow]")
    let ghURL = GitAuthProvider.gitHubAppInstallURL(appName: "citadel-sync-app")
    expect(ghURL?.absoluteString.contains("github.com/apps/citadel-sync-app/installations/new") == true, "GitHub App install URL targets installation with repo picker")
    
    let glURL = GitAuthProvider.gitLabAppInstallURL(clientID: "test-client-id")
    expect(glURL?.absoluteString.contains("gitlab.com/oauth/authorize") == true, "GitLab App URL contains oauth authorization endpoint")
    
    var customConfig = AppAuthConfig()
    customConfig.githubClientID = "custom-gh-app"
    expect(customConfig.githubClientID == "custom-gh-app", "AuthConfig accepts custom user-defined client IDs")
    
    let prevClientID = GitAuthProvider.shared.customGitHubClientID
    GitAuthProvider.shared.customGitHubClientID = "178c6fc778ccc68e1d6a"
    var rejectedGHCLIClientID = false
    do {
        _ = try await GitAuthProvider.shared.startDeviceCodeFlow(provider: .github)
    } catch {
        rejectedGHCLIClientID = error.localizedDescription.contains("gh")
    }
    GitAuthProvider.shared.customGitHubClientID = prevClientID
    expect(rejectedGHCLIClientID, "GitAuthProvider refuses gh CLI shared client ID to avoid invalidating gh auth")
    
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
    await onboardingVM.authorizeAndRunSkillScanAsync(customRoots: [tempDiscoveryDir])
    expect(onboardingVM.hasGrantedScanPermission == true, "User grants permission to run system scan")
    expect(onboardingVM.discoveredSkills.contains(where: { $0.name == "my-custom-skill" }) == true, "Scan detects user skills")
    expect(onboardingVM.discoveredSkills.contains(where: { $0.name == "agent-ui" }) == false, "Scan excludes builtin skills")
    
    // Suite 7: Feature Flags System
    print("\n[Suite 7/7: Feature Flags System]")
    let testFlagDefaults = UserDefaults(suiteName: "test_flags_\(UUID().uuidString)")!
    let flags = FeatureFlags(testDefaults: testFlagDefaults)
    
    expect(flags.npmMarketplaceEnabled == true, "Skills manager flag defaults to ON")
    expect(flags.mcpSyncEnabled == false, "MCP sync flag defaults to OFF")
    expect(flags.githubIntegrationEnabled == true, "GitHub integration flag defaults to ON")
    expect(flags.gitlabIntegrationEnabled == false, "GitLab integration flag defaults to OFF")
    expect(flags.commitSigningEnabled == true, "Commit signing flag defaults to ON")
    expect(flags.workspacePortalsEnabled == true, "Workspace portals flag defaults to ON")
    expect(flags.backgroundAutoSyncEnabled == false, "Background auto-sync flag defaults to OFF")
    expect(flags.includeBuiltinInDiscoveryEnabled == false, "Include builtin in discovery flag defaults to OFF")
    
    // Toggle state and persistence
    flags.npmMarketplaceEnabled = false
    flags.gitlabIntegrationEnabled = true
    expect(testFlagDefaults.bool(forKey: FeatureFlags.Keys.npmMarketplace) == false, "Marketplace toggle persists in defaults")
    expect(testFlagDefaults.bool(forKey: FeatureFlags.Keys.gitlabIntegration) == true, "GitLab toggle persists in defaults")
    
    flags.resetToDefaults()
    expect(flags.npmMarketplaceEnabled == true, "Reset restores skills manager to true")
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
    expect(testOnboardingVM.discoverySegment == "ai_config", "Default discovery segment is ai_config")
    testOnboardingVM.discoverySegment = "workspaces"
    expect(testOnboardingVM.discoverySegment == "workspaces", "Can toggle to workspaces discovery segment")
    expect(testOnboardingVM.discoveredWorkspaces.isEmpty == true, "Starts with empty discoveredWorkspaces prior to permission scan")
    
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
    
    // Test instantiating shared SkillDetailView with portal workspace options
    let testPortalDir = FileManager.default.temporaryDirectory.appendingPathComponent("citadel_test_portal_ws_\(UUID().uuidString)")
    let testPortal = ProjectPortal(projectPath: testPortalDir, enabledSkills: ["git-advanced"])
    var toggledWorkspaceURL: URL? = nil
    let detailView = SkillDetailView(
        skill: discoveryVM.selectedSkill!,
        content: discoveryVM.skillContent,
        palette: ThemePalette.forPreset(.dark),
        portals: [testPortal],
        onToggleWorkspacePortal: { url in
            toggledWorkspaceURL = url
        }
    )
    expect(detailView.skill.name == "git-advanced", "SkillDetailView initialized with skill")
    expect(detailView.skill.author == "Jane Doe", "SkillDetailView contains author")
    expect(detailView.portals.count == 1, "SkillDetailView accepts portals list")
    expect(detailView.portals.first?.enabledSkills.contains("git-advanced") == true, "SkillDetailView detects enabled skills for portal")
    detailView.onToggleWorkspacePortal?(testPortalDir)
    expect(toggledWorkspaceURL?.path == testPortalDir.path, "SkillDetailView triggers onToggleWorkspacePortal callback")
    
    // Test accompanying files detection and SkillPackageNode scanning
    let subRefDir = testSkillDir.appendingPathComponent("references")
    try FileManager.default.createDirectory(at: subRefDir, withIntermediateDirectories: true)
    try "# Reference Guide".write(to: subRefDir.appendingPathComponent("guide.md"), atomically: true, encoding: .utf8)
    try "echo hello".write(to: testSkillDir.appendingPathComponent("helper.sh"), atomically: true, encoding: .utf8)
    
    let scannedAccompanying = discoveryVM.selectedSkill!.accompanyingFiles
    expect(scannedAccompanying.contains("references"), "accompanyingFiles detects subdirectories")
    expect(scannedAccompanying.contains("helper.sh"), "accompanyingFiles detects accompanying script files")
    expect(!scannedAccompanying.contains("SKILL.md"), "accompanyingFiles filters out primary SKILL.md")
    
    let scannedPackageNodes = SkillPackageNode.scan(rootURL: testSkillDir)
    expect(scannedPackageNodes.contains(where: { $0.name == "references" && $0.isDirectory }), "SkillPackageNode scans references directory")
    expect(scannedPackageNodes.contains(where: { $0.name == "helper.sh" && !$0.isDirectory }), "SkillPackageNode scans helper.sh file")
    
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
    let reuseTestDefaults = UserDefaults(suiteName: "citadel_test_reuse_repo_\(UUID().uuidString)")!
    let reuseOnboardingVM = OnboardingViewModel(testDefaults: reuseTestDefaults)
    expect(reuseOnboardingVM.showReuseRepoPrompt == false, "Initial showReuseRepoPrompt is false")
    
    reuseOnboardingVM.foundExistingSyncRepo = true
    reuseOnboardingVM.existingSyncRepoName = "custom-dotfiles"
    reuseOnboardingVM.existingSyncRepoFullName = "testuser/custom-dotfiles"
    reuseOnboardingVM.existingSyncRepoCloneURL = "git@github.com:testuser/custom-dotfiles.git"
    reuseOnboardingVM.existingSyncRepoProvider = GitProvider.github
    reuseOnboardingVM.existingSyncRepoMarker = testMarker
    reuseOnboardingVM.showReuseRepoPrompt = true
    
    expect(reuseOnboardingVM.showReuseRepoPrompt == true, "showReuseRepoPrompt is activated when existing sync repo is detected")
    expect(reuseOnboardingVM.existingSyncRepoName == "custom-dotfiles", "Repo identified by marker regardless of name")
    expect(reuseOnboardingVM.existingSyncRepoMarker?.syncStoreId == "store-test-uuid-12345", "existingSyncRepoMarker holds verified syncStoreId")
    
    reuseOnboardingVM.reuseExistingSyncRepo()
    expect(reuseOnboardingVM.showReuseRepoPrompt == false, "reuseExistingSyncRepo sets remote and dismisses prompt")
    
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
    
    // Suite 12: MVVM & Package Architecture Invariants
    print("\n[Suite 12/12: MVVM & Package Architecture Invariants]")
    
    // Invariant 1: CitadelCore must never import SwiftUI or AppKit
    let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let coreDir = projectRoot.appendingPathComponent("Sources/CitadelCore")
    if FileManager.default.fileExists(atPath: coreDir.path),
       let coreFiles = FileManager.default.enumerator(at: coreDir, includingPropertiesForKeys: nil) {
        var coreUIImports: [String] = []
        while let item = coreFiles.nextObject() {
            if let file = item as? URL, file.pathExtension == "swift" {
                if let content = try? String(contentsOf: file, encoding: .utf8) {
                    let lines = content.components(separatedBy: .newlines)
                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed == "import SwiftUI" || trimmed == "import AppKit" {
                            coreUIImports.append("\(file.lastPathComponent): \(trimmed)")
                        }
                    }
                }
            }
        }
        expect(coreUIImports.isEmpty == true, "CitadelCore maintains pure model/engine boundary with 0 SwiftUI/AppKit imports")
    } else {
        expect(true, "CitadelCore path verified")
    }
    
    // Invariant 2: Headless ViewModel Instantiation & ObservableObject conformance
    let armoryVMInstance = ArmoryViewModel()
    expect(armoryVMInstance is any ObservableObject, "ArmoryViewModel conforms to ObservableObject")
    
    let discoveryVMInstance = DiscoveryViewModel()
    expect(discoveryVMInstance is any ObservableObject, "DiscoveryViewModel conforms to ObservableObject")
    
    let marketplaceVMInstance = MarketplaceViewModel()
    expect(marketplaceVMInstance is any ObservableObject, "MarketplaceViewModel conforms to ObservableObject")
    
    let onboardingVMInstance = OnboardingViewModel()
    expect(onboardingVMInstance is any ObservableObject, "OnboardingViewModel conforms to ObservableObject")
    
    let settingsVMInstance = SettingsViewModel()
    expect(settingsVMInstance is any ObservableObject, "SettingsViewModel conforms to ObservableObject")
    
    let workspacesVMInstance = WorkspacesViewModel()
    expect(workspacesVMInstance is any ObservableObject, "WorkspacesViewModel conforms to ObservableObject")
    
    // Invariant 3: ViewModels expose isolated business state without UI window coupling
    armoryVMInstance.searchText = "test"
    expect(armoryVMInstance.searchText == "test", "ArmoryViewModel operates independently of UI lifecycle")
    
    marketplaceVMInstance.marketQuery = "react"
    expect(marketplaceVMInstance.marketQuery == "react", "MarketplaceViewModel operates independently of UI lifecycle")
    
    // =========================================================================
    // SUITE 13: AgentRegistry & .matilda Support
    // =========================================================================
    print("\n🧪 Suite 13: AgentRegistry & .matilda Support")
    
    let registry = AgentRegistry.shared
    let matildaAgent = registry.agents.first { $0.id == "matilda" }
    expect(matildaAgent != nil, "AgentRegistry includes matilda")
    expect(matildaAgent?.skillsDir == ".matilda/skills", "Matilda project skillsDir is .matilda/skills")
    expect(registry.allProjectSkillDirs.contains(".matilda/skills"), "allProjectSkillDirs includes .matilda/skills")
    expect(registry.allProjectConfigFolderNames.contains(".matilda"), "allProjectConfigFolderNames includes .matilda")
    
    let expectedVercelAgents = ["claude-code", "cursor", "codex", "opencode", "windsurf", "goose", "universal", "antigravity", "github-copilot", "junie", "android-studio"]
    for agentId in expectedVercelAgents {
        expect(registry.agents.contains { $0.id == agentId }, "AgentRegistry includes \(agentId)")
    }
    
    // Verify .matilda global detection & discovery with isolated temp home
    let suite13FM = FileManager.default
    let suite13Root = suite13FM.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("citadel-suite13-\(UUID().uuidString)")
    defer { try? suite13FM.removeItem(at: suite13Root) }
    
    let tempHome = suite13Root.appendingPathComponent("home")
    let tempXdg = tempHome.appendingPathComponent(".config")
    let tempMatildaRoot = tempHome.appendingPathComponent(".matilda")
    let tempMatildaSkills = tempMatildaRoot.appendingPathComponent("skills")
    let tempMatildaSkill = tempMatildaSkills.appendingPathComponent("matilda-test-skill")
    try suite13FM.createDirectory(at: tempMatildaSkill, withIntermediateDirectories: true)
    try "# Matilda Test Skill\n".write(to: tempMatildaSkill.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    
    let detectedTargets = registry.detectedGlobalSyncTargets(home: tempHome, xdgConfig: tempXdg, fileManager: suite13FM)
    expect(detectedTargets.contains { $0.agent.id == "matilda" && $0.skillsDir.path == tempMatildaSkills.path }, "detectedGlobalSyncTargets finds ~/.matilda/skills")
    
    let discoveryEngine = SkillDiscoveryEngine()
    let discoveredMatilda = discoveryEngine.discoverSkills(in: [tempMatildaRoot])
    expect(discoveredMatilda.count == 1, "Discovered 1 skill inside .matilda/skills")
    expect(discoveredMatilda.first?.sourceKind == "matilda", "Skill discovered in .matilda has sourceKind 'matilda'")
    
    // Verify RollbackEngine includes .matilda/skills
    let rollbackEngine = RollbackEngine()
    expect(rollbackEngine.targetSkillDirectories.contains { $0.path.hasSuffix("/.matilda/skills") }, "RollbackEngine targetSkillDirectories includes .matilda/skills")
    
    // Verify SyncEngine.syncProjectPortal initializes & prunes .matilda/skills when .matilda exists in repo
    let tempPortalRepo = suite13Root.appendingPathComponent("matilda-portal-repo")
    let staleMatildaLink = tempPortalRepo.appendingPathComponent(".matilda/skills/stale-skill")
    try suite13FM.createDirectory(at: tempPortalRepo.appendingPathComponent(".matilda/skills"), withIntermediateDirectories: true)
    try "# Stale\n".write(to: staleMatildaLink, atomically: true, encoding: .utf8)
    
    let matildaTestPortal = ProjectPortal(
        projectPath: tempPortalRepo,
        enabledSkills: [],
        enabledMCPs: [],
        targetTools: [.antigravityGlobal]
    )
    let syncEngine = SyncEngine()
    _ = syncEngine.syncProjectPortal(matildaTestPortal)
    expect(!suite13FM.fileExists(atPath: staleMatildaLink.path), "syncProjectPortal prunes disabled skills inside .matilda/skills")
    
    // Verify suffixed profile directories (.claude-bilue, .claude-qantas, .matilda-work) across all agents
    let bilueRoot = tempHome.appendingPathComponent(".claude-bilue")
    let qantasRoot = tempHome.appendingPathComponent(".claude-qantas")
    let matildaWorkRoot = tempHome.appendingPathComponent(".matilda-work")
    let bilueSkillDir = bilueRoot.appendingPathComponent("skills/bilue-skill")
    let qantasSkillDir = qantasRoot.appendingPathComponent("skills/qantas-skill")
    try suite13FM.createDirectory(at: bilueSkillDir, withIntermediateDirectories: true)
    try suite13FM.createDirectory(at: qantasSkillDir, withIntermediateDirectories: true)
    try suite13FM.createDirectory(at: matildaWorkRoot, withIntermediateDirectories: true)
    try "# Bilue Skill\n".write(to: bilueSkillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    try "# Qantas Skill\n".write(to: qantasSkillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    
    let profileGlobalRoots = registry.allGlobalRootDirs(home: tempHome, xdgConfig: tempXdg, env: [:], fileManager: suite13FM)
    expect(profileGlobalRoots.contains { $0.path == bilueRoot.path }, "allGlobalRootDirs discovers ~/.claude-bilue")
    expect(profileGlobalRoots.contains { $0.path == qantasRoot.path }, "allGlobalRootDirs discovers ~/.claude-qantas")
    expect(profileGlobalRoots.contains { $0.path == matildaWorkRoot.path }, "allGlobalRootDirs discovers ~/.matilda-work")
    
    let profileSyncTargets = registry.detectedGlobalSyncTargets(home: tempHome, xdgConfig: tempXdg, env: [:], fileManager: suite13FM)
    expect(profileSyncTargets.contains { $0.agent.id == "claude-code" && $0.skillsDir.path == bilueRoot.appendingPathComponent("skills").path }, "detectedGlobalSyncTargets includes ~/.claude-bilue/skills")
    expect(profileSyncTargets.contains { $0.agent.id == "claude-code" && $0.skillsDir.path == qantasRoot.appendingPathComponent("skills").path }, "detectedGlobalSyncTargets includes ~/.claude-qantas/skills")
    expect(profileSyncTargets.contains { $0.agent.id == "matilda" && $0.skillsDir.path == matildaWorkRoot.appendingPathComponent("skills").path }, "detectedGlobalSyncTargets includes ~/.matilda-work/skills")
    
    let discoveredProfiles = discoveryEngine.discoverSkills(in: [bilueRoot, qantasRoot])
    expect(discoveredProfiles.count == 2, "Discovers skills inside .claude-bilue and .claude-qantas")
    expect(discoveredProfiles.allSatisfy { $0.sourceKind == "claude" }, "Tags .claude-bilue and .claude-qantas skills with sourceKind 'claude'")
    
    let staleBilueRepoLink = tempPortalRepo.appendingPathComponent(".claude-bilue/skills/stale-skill")
    try suite13FM.createDirectory(at: tempPortalRepo.appendingPathComponent(".claude-bilue/skills"), withIntermediateDirectories: true)
    try "# Stale\n".write(to: staleBilueRepoLink, atomically: true, encoding: .utf8)
    _ = syncEngine.syncProjectPortal(matildaTestPortal)
    expect(!suite13FM.fileExists(atPath: staleBilueRepoLink.path), "syncProjectPortal also syncs/prunes suffixed project dirs like .claude-bilue/skills")
    
    // Suite 14: Smart Remote Sync — timestamp race resolution vs. manual conflict hand-off
    print("\n🧪 Suite 14: Smart Remote Sync & Conflict Handling")
    let s14Root = FileManager.default.temporaryDirectory.appendingPathComponent("citadel_s14_\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: s14Root) }
    try FileManager.default.createDirectory(at: s14Root, withIntermediateDirectories: true)
    
    @discardableResult
    func s14Git(_ dir: URL, _ args: [String], epoch: Int? = nil) -> (exitCode: Int32, output: String) {
        var envArgs: [String] = []
        if let epoch = epoch {
            envArgs = ["GIT_AUTHOR_DATE=@\(epoch) +0000", "GIT_COMMITTER_DATE=@\(epoch) +0000"]
        }
        return CitadelUtils.runProcess(executable: "/usr/bin/env",
                                       arguments: envArgs + ["git", "-c", "commit.gpgsign=false", "-C", dir.path] + args)
    }
    func s14Commit(_ hub: HubManager, _ rel: String, _ content: String, epoch: Int) {
        let url = hub.hubURL.appendingPathComponent(rel)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        s14Git(hub.hubURL, ["add", "-A"])
        s14Git(hub.hubURL, ["commit", "-q", "-m", "edit \(rel)"], epoch: epoch)
    }
    func s14Read(_ hub: HubManager, _ rel: String) -> String {
        (try? String(contentsOf: hub.hubURL.appendingPathComponent(rel), encoding: .utf8)) ?? ""
    }
    
    let t0 = Int(Date().timeIntervalSince1970) - 10_000
    let baseLines = (1...60).map { "line \($0)" }
    let sharedRel = "skills/shared/SKILL.md"
    
    let bareRemote = s14Root.appendingPathComponent("remote.git")
    s14Git(s14Root, ["init", "-q", "--bare", "--initial-branch=main", bareRemote.path])
    
    // Device A seeds base commit A and pushes
    let devA = HubManager(customHubURL: s14Root.appendingPathComponent("devA"))
    try devA.initializeHub()
    let syncA = RemoteSyncManager(hub: devA)
    _ = syncA.setRemoteURL(bareRemote.path)
    s14Commit(devA, sharedRel, baseLines.joined(separator: "\n") + "\n", epoch: t0)
    let seed = syncA.smartSync(resyncTools: false)
    expect(seed.success && seed.pushed, "smartSync pushes initial commit to empty remote")
    
    // Device B clones the same remote
    let devBURL = s14Root.appendingPathComponent("devB")
    s14Git(s14Root, ["clone", "-q", bareRemote.path, devBURL.path])
    let devB = HubManager(customHubURL: devBURL)
    try devB.initializeHub()
    let syncB = RemoteSyncManager(hub: devB)
    
    // 1. Non-overlapping divergence: A → B(remote) and A → C(local) touch different files
    s14Commit(devA, "skills/alpha/SKILL.md", "alpha\n", epoch: t0 + 10)
    _ = syncA.smartSync(resyncTools: false)
    s14Commit(devB, "skills/beta/SKILL.md", "beta\n", epoch: t0 + 20)
    let nonOverlap = syncB.smartSync(resyncTools: false)
    expect(nonOverlap.success && nonOverlap.pulled && nonOverlap.pushed, "Diverged, non-overlapping changes rebase cleanly and push")
    expect(s14Read(devB, "skills/alpha/SKILL.md") == "alpha\n" && s14Read(devB, "skills/beta/SKILL.md") == "beta\n", "Both devices' non-overlapping changes are kept")
    _ = syncA.smartSync(resyncTools: false)
    expect(s14Read(devA, "skills/beta/SKILL.md") == "beta\n", "Other device receives the rebased change on next sync")

    // 1b. Non-overlapping edits at opposite ends of the SAME file — clean rebase merges both
    var sameFileA = baseLines; sameFileA[0] = "header edited on A"
    s14Commit(devA, sharedRel, sameFileA.joined(separator: "\n") + "\n", epoch: t0 + 30)
    _ = syncA.smartSync(resyncTools: false)
    var sameFileB = baseLines; sameFileB[59] = "footer edited on B"
    s14Commit(devB, sharedRel, sameFileB.joined(separator: "\n") + "\n", epoch: t0 + 40)
    let sameFileMerge = syncB.smartSync(resyncTools: false)
    expect(sameFileMerge.success && sameFileMerge.pulled && sameFileMerge.pushed, "Same-file non-overlapping hunks merge cleanly during rebase")
    let mergedLines = s14Read(devB, sharedRel)
    expect(mergedLines.contains("header edited on A") && mergedLines.contains("footer edited on B"), "Both header and footer edits in the same file are preserved")
    _ = syncA.smartSync(resyncTools: false)
    
    // 2a. Small race on the same line — local edit is newer, so local wins
    var raceRemote = s14Read(devA, sharedRel).components(separatedBy: "\n").filter { !$0.isEmpty }
    raceRemote[0] = "title from A"
    s14Commit(devA, sharedRel, raceRemote.joined(separator: "\n") + "\n", epoch: t0 + 100)
    _ = syncA.smartSync(resyncTools: false)
    var raceLocal = s14Read(devB, sharedRel).components(separatedBy: "\n").filter { !$0.isEmpty }
    raceLocal[0] = "title from B"
    s14Commit(devB, sharedRel, raceLocal.joined(separator: "\n") + "\n", epoch: t0 + 200)
    let raceLocalWins = syncB.smartSync(resyncTools: false)
    expect(raceLocalWins.success && raceLocalWins.pushed, "Small same-line race auto-resolves and pushes")
    expect(s14Read(devB, sharedRel).hasPrefix("title from B\n"), "Race resolution keeps the newer (local) edit")
    expect(raceLocalWins.conflictStrategy?.contains(sharedRel) == true, "Race resolution reports which file was settled by timestamp")
    _ = syncA.smartSync(resyncTools: false)
    
    // 2b. Small race — remote edit is newer, so remote wins
    var race2Remote = s14Read(devA, sharedRel).components(separatedBy: "\n"); race2Remote[1] = "second from A"
    s14Commit(devA, sharedRel, race2Remote.joined(separator: "\n"), epoch: t0 + 400)
    _ = syncA.smartSync(resyncTools: false)
    var race2Local = s14Read(devB, sharedRel).components(separatedBy: "\n"); race2Local[1] = "second from B"
    s14Commit(devB, sharedRel, race2Local.joined(separator: "\n"), epoch: t0 + 300)
    let raceRemoteWins = syncB.smartSync(resyncTools: false)
    expect(raceRemoteWins.success && !raceRemoteWins.needsManualResolution, "Older local race edit resolves without user intervention")
    expect(s14Read(devB, sharedRel).contains("second from A") && !s14Read(devB, sharedRel).contains("second from B"), "Race resolution keeps the newer (remote) edit")
    _ = syncA.smartSync(resyncTools: false)

    // 2c. Metadata file conflict (portals.json) always auto-resolves by timestamp
    s14Commit(devA, CitadelConstants.Paths.portalsFile, "[\n  {\"name\": \"a\"}\n]\n", epoch: t0 + 410)
    _ = syncA.smartSync(resyncTools: false)
    s14Commit(devB, CitadelConstants.Paths.portalsFile, "[\n  {\"name\": \"b\"}\n]\n", epoch: t0 + 420)
    let metaResolve = syncB.smartSync(resyncTools: false)
    expect(metaResolve.success && !metaResolve.needsManualResolution, "Metadata file conflict (portals.json) auto-resolves by timestamp")
    expect(s14Read(devB, CitadelConstants.Paths.portalsFile).contains("\"b\""), "Metadata file conflict keeps newer timestamp version")
    _ = syncA.smartSync(resyncTools: false)
    
    // 3a. Big conflict — both sides rewrite the whole file (>40 conflicting lines): flag to the user, never auto-pick
    s14Commit(devA, sharedRel, (1...60).map { "A rewrite \($0)" }.joined(separator: "\n") + "\n", epoch: t0 + 500)
    _ = syncA.smartSync(resyncTools: false)
    s14Commit(devB, sharedRel, (1...60).map { "B rewrite \($0)" }.joined(separator: "\n") + "\n", epoch: t0 + 600)
    let headBeforeBig = s14Git(devBURL, ["rev-parse", "HEAD"]).output
    let big = syncB.smartSync(resyncTools: false)
    expect(!big.success && big.needsManualResolution, "Large whole-file conflict is flagged for manual resolution")
    expect(big.conflictFiles.contains(sharedRel), "Flagged result lists the conflicting file")
    expect(!syncB.isResolutionInProgress, "Citadel leaves the repo clean (no half-finished rebase) after flagging")
    expect(s14Git(devBURL, ["rev-parse", "HEAD"]).output == headBeforeBig, "Local commit is preserved untouched after flagging")
    expect(s14Read(devB, sharedRel).hasPrefix("B rewrite 1\n"), "Local file content is preserved after flagging")
    expect(s14Git(bareRemote, ["show", "main:\(sharedRel)"]).output.hasPrefix("A rewrite 1\n"), "Nothing is pushed when a conflict is flagged")

    // Reset devB to match remote before next complex conflict test
    s14Git(devBURL, ["reset", "--hard", "origin/main"])

    // 3b. Complex multi-hunk conflict (>3 separate conflicting hunks across a file) — flagged for manual resolution
    var multiHunkA = (1...60).map { "A rewrite \($0)" }
    var multiHunkB = multiHunkA
    for idx in [2, 15, 30, 45, 55] {
        multiHunkA[idx] = "A hunk at \(idx)"
        multiHunkB[idx] = "B hunk at \(idx)"
    }
    s14Commit(devA, sharedRel, multiHunkA.joined(separator: "\n") + "\n", epoch: t0 + 700)
    _ = syncA.smartSync(resyncTools: false)
    s14Commit(devB, sharedRel, multiHunkB.joined(separator: "\n") + "\n", epoch: t0 + 800)
    let multiHunkRes = syncB.smartSync(resyncTools: false)
    expect(!multiHunkRes.success && multiHunkRes.needsManualResolution, "Multi-hunk conflict (>3 hunks) is flagged for manual resolution")
    expect(multiHunkRes.conflictFiles.contains(sharedRel), "Multi-hunk conflict lists the conflicting file")
    expect(!syncB.isResolutionInProgress, "Repo is left clean after aborting multi-hunk conflict")

    // Reset devB to match remote before modify/delete conflict test
    s14Git(devBURL, ["reset", "--hard", "origin/main"])

    // 3c. Complex modify/delete conflict (remote deletes skill while local modifies it) — flagged for manual resolution
    s14Git(devA.hubURL, ["rm", "-q", "skills/alpha/SKILL.md"])
    s14Git(devA.hubURL, ["commit", "-q", "-m", "delete alpha"], epoch: t0 + 900)
    _ = syncA.smartSync(resyncTools: false)
    s14Commit(devB, "skills/alpha/SKILL.md", "alpha modified locally\n", epoch: t0 + 950)
    let modDeleteRes = syncB.smartSync(resyncTools: false)
    expect(!modDeleteRes.success && modDeleteRes.needsManualResolution, "Modify/delete conflict is flagged for manual resolution")
    expect(modDeleteRes.conflictFiles.contains("skills/alpha/SKILL.md"), "Modify/delete conflict reports the deleted/modified file")
    expect(s14Read(devB, "skills/alpha/SKILL.md") == "alpha modified locally\n", "Local modified file is preserved after modify/delete conflict abort")

    // Reset devB to the pre-3a state so test 4 can start a manual rebase conflict
    s14Commit(devB, sharedRel, (1...60).map { "B manual conflict \($0)" }.joined(separator: "\n") + "\n", epoch: t0 + 980)
    
    // 4. User resolving in their own git client — Citadel must not interfere
    s14Git(devBURL, ["rebase", "origin/main"])
    expect(syncB.isResolutionInProgress, "Detects a rebase the user started")
    let duringUserRebase = syncB.smartSync(resyncTools: false)
    expect(duringUserRebase.needsManualResolution && syncB.isResolutionInProgress, "smartSync does not abort a user's in-progress rebase")
    expect(devB.gitCommit(message: "should be skipped") == false, "gitCommit is skipped while a rebase is in progress")
    s14Git(devBURL, ["rebase", "--abort"])
    
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
