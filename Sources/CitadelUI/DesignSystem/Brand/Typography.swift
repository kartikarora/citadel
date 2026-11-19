import SwiftUI
import CoreText

public extension Font {
    /// Registers bundled Chivo and JetBrains Mono fonts for the current process.
    static func registerBrandFonts() {
        let urls = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

/**
 * @kartikarora Brand Typography System (v2.0.0).
 * Display & Body Font: Albert Sans
 * Monospace Font: JetBrains Mono
 *
 * Implements strict type hierarchy, font weights, and display tracking
 * in compliance with @kartikarora brand guidelines.
 */

public enum BrandFontNames {
    public static let displayRegular = "Chivo-Regular"
    public static let displayMedium = "Chivo-Medium"
    public static let displaySemiBold = "Chivo-SemiBold"
    public static let displayBold = "Chivo-Bold"
    public static let displayBlack = "Chivo-Black"

    public static let monoRegular = "JetBrainsMono-Regular"
    public static let monoMedium = "JetBrainsMono-Medium"
    public static let monoBold = "JetBrainsMono-Bold"
}

public extension Font {
    // MARK: - Display Scale (-0.03em letter spacing)

    /// Signature Display Hero Headline: 48pt (Heavy Black, -0.03em tracking)
    static var brandDisplay: Font {
        Font.custom(BrandFontNames.displayBlack, size: 48)
    }

    /// Large Section Title: 32pt Bold
    static var brandTitleLarge: Font {
        Font.custom(BrandFontNames.displayBold, size: 32)
    }

    /// Section Title / Card Title: 24pt Bold
    static var brandTitle: Font {
        Font.custom(BrandFontNames.displayBold, size: 24)
    }

    /// Subsection Headline: 18pt SemiBold
    static var brandHeadline: Font {
        Font.custom(BrandFontNames.displaySemiBold, size: 18)
    }

    /// Subheadline / Lead Paragraph: 16pt Medium
    static var brandSubheadline: Font {
        Font.custom(BrandFontNames.displayMedium, size: 16)
    }

    // MARK: - Body Scale

    /// Primary Body Text: 15pt Regular
    static var brandBody: Font {
        Font.custom(BrandFontNames.displayRegular, size: 15)
    }

    /// Emphasized Body Text: 15pt SemiBold
    static var brandBodyBold: Font {
        Font.custom(BrandFontNames.displaySemiBold, size: 15)
    }

    /// Small Body / Secondary Text: 13pt Regular
    static var brandCaption: Font {
        Font.custom(BrandFontNames.displayRegular, size: 13)
    }

    // MARK: - Monospace & Technical Telemetry (JetBrains Mono)

    /// Monospace Standard: 13pt Regular (CLI pills, code snippets)
    static var brandMono: Font {
        Font.custom(BrandFontNames.monoRegular, size: 13)
    }

    /// Monospace Medium: 13pt Medium
    static var brandMonoMedium: Font {
        Font.custom(BrandFontNames.monoMedium, size: 13)
    }

    /// Monospace Bold: 13pt Bold
    static var brandMonoBold: Font {
        Font.custom(BrandFontNames.monoBold, size: 13)
    }

    /// Monospace Badge / Tag: 11pt Bold (+0.05em tracking)
    static var brandMonoBadge: Font {
        Font.custom(BrandFontNames.monoBold, size: 11)
    }

    /// Monospace Micro Caption: 10pt Regular
    static var brandMonoMicro: Font {
        Font.custom(BrandFontNames.monoRegular, size: 10)
    }
}

// MARK: - View Modifiers for Typography

public struct BrandDisplayModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .font(.brandDisplay)
            .tracking(-1.44) // -0.03em at 48pt
            .foregroundColor(Color.brand.ink)
    }
}

public struct BrandMonoBadgeModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .font(.brandMonoBadge)
            .tracking(0.55) // +0.05em tracking
            .textCase(.uppercase)
    }
}

public extension View {
    /// Applies display typography styling with brand -0.03em tracking
    func brandDisplayHeadline() -> some View {
        modifier(BrandDisplayModifier())
    }

    /// Applies uppercase monospace badge typography with +0.05em tracking
    func brandMonoBadgeStyle() -> some View {
        modifier(BrandMonoBadgeModifier())
    }
}
