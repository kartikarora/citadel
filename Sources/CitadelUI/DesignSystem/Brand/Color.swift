import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/**
 * Brand Color Palette for @kartikarora design system (v2.0.0).
 * AUTO-GENERATED from tokens/design-tokens.json. DO NOT EDIT DIRECTLY.
 * Run 'node scripts/generate-tokens.js' to re-generate.
 */
public enum BrandColors {
    // --- Light Palette Tokens ---
    public enum Light {
        public static let paper = Color(hex: "#ffffff") // Base canvas background
        public static let paperAlt = Color(hex: "#f6f8fa") // Elevated cards, wells, panels
        public static let paperSunken = Color(hex: "#eaeef2") // Code blocks, inputs, sunken wells
        public static let card = Color(hex: "#ffffff") // Card surface
        public static let ink = Color(hex: "#0d1117") // Primary high-contrast text and headings
        public static let inkMuted = Color(hex: "#57606a") // Secondary text, subtitles, metadata
        public static let inkFaint = Color(hex: "#8d96a0") // Disabled, borders, subtle text
        public static let rule = Color(hex: "#d0d7de") // Hairline borders and rules
        public static let ruleStrong = Color(hex: "#afb8c1") // Active borders and dividers
        public static let signal = Color(hex: "#0066cc") // Interactive accent signal (Precision Cobalt)
        public static let signalHover = Color(hex: "#0052a3") // Hover state for signal
        public static let signalWash = Color(hex: "0x1A0066CC") // Translucent signal wash
        public static let signalInk = Color(hex: "#ffffff") // High-contrast text on signal fill
        public static let focus = Color(hex: "#0066cc") // Instant accessibility focus ring
        public static let shadow = Color(hex: "#1f232814") // Card elevation shadow
        public static let shadowHover = Color(hex: "#1f23281f") // Card hover elevation shadow
        public static let glow = Color(hex: "0x1A0066CC") // Cobalt glow
        public static let success = Color(hex: "#2da44e") // Success indicators and badges
        public static let danger = Color(hex: "#cf222e") // Danger/error alerts and badges
        public static let warning = Color(hex: "#bf8700") // Warning indicators and badges
    }

    // --- Dark Palette Tokens (Option 03 Studio Dark-First) ---
    public enum Dark {
        public static let paper = Color(hex: "#000000") // Pure Black canvas (Studio)
        public static let paperAlt = Color(hex: "#0a0a0a") // Elevated surface in studio
        public static let paperSunken = Color(hex: "#050505") // Sunken code blocks in studio
        public static let card = Color(hex: "#0a0a0a") // Card surface in dark
        public static let ink = Color(hex: "#f0f4f8") // Bone white primary text
        public static let inkMuted = Color(hex: "#8c9ba5") // Slate secondary text in dark
        public static let inkFaint = Color(hex: "#8c9ba5") // Subtle / disabled in dark
        public static let rule = Color(hex: "#1f242c") // Hairline borders in dark
        public static let ruleStrong = Color(hex: "#30363d") // Active borders in dark
        public static let signal = Color(hex: "#818cf8") // Electric Indigo interactive signal in dark
        public static let signalHover = Color(hex: "#a5b4fc") // Hover state for signal in dark
        public static let signalWash = Color(hex: "0x26818CF8") // Translucent signal wash in dark
        public static let signalInk = Color(hex: "#000000") // High-contrast text on signal fill in dark
        public static let focus = Color(hex: "#818cf8") // Instant focus ring in dark
        public static let shadow = Color(hex: "#00000099") // Shadow in dark
        public static let shadowHover = Color(hex: "#818cf833") // Hover shadow in dark
        public static let glow = Color(hex: "0x1A818CF8") // Electric indigo glow in dark
        public static let success = Color(hex: "#3fb950") // Success in dark
        public static let danger = Color(hex: "#f85149") // Danger in dark
        public static let warning = Color(hex: "#d29922") // Warning in dark
    }
}

// MARK: - Color Hex Initializer & Dynamic Color Provider

public extension Color {
    init(hex: String) {
        let clean = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: "0X", with: "")

        var rgb: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&rgb)

        let a, r, g, b: Double
        if clean.count == 8 {
            a = Double((rgb & 0xFF000000) >> 24) / 255.0
            r = Double((rgb & 0x00FF0000) >> 16) / 255.0
            g = Double((rgb & 0x0000FF00) >> 8) / 255.0
            b = Double(rgb & 0x000000FF) / 255.0
        } else {
            a = 1.0
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    static func brandDynamic(light: String, dark: String) -> Color {
        #if canImport(UIKit)
        let uiColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        }
        return Color(uiColor: uiColor)
        #elseif canImport(AppKit)
        let nsColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(Color(hex: dark))
                : NSColor(Color(hex: light))
        }
        return Color(nsColor: nsColor)
        #else
        return Color(hex: dark)
        #endif
    }
}

// MARK: - Semantic Brand Colors (Adaptive Light / Dark)

public struct BrandSemanticColors: Sendable {
    public let canvas = Color.brandDynamic(light: "#ffffff", dark: "#070a10")
    public let surface = Color.brandDynamic(light: "#f4f6fa", dark: "#0d121c")
    public let surfaceSunken = Color.brandDynamic(light: "#e6ebf3", dark: "#04060a")
    public let card = Color.brandDynamic(light: "#ffffff", dark: "#121824")
    public let ink = Color.brandDynamic(light: "#0a111c", dark: "#f0f6fc")
    public let inkMuted = Color.brandDynamic(light: "#49586e", dark: "#8a9bb4")
    public let inkFaint = Color.brandDynamic(light: "#7f90a6", dark: "#4e5f7a")
    public let signal = Color.brandDynamic(light: "#0084c7", dark: "#00f0ff")
    public let signalHover = Color.brandDynamic(light: "#009ceb", dark: "#33f3ff")
    public let signalInk = Color.brandDynamic(light: "#ffffff", dark: "#000000")
    public let signalWash = Color.brandDynamic(light: "#1F0084C7", dark: "#2400F0FF")
    public let signalSecondary = Color.brandDynamic(light: "#e6b800", dark: "#ffe600")
    public let signalSecondaryInk = Color.brandDynamic(light: "#0a111c", dark: "#000000")
    public let rule = Color.brandDynamic(light: "#cdd8e6", dark: "#1a2436")
    public let ruleStrong = Color.brandDynamic(light: "#0a111c", dark: "#273752")
    public let success = Color.brandDynamic(light: "#2da44e", dark: "#3fb950")
    public let danger = Color.brandDynamic(light: "#cf222e", dark: "#f85149")
    public let warning = Color.brandDynamic(light: "#e6b800", dark: "#ffe600")
}

public extension Color {
    static let brand = BrandSemanticColors()
}
