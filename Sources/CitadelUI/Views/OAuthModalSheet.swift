import SwiftUI
import CitadelCore

public struct OAuthModalSheet: View {
    public let provider: GitProvider
    public let deviceCode: DeviceCodeResponse?
    public let statusMessage: String
    public let errorMessage: String?
    public let userCodeCopied: Bool
    public let isAuthenticating: Bool
    public let palette: ThemePalette
    @Binding public var tokenInput: String
    public let onCopyCode: () -> Void
    public let onOpenBrowser: () -> Void
    public let onSignInWithToken: () -> Void
    public let onCancel: () -> Void
    
    public init(
        provider: GitProvider,
        deviceCode: DeviceCodeResponse?,
        statusMessage: String,
        errorMessage: String?,
        userCodeCopied: Bool,
        isAuthenticating: Bool,
        palette: ThemePalette,
        tokenInput: Binding<String>,
        onCopyCode: @escaping () -> Void,
        onOpenBrowser: @escaping () -> Void,
        onSignInWithToken: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.provider = provider
        self.deviceCode = deviceCode
        self.statusMessage = statusMessage
        self.errorMessage = errorMessage
        self.userCodeCopied = userCodeCopied
        self.isAuthenticating = isAuthenticating
        self.palette = palette
        self._tokenInput = tokenInput
        self.onCopyCode = onCopyCode
        self.onOpenBrowser = onOpenBrowser
        self.onSignInWithToken = onSignInWithToken
        self.onCancel = onCancel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "safari.fill")
                    .foregroundColor(palette.accent)
                    .font(.system(size: 20))
                Text("\(provider.rawValue) OAuth Authentication")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(palette.textPrimary)
            }
            
            if let devCode = deviceCode {
                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Confirm this 8-digit verification code:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(palette.textSecondary)
                    
                    HStack(spacing: 12) {
                        Text(devCode.userCode)
                            .font(.system(size: 26, weight: .black, design: .monospaced))
                            .tracking(4)
                            .foregroundColor(palette.accent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(palette.accentMuted)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.accent.opacity(0.4), lineWidth: 1))
                        
                        Button(action: onCopyCode) {
                            HStack(spacing: 4) {
                                Image(systemName: userCodeCopied ? "checkmark" : "doc.on.doc")
                                Text(userCodeCopied ? "Copied" : "Copy Code")
                            }
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(palette.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(palette.card)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.borderStrong, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text("2. Authorize in your default browser:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(palette.textSecondary)
                    
                    Button(action: onOpenBrowser) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square.fill")
                            Text("OPEN \(provider.rawValue.uppercased()) VERIFICATION PAGE")
                        }
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(palette.background)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(palette.accent)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    HStack(spacing: 8) {
                        if isAuthenticating {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else if errorMessage != nil {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color.orange)
                        }
                        Text(statusMessage)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(errorMessage != nil ? Color.orange : palette.textMuted)
                    }
                    .padding(.top, 4)
                    
                    if let err = errorMessage {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "xmark.octagon.fill")
                                .foregroundColor(Color.red)
                                .font(.system(size: 14))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Authorization Declined or Failed")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(palette.textPrimary)
                                Text(err)
                                    .font(.system(size: 11))
                                    .foregroundColor(palette.textSecondary)
                            }
                        }
                        .padding(10)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.red.opacity(0.3), lineWidth: 1))
                        .padding(.top, 4)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        if isAuthenticating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if errorMessage != nil {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color.orange)
                        }
                        Text(statusMessage)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(errorMessage != nil ? Color.orange : palette.textSecondary)
                    }
                    
                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundColor(Color.red)
                    }
                }
                .padding(.vertical, 16)
            }
            
            Divider().background(palette.border)
            
            // Fallback token option
            DisclosureGroup("Or enter Personal Access Token directly") {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("Token...", text: $tokenInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                    
                    Button("Sign In with Token") {
                        onSignInWithToken()
                    }
                    .buttonStyle(.bordered)
                    .disabled(tokenInput.isEmpty)
                }
                .padding(.top, 6)
            }
            .font(.system(size: 11))
            .foregroundColor(palette.textMuted)
            
            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 490)
        .background(palette.card)
    }
}
