import Foundation
import Security

public struct DeviceCodeResponse: Sendable {
    public let deviceCode: String
    public let userCode: String
    public let verificationURI: String
    public let expiresIn: Int
    public let interval: Int
}

public final class GitAuthProvider: @unchecked Sendable {
    public static let shared = GitAuthProvider()
    private let keychainService = CitadelConstants.Keychain.authService
    /// Public OAuth Client ID of GitHub CLI (`gh`). Sharing it would overwrite/invalidate `gh auth` grants on GitHub.
    private static let ghCLIClientID = "178c6fc778ccc68e1d6a"
    
    /// User configured GitHub App slug/name or Client ID
    public var customGitHubAppSlug: String? = ProcessInfo.processInfo.environment["CITADEL_GITHUB_APP_NAME"]
    public var customGitHubClientID: String? = ProcessInfo.processInfo.environment["CITADEL_GITHUB_CLIENT_ID"]
    public var customGitHubClientSecret: String? = ProcessInfo.processInfo.environment["CITADEL_GITHUB_CLIENT_SECRET"]
    public var customGitLabClientID: String? = ProcessInfo.processInfo.environment["CITADEL_GITLAB_CLIENT_ID"]
    
    // MARK: - App Installation URLs for Repository-Specific Access
    
    /// Generates URL for GitHub App installation where user selects exact repositories
    public static func gitHubAppInstallURL(appName: String) -> URL? {
        return URL(string: "https://github.com/apps/\(appName)/installations/new")
    }
    
    /// Generates URL for GitLab OAuth App authorization with repository-scoped permissions
    public static func gitLabAppInstallURL(clientID: String, redirectURI: String = CitadelConstants.OAuth.defaultCallbackURL) -> URL? {
        var comps = URLComponents(string: "https://gitlab.com/oauth/authorize")
        comps?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "token"),
            URLQueryItem(name: "scope", value: "read_repository write_repository")
        ]
        return comps?.url
    }
    
    public var activeGitHubClientID: String {
        if let env = customGitHubClientID, !env.isEmpty {
            return env
        }
        // Check local gitignored citadel-secrets.json
        if let localID = loadLocalSecret(key: "github_client_id") {
            return localID
        }
        return CitadelConstants.OAuth.defaultGitHubClientID
    }
    
    public var activeGitHubClientSecret: String? {
        if let env = customGitHubClientSecret, !env.isEmpty {
            return env
        }
        return loadLocalSecret(key: "github_client_secret")
    }
    
    private func loadLocalSecret(key: String) -> String? {
        var paths = [
            // Project root
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("citadel-secrets.json")
        ]
        // Also check inside App Bundle Resources (Production DMG build)
        if let bundleRes = Bundle.main.url(forResource: "citadel-secrets", withExtension: "json") {
            paths.append(bundleRes)
        }
        // Fallback to executable directory if launched from .build/debug
        let execDir = Bundle.main.bundleURL.deletingLastPathComponent()
        paths.append(execDir.appendingPathComponent("citadel-secrets.json"))
        
        for url in paths {
            if let data = try? Data(contentsOf: url),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let val = json[key] as? String, !val.isEmpty {
                return val
            }
        }
        return nil
    }
    
    public var activeGitLabClientID: String {
        return customGitLabClientID ?? CitadelConstants.OAuth.gitlabDefaultClientID
    }
    
    public func sanitizedRemoteURL(_ urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        if url.user != nil || url.password != nil {
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            comps?.user = nil
            comps?.password = nil
            return comps?.string ?? urlString
        }
        return urlString
    }
    
    public func webURL(forRemote urlString: String) -> URL? {
        var cleaned = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasSuffix(".git") {
            cleaned = String(cleaned.dropLast(4))
        }
        if cleaned.starts(with: "git@github.com:") {
            let repoPath = String(cleaned.dropFirst("git@github.com:".count))
            return URL(string: "https://github.com/\(repoPath)")
        } else if cleaned.starts(with: "git@gitlab.com:") {
            let repoPath = String(cleaned.dropFirst("git@gitlab.com:".count))
            return URL(string: "https://gitlab.com/\(repoPath)")
        } else if let url = URL(string: cleaned) {
            if url.user != nil || url.password != nil {
                var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
                comps?.user = nil
                comps?.password = nil
                return comps?.url
            }
            return url
        }
        return nil
    }
    
    // MARK: - Device Code OAuth Flow
    
    /// Requests a Device Code session from GitHub or GitLab
    public func startDeviceCodeFlow(provider: GitProvider) async throws -> DeviceCodeResponse {
        if provider == .github {
            let clientID = activeGitHubClientID.trimmingCharacters(in: .whitespacesAndNewlines)
            if clientID.isEmpty || clientID == Self.ghCLIClientID {
                throw NSError(
                    domain: "Citadel",
                    code: 400,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Citadel requires its own dedicated GitHub OAuth Client ID (separate from GitHub CLI's client ID) so signing in does not invalidate your `gh` CLI session. Set CITADEL_GITHUB_CLIENT_ID or sign in with a Personal Access Token."
                    ]
                )
            }
            let url = URL(string: CitadelConstants.OAuth.githubDeviceCodeURL)!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            let body = "client_id=\(activeGitHubClientID)&scope=\(CitadelConstants.OAuth.githubScope)"
            req.httpBody = body.data(using: .utf8)
            
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let deviceCode = json["device_code"] as? String,
                  let userCode = json["user_code"] as? String,
                  let verifURI = json["verification_uri"] as? String else {
                throw NSError(domain: "Citadel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to initiate GitHub device authorization"])
            }
            
            let expires = json["expires_in"] as? Int ?? 900
            let interval = json["interval"] as? Int ?? 5
            return DeviceCodeResponse(deviceCode: deviceCode, userCode: userCode, verificationURI: verifURI, expiresIn: expires, interval: interval)
        } else {
            // GitLab device authorization (supported on GitLab.com & modern GitLab instances)
            let url = URL(string: CitadelConstants.OAuth.gitlabDeviceAuthURL)!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            let body = "client_id=\(activeGitLabClientID)&scope=\(CitadelConstants.OAuth.gitlabScope)"
            req.httpBody = body.data(using: .utf8)
            
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let deviceCode = json["device_code"] as? String,
               let userCode = json["user_code"] as? String,
               let verifURI = (json["verification_uri_complete"] as? String) ?? (json["verification_uri"] as? String) {
                let expires = json["expires_in"] as? Int ?? 300
                let interval = json["interval"] as? Int ?? 5
                return DeviceCodeResponse(deviceCode: deviceCode, userCode: userCode, verificationURI: verifURI, expiresIn: expires, interval: interval)
            }
            
            // Fallback for custom GitLab setups
            throw NSError(domain: "Citadel", code: 500, userInfo: [NSLocalizedDescriptionKey: "GitLab OAuth device flow requires registered Client ID"])
        }
    }
    
    /// Polls the OAuth token endpoint until the user authorizes in the browser
    public func pollDeviceToken(provider: GitProvider, deviceCode: String, interval: Int) async throws -> String {
        let startTime = Date()
        let pollInterval = max(interval, 5)
        
        while Date().timeIntervalSince(startTime) < 900 {
            try await Task.sleep(nanoseconds: UInt64(pollInterval) * 1_000_000_000)
            
            if provider == .github {
                let url = URL(string: "https://github.com/login/oauth/access_token")!
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Accept")
                req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                var body = "client_id=\(activeGitHubClientID)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
                if let secret = activeGitHubClientSecret, !secret.isEmpty {
                    body += "&client_secret=\(secret)"
                }
                req.httpBody = body.data(using: .utf8)
                
                let (data, resp) = try await URLSession.shared.data(for: req)
                if let http = resp as? HTTPURLResponse, http.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let token = json["access_token"] as? String {
                        let username = await fetchUsername(for: .github, token: token)
                        _ = saveToken(token, for: .github, username: username)
                        return token
                    }
                    if let err = json["error"] as? String {
                        if err == "authorization_pending" {
                            continue
                        } else if err == "slow_down" {
                            try await Task.sleep(nanoseconds: 5_000_000_000)
                            continue
                        } else if err == "access_denied" {
                            throw NSError(domain: "Citadel", code: 403, userInfo: [NSLocalizedDescriptionKey: "Authorization declined by user on GitHub."])
                        } else if err == "expired_token" {
                            throw NSError(domain: "Citadel", code: 410, userInfo: [NSLocalizedDescriptionKey: "Verification code expired. Please generate a new code."])
                        } else {
                            let desc = (json["error_description"] as? String) ?? err
                            throw NSError(domain: "Citadel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Authentication failed: \(desc)"])
                        }
                    }
                }
            } else {
                let url = URL(string: "https://gitlab.com/oauth/token")!
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Accept")
                req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                let clientID = ProcessInfo.processInfo.environment["GITLAB_CLIENT_ID"] ?? "1f486414757e7bb7f3721ae9dfd4a22ad27c1965a0b777a835b8004f21da9ad2"
                let body = "client_id=\(clientID)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
                req.httpBody = body.data(using: .utf8)
                
                let (data, resp) = try await URLSession.shared.data(for: req)
                if let http = resp as? HTTPURLResponse, http.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let token = json["access_token"] as? String {
                        _ = saveToken(token, for: .gitlab)
                        return token
                    }
                    if let err = json["error"] as? String {
                        if err == "authorization_pending" {
                            continue
                        } else if err == "access_denied" {
                            throw NSError(domain: "Citadel", code: 403, userInfo: [NSLocalizedDescriptionKey: "Authorization declined by user on GitLab."])
                        } else if err == "expired_token" {
                            throw NSError(domain: "Citadel", code: 410, userInfo: [NSLocalizedDescriptionKey: "Verification code expired. Please generate a new code."])
                        } else {
                            let desc = (json["error_description"] as? String) ?? err
                            throw NSError(domain: "Citadel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Authentication failed: \(desc)"])
                        }
                    }
                }
            }
        }
        
        throw NSError(domain: "Citadel", code: 408, userInfo: [NSLocalizedDescriptionKey: "OAuth authorization timed out"])
    }
    
    // MARK: - Keychain Operations (Per-Account Isolated)

    private func activeAccountKey(for provider: GitProvider) -> String {
        "\(provider.rawValue).active"
    }

    private func scopedAccountKey(for provider: GitProvider, username: String) -> String {
        "\(provider.rawValue):\(username)"
    }

    public func saveToken(_ token: String, for provider: GitProvider, username: String? = nil) -> Bool {
        if let username = username, !username.isEmpty {
            let scopedSaved = CitadelUtils.saveKeychainSecret(
                service: keychainService,
                account: scopedAccountKey(for: provider, username: username),
                value: token
            )
            let activeSaved = CitadelUtils.saveKeychainSecret(
                service: keychainService,
                account: activeAccountKey(for: provider),
                value: username
            )
            return scopedSaved && activeSaved
        }
        return CitadelUtils.saveKeychainSecret(
            service: keychainService,
            account: provider.rawValue,
            value: token
        )
    }

    public func getToken(for provider: GitProvider) -> String? {
        if let activeUsername = CitadelUtils.loadKeychainSecret(service: keychainService, account: activeAccountKey(for: provider)),
           !activeUsername.isEmpty,
           let scopedToken = CitadelUtils.loadKeychainSecret(service: keychainService, account: scopedAccountKey(for: provider, username: activeUsername)) {
            return scopedToken
        }
        // Fallback to legacy single-account slot
        return CitadelUtils.loadKeychainSecret(service: keychainService, account: provider.rawValue)
    }

    public func listSavedAccounts(for provider: GitProvider) -> [String] {
        let prefix = "\(provider.rawValue):"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }
        return items.compactMap { item in
            guard let account = item[kSecAttrAccount as String] as? String,
                  account.hasPrefix(prefix) else {
                return nil
            }
            return String(account.dropFirst(prefix.count))
        }.sorted()
    }

    public func switchAccount(_ username: String, for provider: GitProvider) -> Bool {
        guard CitadelUtils.loadKeychainSecret(service: keychainService, account: scopedAccountKey(for: provider, username: username)) != nil else {
            return false
        }
        return CitadelUtils.saveKeychainSecret(service: keychainService, account: activeAccountKey(for: provider), value: username)
    }

    public func deleteToken(for provider: GitProvider) {
        if let activeUsername = CitadelUtils.loadKeychainSecret(service: keychainService, account: activeAccountKey(for: provider)),
           !activeUsername.isEmpty {
            CitadelUtils.deleteKeychainSecret(service: keychainService, account: scopedAccountKey(for: provider, username: activeUsername))
            CitadelUtils.deleteKeychainSecret(service: keychainService, account: activeAccountKey(for: provider))
        }
        CitadelUtils.deleteKeychainSecret(service: keychainService, account: provider.rawValue)
    }

    private func fetchUsername(for provider: GitProvider, token: String) async -> String? {
        if provider == .github {
            guard let url = URL(string: CitadelConstants.OAuth.githubUserAPI) else { return nil }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               (resp as? HTTPURLResponse)?.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json["login"] as? String
            }
        } else {
            guard let url = URL(string: CitadelConstants.OAuth.gitlabUserAPI) else { return nil }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               (resp as? HTTPURLResponse)?.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json["username"] as? String
            }
        }
        return nil
    }
    
    public func getAuthenticatedUser(for provider: GitProvider) async -> AuthAccount? {
        guard let token = getToken(for: provider) else { return nil }
        
        if provider == .github {
            guard let url = URL(string: "https://api.github.com/user") else { return nil }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let login = json["login"] as? String else {
                return nil
            }
            let avatar = json["avatar_url"] as? String
            return AuthAccount(username: login, provider: .github, avatarURL: avatar)
        } else {
            guard let url = URL(string: "https://gitlab.com/api/v4/user") else { return nil }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let username = json["username"] as? String else {
                return nil
            }
            let avatar = json["avatar_url"] as? String
            return AuthAccount(username: username, provider: .gitlab, avatarURL: avatar)
        }
    }
    
    // MARK: - Safe Remote Repository Checks (Read-Only)
    
    /// Checks if a repository already exists on the user's account (Read-Only)
    public func checkRepoExists(provider: GitProvider, repoName: String) async -> (exists: Bool, cloneURL: String?) {
        guard let token = getToken(for: provider),
              let user = await getAuthenticatedUser(for: provider) else {
            return (false, nil)
        }
        
        if provider == .github {
            guard let checkURL = URL(string: "https://api.github.com/repos/\(user.username)/\(repoName)") else { return (false, nil) }
            var checkReq = URLRequest(url: checkURL)
            checkReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            if let (_, resp) = try? await URLSession.shared.data(for: checkReq),
               let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                let clone = "https://github.com/\(user.username)/\(repoName).git"
                return (true, clone)
            }
        } else {
            guard let checkURL = URL(string: "https://gitlab.com/api/v4/projects/\(user.username)%2F\(repoName)") else { return (false, nil) }
            var checkReq = URLRequest(url: checkURL)
            checkReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            if let (_, resp) = try? await URLSession.shared.data(for: checkReq),
               let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                let clone = "https://gitlab.com/\(user.username)/\(repoName).git"
                return (true, clone)
            }
        }
        
        return (false, nil)
    }
    
    /// Checks if a remote repository contains the .citadel-sync-manifest.json marker file
    public func checkRemoteSyncMarker(provider: GitProvider, repoFullName: String) async -> RemoteSyncManager.SyncMarker? {
        guard let token = getToken(for: provider),
              let user = await getAuthenticatedUser(for: provider) else {
            return nil
        }
        
        let path = repoFullName.contains("/") ? repoFullName : "\(user.username)/\(repoFullName)"
        let markerFilename = CitadelConstants.Paths.syncMarkerFile
        
        if provider == .github {
            guard let url = URL(string: "https://api.github.com/repos/\(path)/contents/\(markerFilename)") else { return nil }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let base64Content = json["content"] as? String else {
                return nil
            }
            
            let sanitizedBase64 = base64Content.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
            guard let decodedData = Data(base64Encoded: sanitizedBase64) else { return nil }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try? decoder.decode(RemoteSyncManager.SyncMarker.self, from: decodedData)
        } else {
            let encodedProject = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
            guard let encodedPath = markerFilename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "https://gitlab.com/api/v4/projects/\(encodedProject)/repository/files/\(encodedPath)/raw?ref=main") else {
                return nil
            }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try? decoder.decode(RemoteSyncManager.SyncMarker.self, from: data)
        }
    }
    
    /// Discovered sync repository metadata
    public struct DiscoveredSyncRepo: Sendable {
        public let repoName: String
        public let fullName: String
        public let cloneURL: String
        public let provider: GitProvider
        public let marker: RemoteSyncManager.SyncMarker
        
        public init(repoName: String, fullName: String, cloneURL: String, provider: GitProvider, marker: RemoteSyncManager.SyncMarker) {
            self.repoName = repoName
            self.fullName = fullName
            self.cloneURL = cloneURL
            self.provider = provider
            self.marker = marker
        }
    }
    
    /// Checks the dedicated `citadel-sync` repository for the Citadel sync marker.
    public func discoverSyncRepository(provider: GitProvider, preferredRepoName: String = CitadelConstants.Git.defaultRepoName) async -> DiscoveredSyncRepo? {
        guard let user = await getAuthenticatedUser(for: provider) else {
            return nil
        }

        let repoName = CitadelConstants.Git.defaultRepoName
        if let marker = await checkRemoteSyncMarker(provider: provider, repoFullName: "\(user.username)/\(repoName)") {
            let clone = provider == .github
                ? "https://github.com/\(user.username)/\(repoName).git"
                : "https://gitlab.com/\(user.username)/\(repoName).git"
            return DiscoveredSyncRepo(
                repoName: repoName,
                fullName: "\(user.username)/\(repoName)",
                cloneURL: clone,
                provider: provider,
                marker: marker
            )
        }

        return nil
    }

    /// Ensures the dedicated private `citadel-sync` repository exists and configures it as the hub remote.
    @discardableResult
    public func ensurePrivateSyncRepo(provider: GitProvider) async throws -> String {
        let repoName = CitadelConstants.Git.defaultRepoName
        let existing = await checkRepoExists(provider: provider, repoName: repoName)
        if existing.exists, let cloneURL = existing.cloneURL {
            _ = RemoteSyncManager.shared.setRemoteURL(cloneURL)
            return cloneURL
        }
        return try await createPrivateRepo(provider: provider, repoName: repoName, isPrivate: true)
    }
    
    // MARK: - List User Repositories

    public struct RemoteRepositoryInfo: Identifiable, Sendable {
        public let id: String
        public let name: String
        public let fullName: String
        public let cloneURL: String
        public let isPrivate: Bool
        
        public init(id: String, name: String, fullName: String, cloneURL: String, isPrivate: Bool) {
            self.id = id
            self.name = name
            self.fullName = fullName
            self.cloneURL = cloneURL
            self.isPrivate = isPrivate
        }
    }

    /// Fetches repositories accessible to the user on GitHub / GitLab
    public func listUserRepositories(provider: GitProvider) async -> [RemoteRepositoryInfo] {
        guard let token = getToken(for: provider),
              let user = await getAuthenticatedUser(for: provider) else {
            return []
        }
        
        if provider == .github {
            guard let url = URL(string: "https://api.github.com/user/repos?per_page=100&sort=updated&affiliation=owner,collaborator") else { return [] }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }
            
            return jsonArray.compactMap { item in
                guard let name = item["name"] as? String,
                      let fullName = item["full_name"] as? String else { return nil }
                let isPriv = item["private"] as? Bool ?? false
                let clone = "https://\(user.username):\(token)@github.com/\(fullName).git"
                return RemoteRepositoryInfo(id: fullName, name: name, fullName: fullName, cloneURL: clone, isPrivate: isPriv)
            }
        } else {
            guard let url = URL(string: "https://gitlab.com/api/v4/projects?membership=true&order_by=updated_at&per_page=100") else { return [] }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }
            
            return jsonArray.compactMap { item in
                guard let name = item["name"] as? String,
                      let pathWithNamespace = item["path_with_namespace"] as? String else { return nil }
                let visibility = item["visibility"] as? String ?? "public"
                let isPriv = visibility == "private"
                let clone = "https://oauth2:\(token)@gitlab.com/\(pathWithNamespace).git"
                return RemoteRepositoryInfo(id: pathWithNamespace, name: name, fullName: pathWithNamespace, cloneURL: clone, isPrivate: isPriv)
            }
        }
    }

    // MARK: - Explicit Repository Creation (Requires Prior User Approval)
    
    /// Creates a repository ONLY after explicit user confirmation
    public func createPrivateRepo(provider: GitProvider, repoName: String, isPrivate: Bool = true) async throws -> String {
        guard let token = getToken(for: provider),
              let user = await getAuthenticatedUser(for: provider) else {
            throw NSError(domain: "Citadel", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated with \(provider.rawValue)"])
        }
        
        if provider == .github {
            let createURL = URL(string: "https://api.github.com/user/repos")!
            var createReq = URLRequest(url: createURL)
            createReq.httpMethod = "POST"
            createReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            createReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let payload: [String: Any] = [
                "name": repoName,
                "description": "Citadel canonical store for AI skills and configurations",
                "private": isPrivate,
                "auto_init": false
            ]
            createReq.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, resp) = try await URLSession.shared.data(for: createReq)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 201 || http.statusCode == 200 else {
                let errMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NSError(domain: "Citadel", code: 500, userInfo: [NSLocalizedDescriptionKey: "GitHub repository creation rejected: \(errMsg)"])
            }
            
            let clone = "https://github.com/\(user.username)/\(repoName).git"
            _ = RemoteSyncManager.shared.setRemoteURL(clone)
            return clone
        } else {
            let createURL = URL(string: "https://gitlab.com/api/v4/projects")!
            var createReq = URLRequest(url: createURL)
            createReq.httpMethod = "POST"
            createReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            createReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let payload: [String: Any] = [
                "name": repoName,
                "visibility": isPrivate ? "private" : "public"
            ]
            createReq.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, resp) = try await URLSession.shared.data(for: createReq)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 201 || http.statusCode == 200 else {
                let errMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NSError(domain: "Citadel", code: 500, userInfo: [NSLocalizedDescriptionKey: "GitLab repository creation rejected: \(errMsg)"])
            }
            
            let clone = "https://gitlab.com/\(user.username)/\(repoName).git"
            _ = RemoteSyncManager.shared.setRemoteURL(clone)
            return clone
        }
    }

    // MARK: - GitHub Verified Commit Identity & SSH Signing Key Upload

    /// Resolves the user's primary verified GitHub email and uploads Citadel's SSH signing key
    /// to GitHub (`/user/ssh_signing_keys`) so synced commits show as "Verified".
    public func syncGitHubSigningAndIdentity() async {
        guard let token = getToken(for: .github), !token.isEmpty else { return }

        if let identity = await fetchGitHubPrimaryVerifiedEmail(token: token) {
            HubManager.shared.updateCommitIdentity(email: identity.email, name: identity.name)
        }
        await ensureGitHubSigningKeyUploaded(token: token)
    }

    private func fetchGitHubPrimaryVerifiedEmail(token: String) async -> (email: String, name: String?)? {
        var resolvedName: String?
        var noreplyFallback: String?
        var profileEmail: String?

        if let userURL = URL(string: CitadelConstants.OAuth.githubUserAPI) {
            var userReq = URLRequest(url: userURL)
            userReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            userReq.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            if let (data, resp) = try? await URLSession.shared.data(for: userReq),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let name = json["name"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    resolvedName = name
                } else if let login = json["login"] as? String {
                    resolvedName = login
                }
                if let email = json["email"] as? String, !email.isEmpty {
                    profileEmail = email
                }
                if let id = json["id"] as? Int, let login = json["login"] as? String {
                    noreplyFallback = "\(id)+\(login)@users.noreply.github.com"
                }
            }
        }

        if let emailsURL = URL(string: CitadelConstants.OAuth.githubUserEmailsAPI) {
            var req = URLRequest(url: emailsURL)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                if let primary = list.first(where: { ($0["primary"] as? Bool == true) && ($0["verified"] as? Bool == true) }),
                   let email = primary["email"] as? String, !email.isEmpty {
                    return (email, resolvedName)
                }
                if let anyVerified = list.first(where: { $0["verified"] as? Bool == true }),
                   let email = anyVerified["email"] as? String, !email.isEmpty {
                    return (email, resolvedName)
                }
            }
        }

        if let fallback = noreplyFallback ?? profileEmail {
            return (fallback, resolvedName)
        }
        return nil
    }

    private func ensureGitHubSigningKeyUploaded(token: String) async {
        let hub = HubManager.shared
        hub.setupSigningKeyAndGitIdentity()

        guard let rawPubKey = try? String(contentsOf: hub.signingPubKeyFile, encoding: .utf8) else { return }
        let trimmedPubKey = rawPubKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let keyParts = trimmedPubKey.split(whereSeparator: { $0.isWhitespace })
        guard keyParts.count >= 2 else { return }
        let canonicalKeyPrefix = "\(keyParts[0]) \(keyParts[1])"

        guard let keysURL = URL(string: CitadelConstants.OAuth.githubSSHSigningKeysAPI) else { return }

        // Check if this signing key is already registered on GitHub
        var listReq = URLRequest(url: keysURL)
        listReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        listReq.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let (data, resp) = try? await URLSession.shared.data(for: listReq),
           let http = resp as? HTTPURLResponse, http.statusCode == 200,
           let existing = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            let alreadyExists = existing.contains { entry in
                guard let key = entry["key"] as? String else { return false }
                let parts = key.split(whereSeparator: { $0.isWhitespace })
                return parts.count >= 2 && "\(parts[0]) \(parts[1])" == canonicalKeyPrefix
            }
            if alreadyExists { return }
        }

        // Upload as a GitHub SSH Signing Key
        var createReq = URLRequest(url: keysURL)
        createReq.httpMethod = "POST"
        createReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        createReq.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        createReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let deviceLabel = Host.current().localizedName ?? CitadelConstants.Git.deviceUsername
        let payload: [String: Any] = [
            "title": "Citadel (\(deviceLabel))",
            "key": trimmedPubKey
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        createReq.httpBody = body
        _ = try? await URLSession.shared.data(for: createReq)
    }
}
