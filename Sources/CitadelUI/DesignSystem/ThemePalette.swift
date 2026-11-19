import SwiftUI
import AppKit
import CitadelCore

public enum ThemePreset: String, CaseIterable, Identifiable, Codable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    public var id: String { rawValue }
}

public struct ThemePalette {
    public let isDark: Bool
    public let background: Color
    public let card: Color
    public let cardHover: Color
    public let cardSelected: Color
    public let border: Color
    public let borderStrong: Color
    public let textPrimary: Color
    public let textSecondary: Color
    public let textMuted: Color
    public let accent: Color
    public let accentSecondary: Color
    public let accentMuted: Color
    public let success: Color
    public let danger: Color
    public let warning: Color
    
    public init(
        isDark: Bool,
        background: Color,
        card: Color,
        cardHover: Color,
        cardSelected: Color,
        border: Color,
        borderStrong: Color,
        textPrimary: Color,
        textSecondary: Color,
        textMuted: Color,
        accent: Color,
        accentSecondary: Color = Color(red: 255/255, green: 230/255, blue: 0/255),
        accentMuted: Color,
        success: Color,
        danger: Color,
        warning: Color
    ) {
        self.isDark = isDark
        self.background = background
        self.card = card
        self.cardHover = cardHover
        self.cardSelected = cardSelected
        self.border = border
        self.borderStrong = borderStrong
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.textMuted = textMuted
        self.accent = accent
        self.accentSecondary = accentSecondary
        self.accentMuted = accentMuted
        self.success = success
        self.danger = danger
        self.warning = warning
    }
    
    @MainActor
    public static func forPreset(_ preset: ThemePreset, isSystemDark: Bool? = nil) -> ThemePalette {
        let systemIsDark: Bool = {
            if let explicit = isSystemDark {
                return explicit
            }
            // Check NSApp effective appearance if window / app is active
            if let appearance = NSApp?.effectiveAppearance {
                if let match = appearance.bestMatch(from: [.darkAqua, .aqua]) {
                    return match == .darkAqua
                }
            }
            // Check global macOS user defaults AppleInterfaceStyle ("Dark" vs nil/Light)
            if let globalDict = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain),
               let style = globalDict["AppleInterfaceStyle"] as? String {
                return style.caseInsensitiveCompare("dark") == .orderedSame
            }
            return false
        }()
        
        let effectiveDark: Bool
        switch preset {
        case .light:
            effectiveDark = false
        case .dark:
            effectiveDark = true
        case .system:
            effectiveDark = systemIsDark
        }
        
        return ThemePalette(
            isDark: effectiveDark,
            background: Color.brand.canvas,
            card: Color.brand.surface,
            cardHover: Color.brand.surfaceSunken,
            cardSelected: Color.brand.signalWash,
            border: Color.brand.rule,
            borderStrong: Color.brand.inkFaint,
            textPrimary: Color.brand.ink,
            textSecondary: Color.brand.inkMuted,
            textMuted: Color.brand.inkFaint,
            accent: Color.brand.signal,
            accentSecondary: Color.brand.warning,
            accentMuted: Color.brand.signalWash,
            success: Color.brand.success,
            danger: Color.brand.danger,
            warning: Color.brand.warning
        )
    }
}
