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
        
        if effectiveDark {
            // Tokyo Neo-Brutalist Dark Palette (Deep Space Obsidian & Akihabara Cyan / Caution Yellow)
            let cyanSignal = Color(red: 0/255, green: 240/255, blue: 255/255) // #00f0ff
            let cautionYellow = Color(red: 255/255, green: 230/255, blue: 0/255) // #ffe600
            return ThemePalette(
                isDark: true,
                background: Color(red: 7/255, green: 10/255, blue: 16/255), // Deep Space Obsidian #070a10
                card: Color(red: 18/255, green: 24/255, blue: 36/255), // Card Surface #121824
                cardHover: Color(red: 26/255, green: 34/255, blue: 50/255),
                cardSelected: Color(red: 32/255, green: 42/255, blue: 62/255),
                border: Color(red: 31/255, green: 36/255, blue: 44/255), // Rule #1f242c
                borderStrong: Color(red: 51/255, green: 65/255, blue: 85/255), // Rule Strong #334155
                textPrimary: Color(red: 240/255, green: 244/255, blue: 248/255), // Bone White Ink #f0f4f8
                textSecondary: Color(red: 140/255, green: 155/255, blue: 165/255), // Ink Muted Dark #8c9ba5
                textMuted: Color(red: 100/255, green: 116/255, blue: 139/255), // Ink Faint Dark #64748b
                accent: cyanSignal,
                accentSecondary: cautionYellow,
                accentMuted: cyanSignal.opacity(0.15),
                success: Color(red: 63/255, green: 185/255, blue: 80/255),
                danger: Color(red: 248/255, green: 81/255, blue: 73/255),
                warning: cautionYellow
            )
        } else {
            // Tokyo Neo-Brutalist Light Palette (Architectural Concrete & Akihabara Cyan Light / Caution Yellow Light)
            let cyanSignalLight = Color(red: 0/255, green: 132/255, blue: 199/255) // #0084c7
            let cautionYellowLight = Color(red: 230/255, green: 184/255, blue: 0/255) // #e6b800
            return ThemePalette(
                isDark: false,
                background: Color(red: 255/255, green: 255/255, blue: 255/255), // Pure Paper #ffffff
                card: Color(red: 244/255, green: 246/255, blue: 250/255), // Card Well #f4f6fa
                cardHover: Color(red: 234/255, green: 238/255, blue: 244/255),
                cardSelected: Color(red: 225/255, green: 232/255, blue: 240/255),
                border: Color(red: 208/255, green: 215/255, blue: 222/255), // Rule #d0d7de
                borderStrong: Color(red: 31/255, green: 36/255, blue: 44/255), // Rule Strong #1f242c
                textPrimary: Color(red: 13/255, green: 17/255, blue: 23/255), // Ink #0d1117
                textSecondary: Color(red: 87/255, green: 96/255, blue: 106/255), // Ink Muted #57606a
                textMuted: Color(red: 141/255, green: 150/255, blue: 160/255), // Ink Faint #8d96a0
                accent: cyanSignalLight,
                accentSecondary: cautionYellowLight,
                accentMuted: cyanSignalLight.opacity(0.12),
                success: Color(red: 45/255, green: 164/255, blue: 78/255),
                danger: Color(red: 207/255, green: 34/255, blue: 46/255),
                warning: cautionYellowLight
            )
        }
    }
}
