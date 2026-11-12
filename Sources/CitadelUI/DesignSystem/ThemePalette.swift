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
        
        if effectiveDark {
            let indigoAccent = Color(red: 129/255, green: 140/255, blue: 248/255) // #818cf8
            return ThemePalette(
                isDark: true,
                background: Color(red: 0/255, green: 0/255, blue: 0/255), // Pure Studio Pitch Black #000000
                card: Color(red: 10/255, green: 10/255, blue: 10/255), // Paper Alt Dark #0a0a0a
                cardHover: Color(red: 20/255, green: 20/255, blue: 20/255),
                cardSelected: Color(red: 26/255, green: 28/255, blue: 34/255),
                border: Color(red: 31/255, green: 36/255, blue: 44/255), // Rule Dark #1f242c
                borderStrong: Color(red: 48/255, green: 54/255, blue: 61/255), // Rule Strong Dark #30363d
                textPrimary: Color(red: 240/255, green: 244/255, blue: 248/255), // Bone White Ink #f0f4f8
                textSecondary: Color(red: 140/255, green: 155/255, blue: 165/255), // Ink Muted Dark #8c9ba5
                textMuted: Color(red: 100/255, green: 116/255, blue: 139/255), // Ink Faint Dark #64748b
                accent: indigoAccent,
                accentMuted: indigoAccent.opacity(0.15),
                success: Color(red: 63/255, green: 185/255, blue: 80/255),
                danger: Color(red: 248/255, green: 81/255, blue: 73/255),
                warning: Color(red: 210/255, green: 153/255, blue: 34/255)
            )
        } else {
            let cobaltAccent = Color(red: 0/255, green: 102/255, blue: 204/255) // #0066cc
            return ThemePalette(
                isDark: false,
                background: Color(red: 255/255, green: 255/255, blue: 255/255), // Pure Paper #ffffff
                card: Color(red: 246/255, green: 248/255, blue: 250/255), // Paper Alt #f6f8fa
                cardHover: Color(red: 234/255, green: 238/255, blue: 242/255),
                cardSelected: Color(red: 225/255, green: 232/255, blue: 240/255),
                border: Color(red: 208/255, green: 215/255, blue: 222/255), // Rule #d0d7de
                borderStrong: Color(red: 175/255, green: 184/255, blue: 193/255), // Rule Strong #afb8c1
                textPrimary: Color(red: 13/255, green: 17/255, blue: 23/255), // Ink #0d1117
                textSecondary: Color(red: 87/255, green: 96/255, blue: 106/255), // Ink Muted #57606a
                textMuted: Color(red: 141/255, green: 150/255, blue: 160/255), // Ink Faint #8d96a0
                accent: cobaltAccent,
                accentMuted: cobaltAccent.opacity(0.12),
                success: Color(red: 45/255, green: 164/255, blue: 78/255),
                danger: Color(red: 207/255, green: 34/255, blue: 46/255),
                warning: Color(red: 191/255, green: 135/255, blue: 0/255)
            )
        }
    }
}
