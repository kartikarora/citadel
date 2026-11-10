import Foundation

/// Centralized immutable constants for Citadel
public enum CitadelConstants {
    // MARK: - Git & Commit Identity
    public enum Git {
        public static let botName = "Citadel Bot"
        public static var deviceUsername: String {
            NSUserName()
        }
        public static var botEmail: String {
            "citadel-bot-\(deviceUsername)@github.com"
        }
        public static let defaultRepoName = "citadel-sync"
        public static let gitignoreRules = ".DS_Store\n*.swp\n.env*\n.keys/\n"
    }
    
    // MARK: - Security & Keychain Services
    public enum Keychain {
        public static let authService = "sh.citadel.auth"
        public static let signingService = "sh.citadel.signing"
    }
    
    // MARK: - File System & Paths
    public enum Paths {
        public static let defaultCitadelDir = "~/.citadel"
        public static let skillsFolder = "skills"
        public static let mcpsFolder = "mcps"
        public static let keysFolder = ".keys"
        public static let signingKeyFile = "citadel_signing_key"
        public static let signingPubKeyFile = "citadel_signing_key.pub"
        public static let allowedSignersFile = "allowed_signers"
        public static let portalsFile = "portals.json"
        public static let configFile = "config.json"
        public static let syncMarkerFile = ".citadel-sync-manifest.json"
        public static let skillDocFile = "SKILL.md"
        public static let rollbackScriptFile = "rollback.sh"
    }
    
    // MARK: - OAuth Client Identifiers & Endpoints
    public enum OAuth {
        public static let defaultCallbackURL = "https://citadel.kartikarora.me/callback"
        public static let defaultGitHubClientID = ""
        // Required for creating private repository on GitHub
        public static let githubScope = "repo read:user"
        public static let githubDeviceCodeURL = "https://github.com/login/device/code"
        public static let githubOAuthTokenURL = "https://github.com/login/oauth/access_token"
        public static let githubUserAPI = "https://api.github.com/user"
        public static let githubUserReposAPI = "https://api.github.com/user/repos"
        
        public static let gitlabDefaultClientID = "1f486414757e7bb7f3721ae9dfd4a22ad27c1965a0b777a835b8004f21da9ad2"
        public static let gitlabScope = "api read_user write_repository"
        public static let gitlabDeviceAuthURL = "https://gitlab.com/oauth/authorize_device"
        public static let gitlabOAuthTokenURL = "https://gitlab.com/oauth/token"
        public static let gitlabUserAPI = "https://gitlab.com/api/v4/user"
        public static let gitlabUserProjectsAPI = "https://gitlab.com/api/v4/projects"
    }
    
    // MARK: - Web & Documentation
    public enum Web {
        public static let homepageURL = URL(string: "https://citadel.kartikarora.me/")!
        public static let docsURL = URL(string: "https://citadel.kartikarora.me/#cli")!
    }
    
    // MARK: - UserDefaults Storage Keys
    public enum StorageKeys {
        public static let themePreset = "themePreset"
        public static let customHubPath = "customHubPath"
        public static let isOnboardingComplete = "isOnboardingComplete"
        public static let sidebarWidth = "sidebarWidth"
        public static let showSkillPreview = "showSkillPreview"
    }
    
    // MARK: - UI Defaults
    public enum UIDefaults {
        public static let minWindowWidth: CGFloat = 960
        public static let minWindowHeight: CGFloat = 640
        public static let defaultWindowWidth: CGFloat = 1180
        public static let defaultWindowHeight: CGFloat = 780
        public static let defaultSidebarWidth: CGFloat = 220
        public static let minSidebarWidth: CGFloat = 180
        public static let maxSidebarWidth: CGFloat = 360
    }
}
