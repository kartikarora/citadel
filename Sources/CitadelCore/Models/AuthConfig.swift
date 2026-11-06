import Foundation

public enum GitProvider: String, CaseIterable, Sendable, Codable {
    case github = "GitHub"
    case gitlab = "GitLab"
}

public struct AuthAccount: Sendable, Codable {
    public let username: String
    public let provider: GitProvider
    public let avatarURL: String?
    
    public init(username: String, provider: GitProvider, avatarURL: String? = nil) {
        self.username = username
        self.provider = provider
        self.avatarURL = avatarURL
    }
}

public struct AppAuthConfig: Sendable, Codable {
    public var githubAppID: String?
    public var githubClientID: String?
    public var gitlabAppID: String?
    public var gitlabClientID: String?
    
    public init(
        githubAppID: String? = nil,
        githubClientID: String? = nil,
        gitlabAppID: String? = nil,
        gitlabClientID: String? = nil
    ) {
        self.githubAppID = githubAppID
        self.githubClientID = githubClientID
        self.gitlabAppID = gitlabAppID
        self.gitlabClientID = gitlabClientID
    }
}
