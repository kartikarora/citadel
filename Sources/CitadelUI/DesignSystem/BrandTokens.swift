import SwiftUI
import AppKit

// MARK: - Spacing Scale (8pt Grid)
public enum BrandSpacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat  = 8
    public static let sm: CGFloat  = 12
    public static let md: CGFloat  = 16
    public static let lg: CGFloat  = 24
    public static let xl: CGFloat  = 32
    public static let xxl: CGFloat = 48
}

// MARK: - Corner Radii
public enum BrandCornerRadius {
    public static let xs: CGFloat   = 4
    public static let sm: CGFloat   = 6
    public static let md: CGFloat   = 8
    public static let lg: CGFloat   = 12
    public static let xl: CGFloat   = 16
    public static let full: CGFloat = 9999
}

// MARK: - Shapes
public enum BrandShapes {
    public static let sm   = RoundedRectangle(cornerRadius: BrandCornerRadius.sm, style: .continuous)
    public static let md   = RoundedRectangle(cornerRadius: BrandCornerRadius.md, style: .continuous)
    public static let lg   = RoundedRectangle(cornerRadius: BrandCornerRadius.lg, style: .continuous)
    public static let full = Capsule()
}

// MARK: - Motion
public enum BrandMotion {
    public static let fastSpring = Animation.spring(response: 0.28, dampingFraction: 0.82)
    public static let smoothSpring = Animation.spring(response: 0.40, dampingFraction: 0.86)
    public static let gentleSpring = Animation.spring(response: 0.55, dampingFraction: 0.88)
}

// MARK: - Typography Extensions
public extension Font {
    private static func brandCustom(_ name: String, size: CGFloat, fallback: Font) -> Font {
        if NSFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return fallback
    }

    static var brandDisplay: Font {
        brandCustom("AlbertSans-Bold", size: 26, fallback: .system(size: 26, weight: .bold))
    }
    static var brandTitle: Font {
        brandCustom("AlbertSans-Bold", size: 19, fallback: .system(size: 19, weight: .bold))
    }
    static var brandHeadline: Font {
        brandCustom("AlbertSans-SemiBold", size: 15, fallback: .system(size: 15, weight: .semibold))
    }
    static var brandBody: Font {
        brandCustom("AlbertSans-Regular", size: 13, fallback: .system(size: 13, weight: .regular))
    }
    static var brandBodyBold: Font {
        brandCustom("AlbertSans-Bold", size: 13, fallback: .system(size: 13, weight: .bold))
    }
    static var brandCaption: Font {
        brandCustom("AlbertSans-Regular", size: 11, fallback: .system(size: 11, weight: .regular))
    }
    static var brandCaptionBold: Font {
        brandCustom("AlbertSans-SemiBold", size: 11, fallback: .system(size: 11, weight: .semibold))
    }
    static var brandMono: Font {
        brandCustom("JetBrainsMono-Regular", size: 13, fallback: .system(size: 13, weight: .regular, design: .monospaced))
    }
    static var brandMonoMedium: Font {
        brandCustom("JetBrainsMono-Medium", size: 13, fallback: .system(size: 13, weight: .medium, design: .monospaced))
    }
    static var brandMonoBold: Font {
        brandCustom("JetBrainsMono-Bold", size: 13, fallback: .system(size: 13, weight: .bold, design: .monospaced))
    }
    static var brandMonoBadge: Font {
        brandCustom("JetBrainsMono-Bold", size: 11, fallback: .system(size: 11, weight: .bold, design: .monospaced))
    }
    static var brandMonoMicro: Font {
        brandCustom("JetBrainsMono-Regular", size: 10, fallback: .system(size: 10, weight: .regular, design: .monospaced))
    }
}

// MARK: - Dynamic Color Helpers
public extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch clean.count {
        case 3:
            (r, g, b, a) = ((int >> 8) * 17, ((int >> 4) & 0xF) * 17, (int & 0xF) * 17, 255)
        case 6:
            (r, g, b, a) = (int >> 16, (int >> 8) & 0xFF, int & 0xFF, 255)
        case 8:
            (r, g, b, a) = (int >> 24, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    static func brandDynamic(light: String, dark: String) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let match = appearance.bestMatch(from: [.aqua, .darkAqua])
            return match == .darkAqua ? NSColor(Color(hex: dark)) : NSColor(Color(hex: light))
        }))
    }
}

public struct BrandSemanticColors: Sendable {
    public let paper = Color.brandDynamic(light: "#ffffff", dark: "#000000")
    public let paperAlt = Color.brandDynamic(light: "#f6f8fa", dark: "#0a0a0a")
    public let ink = Color.brandDynamic(light: "#0d1117", dark: "#f0f4f8")
    public let inkMuted = Color.brandDynamic(light: "#57606a", dark: "#8c9ba5")
    public let inkFaint = Color.brandDynamic(light: "#8d96a0", dark: "#64748b")
    public let signal = Color.brandDynamic(light: "#0066cc", dark: "#818cf8")
    public let signalWash = Color.brandDynamic(light: "#ebf5ff", dark: "#1e1b4b")
    public let rule = Color.brandDynamic(light: "#d0d7de", dark: "#1f242c")
    public let ruleStrong = Color.brandDynamic(light: "#afb8c1", dark: "#30363d")
    public let success = Color.brandDynamic(light: "#2da44e", dark: "#3fb950")
    public let danger = Color.brandDynamic(light: "#cf222e", dark: "#f85149")
    public let warning = Color.brandDynamic(light: "#bf8700", dark: "#d29922")
}

public extension Color {
    @MainActor static let brand = BrandSemanticColors()
}
