import SwiftUI
import AppKit
import Combine
import CitadelCore

// MARK: - @kartikarora Brand Design System Tokens (v2.0.0)

public struct BrandSpacing {
    /// 4pt --space-2xs
    public static let xxs: CGFloat = 4.0
    /// 8pt --space-xs
    public static let xs: CGFloat = 8.0
    /// 16pt --space-sm
    public static let sm: CGFloat = 16.0
    /// 24pt --space-md
    public static let md: CGFloat = 24.0
    /// 32pt --space-lg
    public static let lg: CGFloat = 32.0
    /// 48pt --space-xl
    public static let xl: CGFloat = 48.0
    /// 64pt --space-2xl
    public static let xxl: CGFloat = 64.0
    /// 96pt --space-3xl
    public static let xxxl: CGFloat = 96.0

    public static let maxWidth: CGFloat = 1200.0
    public static let maxWidthNarrow: CGFloat = 800.0
}

public struct BrandCornerRadius {
    /// 6pt --radius-sm
    public static let sm: CGFloat = 6.0
    /// 12pt --radius-md
    public static let md: CGFloat = 12.0
    /// 16pt --radius-lg
    public static let lg: CGFloat = 16.0
    /// 9999pt --radius-pill
    public static let pill: CGFloat = 9999.0
}

public struct BrandShapes {
    public static let small = RoundedRectangle(cornerRadius: BrandCornerRadius.sm, style: .continuous)
    public static let medium = RoundedRectangle(cornerRadius: BrandCornerRadius.md, style: .continuous)
    public static let large = RoundedRectangle(cornerRadius: BrandCornerRadius.lg, style: .continuous)
    public static let pill = Capsule()
}

// MARK: - Brand Color System & Semantic Tokens (v2.0.0)

public extension Color {
    init(brandHex: String) {
        let clean = brandHex
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
        let nsColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(Color(brandHex: dark))
                : NSColor(Color(brandHex: light))
        }
        return Color(nsColor: nsColor)
    }
}

public struct BrandSemanticColors: Sendable {
    public let canvas = Color.brandDynamic(light: "#ffffff", dark: "#000000")
    public let surface = Color.brandDynamic(light: "#f6f8fa", dark: "#0a0a0a")
    public let surfaceSunken = Color.brandDynamic(light: "#eaeef2", dark: "#050505")
    public let card = Color.brandDynamic(light: "#ffffff", dark: "#0a0a0a")
    public let ink = Color.brandDynamic(light: "#0d1117", dark: "#f0f4f8")
    public let inkMuted = Color.brandDynamic(light: "#57606a", dark: "#8c9ba5")
    public let inkFaint = Color.brandDynamic(light: "#8d96a0", dark: "#8c9ba5")
    public let signal = Color.brandDynamic(light: "#0066cc", dark: "#818cf8")
    public let signalHover = Color.brandDynamic(light: "#0052a3", dark: "#a5b4fc")
    public let signalInk = Color.brandDynamic(light: "#ffffff", dark: "#000000")
    public let signalWash = Color.brandDynamic(light: "0x1A0066CC", dark: "0x26818CF8")
    public let rule = Color.brandDynamic(light: "#d0d7de", dark: "#1f242c")
    public let ruleStrong = Color.brandDynamic(light: "#afb8c1", dark: "#30363d")
    public let success = Color.brandDynamic(light: "#2da44e", dark: "#3fb950")
    public let danger = Color.brandDynamic(light: "#cf222e", dark: "#f85149")
    public let warning = Color.brandDynamic(light: "#bf8700", dark: "#d29922")
}

public extension Color {
    @MainActor static let brand = BrandSemanticColors()
}

// MARK: - Liquid Glass Surface & Material System (v2.0.0)

public struct LiquidGlassModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    public let cornerRadius: CGFloat
    public let tint: Color?
    public let blurMaterial: Material

    public init(
        cornerRadius: CGFloat = BrandCornerRadius.lg,
        tint: Color? = nil,
        material: Material = .ultraThinMaterial
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.blurMaterial = material
    }

    public func body(content: Content) -> some View {
        let isDark = colorScheme == .dark
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                ZStack {
                    shape.fill(blurMaterial)
                    if let tint = tint {
                        shape.fill(tint.opacity(isDark ? 0.12 : 0.06))
                    } else {
                        shape.fill(Color.brand.signalWash.opacity(isDark ? 0.35 : 0.15))
                    }
                    shape.strokeBorder(
                        LinearGradient(
                            colors: isDark
                                ? [Color.white.opacity(0.24), Color.white.opacity(0.06), Color.white.opacity(0.02)]
                                : [Color.white.opacity(0.85), Color.black.opacity(0.08), Color.black.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                }
            }
            .clipShape(shape)
            .shadow(
                color: Color.black.opacity(isDark ? 0.35 : 0.08),
                radius: 16,
                x: 0,
                y: 8
            )
    }
}

public struct LiquidGlassPillModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    public let tint: Color?

    public init(tint: Color? = nil) {
        self.tint = tint
    }

    public func body(content: Content) -> some View {
        let isDark = colorScheme == .dark
        let capsule = Capsule()

        content
            .background {
                ZStack {
                    capsule.fill(.ultraThinMaterial)
                    if let tint = tint {
                        capsule.fill(tint.opacity(isDark ? 0.14 : 0.08))
                    } else {
                        capsule.fill(Color.brand.signalWash.opacity(isDark ? 0.3 : 0.12))
                    }
                    capsule.strokeBorder(
                        LinearGradient(
                            colors: isDark
                                ? [Color.white.opacity(0.3), Color.white.opacity(0.08)]
                                : [Color.white.opacity(0.9), Color.black.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                }
            }
            .clipShape(capsule)
            .shadow(
                color: Color.black.opacity(isDark ? 0.28 : 0.06),
                radius: 12,
                x: 0,
                y: 4
            )
    }
}

public extension View {
    func liquidGlass(
        cornerRadius: CGFloat = BrandCornerRadius.lg,
        tint: Color? = nil,
        material: Material = .ultraThinMaterial
    ) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius, tint: tint, material: material))
    }

    func liquidGlassPill(tint: Color? = nil) -> some View {
        modifier(LiquidGlassPillModifier(tint: tint))
    }
}

public struct LiquidGlassCard<Content: View>: View {
    public let cornerRadius: CGFloat
    public let tint: Color?
    public let content: Content

    public init(
        cornerRadius: CGFloat = BrandCornerRadius.lg,
        tint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.content = content()
    }

    public var body: some View {
        content
            .padding(BrandSpacing.md)
            .liquidGlass(cornerRadius: cornerRadius, tint: tint)
    }
}

public struct LiquidGlassPill<Content: View>: View {
    public let tint: Color?
    public let content: Content

    public init(
        tint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.content = content()
    }

    public var body: some View {
        content
            .padding(.horizontal, BrandSpacing.sm)
            .padding(.vertical, BrandSpacing.xs)
            .liquidGlassPill(tint: tint)
    }
}

public enum BrandMotion {
    public static let fastSpring = Animation.spring(response: 0.22, dampingFraction: 0.8)
    public static let easeOut = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.28)
}

public extension Font {
    static func brandCustom(_ name: String, size: CGFloat, fallback: Font) -> Font {
        if NSFont(name: name, size: size) != nil {
            return Font.custom(name, size: size)
        }
        return fallback
    }

    static var brandDisplay: Font {
        brandCustom("AlbertSans-Black", size: 48, fallback: .system(size: 48, weight: .black))
    }
    static var brandTitleLarge: Font {
        brandCustom("AlbertSans-Bold", size: 32, fallback: .system(size: 32, weight: .bold))
    }
    static var brandTitle: Font {
        brandCustom("AlbertSans-Bold", size: 24, fallback: .system(size: 24, weight: .bold))
    }
    static var brandHeadline: Font {
        brandCustom("AlbertSans-SemiBold", size: 18, fallback: .system(size: 18, weight: .semibold))
    }
    static var brandSubheadline: Font {
        brandCustom("AlbertSans-Medium", size: 16, fallback: .system(size: 16, weight: .medium))
    }
    static var brandBody: Font {
        brandCustom("AlbertSans-Regular", size: 15, fallback: .system(size: 15, weight: .regular))
    }
    static var brandBodyBold: Font {
        brandCustom("AlbertSans-SemiBold", size: 15, fallback: .system(size: 15, weight: .semibold))
    }
    static var brandCaption: Font {
        brandCustom("AlbertSans-Regular", size: 13, fallback: .system(size: 13, weight: .regular))
    }
    static var brandCaptionBold: Font {
        brandCustom("AlbertSans-SemiBold", size: 13, fallback: .system(size: 13, weight: .semibold))
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

// MARK: - Theme System & User Overrides

public enum ThemePreset: String, CaseIterable, Identifiable, Codable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    public var id: String { rawValue }
}

// MARK: - Dynamic Theme Palette (Strict @kartikarora Brand System)

struct ThemePalette {
    let isDark: Bool
    let background: Color
    let card: Color
    let cardHover: Color
    let cardSelected: Color
    let border: Color
    let borderStrong: Color
    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color
    let accent: Color
    let accentMuted: Color
    let success: Color
    let danger: Color
    let warning: Color
    
    @MainActor
    static func forPreset(_ preset: ThemePreset, isSystemDark: Bool? = nil) -> ThemePalette {
        let systemIsDark: Bool = {
            if let explicit = isSystemDark {
                return explicit
            }
            if let appearance = NSApp?.effectiveAppearance {
                if let match = appearance.bestMatch(from: [.darkAqua, .aqua]) {
                    return match == .darkAqua
                }
            }
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
            // @kartikarora Dark Palette (Pure Black Studio Canvas & Electric Indigo Accent)
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
                success: Color(red: 63/255, green: 185/255, blue: 80/255), // #3fb950
                danger: Color(red: 248/255, green: 81/255, blue: 73/255), // #f85149
                warning: Color(red: 210/255, green: 153/255, blue: 34/255) // #d29922
            )
        } else {
            // @kartikarora Light Palette (Pure White Paper Canvas & Precision Cobalt Accent)
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
                success: Color(red: 45/255, green: 164/255, blue: 78/255), // #2da44e
                danger: Color(red: 207/255, green: 34/255, blue: 46/255), // #cf222e
                warning: Color(red: 191/255, green: 135/255, blue: 0/255) // #bf8700
            )
        }
    }
}

// MARK: - Native Visual Effect View

struct CitadelBrandLogoView: View {
    var size: CGFloat = 20
    var tint: Color? = nil
    
    init(size: CGFloat = 20, tint: Color? = nil) {
        self.size = size
        self.tint = tint
    }
    
    var body: some View {
        ZStack {
            Canvas { context, sz in
                let scale = sz.width / 256.0
                
                // Outer Fortress Shield
                var outerShield = Path()
                outerShield.move(to: CGPoint(x: 128 * scale, y: 24 * scale))
                outerShield.addLine(to: CGPoint(x: 214 * scale, y: 64 * scale))
                outerShield.addCurve(
                    to: CGPoint(x: 128 * scale, y: 232 * scale),
                    control1: CGPoint(x: 214 * scale, y: 146 * scale),
                    control2: CGPoint(x: 186 * scale, y: 204 * scale)
                )
                outerShield.addCurve(
                    to: CGPoint(x: 42 * scale, y: 64 * scale),
                    control1: CGPoint(x: 70 * scale, y: 204 * scale),
                    control2: CGPoint(x: 42 * scale, y: 146 * scale)
                )
                outerShield.closeSubpath()
                context.fill(outerShield, with: .color(Color(brandHex: "#0f172a")))
                
                // Secondary Inner Vault Plate
                var innerPlate = Path()
                innerPlate.move(to: CGPoint(x: 128 * scale, y: 44 * scale))
                innerPlate.addLine(to: CGPoint(x: 194 * scale, y: 76 * scale))
                innerPlate.addCurve(
                    to: CGPoint(x: 128 * scale, y: 216 * scale),
                    control1: CGPoint(x: 194 * scale, y: 144 * scale),
                    control2: CGPoint(x: 172 * scale, y: 192 * scale)
                )
                innerPlate.addCurve(
                    to: CGPoint(x: 62 * scale, y: 76 * scale),
                    control1: CGPoint(x: 84 * scale, y: 192 * scale),
                    control2: CGPoint(x: 62 * scale, y: 144 * scale)
                )
                innerPlate.closeSubpath()
                context.fill(innerPlate, with: .color(Color(brandHex: "#1e1b4b")))
                
                // Neural Synapse Network Conduits
                let accentColor = tint ?? Color(brandHex: "#818cf8")
                var outerLines = Path()
                outerLines.move(to: CGPoint(x: 128 * scale, y: 68 * scale))
                outerLines.addLine(to: CGPoint(x: 86 * scale, y: 112 * scale))
                outerLines.addLine(to: CGPoint(x: 86 * scale, y: 156 * scale))
                outerLines.addLine(to: CGPoint(x: 128 * scale, y: 188 * scale))
                outerLines.addLine(to: CGPoint(x: 170 * scale, y: 156 * scale))
                outerLines.addLine(to: CGPoint(x: 170 * scale, y: 112 * scale))
                outerLines.addLine(to: CGPoint(x: 128 * scale, y: 68 * scale))
                context.stroke(outerLines, with: .color(accentColor.opacity(0.4)), lineWidth: max(1.0, 3.0 * scale))
                
                var innerSpokes = Path()
                let center = CGPoint(x: 128 * scale, y: 134 * scale)
                for pt in [
                    CGPoint(x: 128 * scale, y: 68 * scale),
                    CGPoint(x: 86 * scale, y: 112 * scale),
                    CGPoint(x: 170 * scale, y: 112 * scale),
                    CGPoint(x: 86 * scale, y: 156 * scale),
                    CGPoint(x: 170 * scale, y: 156 * scale),
                    CGPoint(x: 128 * scale, y: 188 * scale)
                ] {
                    innerSpokes.move(to: pt)
                    innerSpokes.addLine(to: center)
                }
                context.stroke(innerSpokes, with: .color(accentColor.opacity(0.7)), lineWidth: max(1.2, 3.5 * scale))
                
                // Peripheral Skill Nodes
                for pt in [
                    CGPoint(x: 86 * scale, y: 112 * scale),
                    CGPoint(x: 170 * scale, y: 112 * scale),
                    CGPoint(x: 86 * scale, y: 156 * scale),
                    CGPoint(x: 170 * scale, y: 156 * scale)
                ] {
                    context.fill(Path(ellipseIn: CGRect(x: pt.x - 7 * scale, y: pt.y - 7 * scale, width: 14 * scale, height: 14 * scale)), with: .color(Color(brandHex: "#6366f1")))
                }
                context.fill(Path(ellipseIn: CGRect(x: 128 * scale - 8 * scale, y: 188 * scale - 8 * scale, width: 16 * scale, height: 16 * scale)), with: .color(accentColor))
                
                // Central Intelligence Nucleus
                context.fill(Path(ellipseIn: CGRect(x: center.x - 12 * scale, y: center.y - 12 * scale, width: 24 * scale, height: 24 * scale)), with: .color(accentColor))
                context.fill(Path(ellipseIn: CGRect(x: center.x - 6 * scale, y: center.y - 6 * scale, width: 12 * scale, height: 12 * scale)), with: .color(.white))
            }
        }
        .frame(width: size, height: size)
    }
}

struct NativeBlurBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Main Application Store

@MainActor
final class CitadelStore: ObservableObject {
    @Published var selectedNav: NavSection = .armory
    @Published var skills: [Skill] = []
    @Published var mcps: [MCPServer] = []
    @Published var portals: [ProjectPortal] = []
    
    // User Settings & Theme (Persisted)
    @Published var themePreset: ThemePreset {
        didSet { UserDefaults.standard.set(themePreset.rawValue, forKey: "themePreset") }
    }
    @Published var sidebarWidth: CGFloat {
        didSet { UserDefaults.standard.set(sidebarWidth, forKey: "sidebarWidth") }
    }
    @Published var showSkillPreview: Bool {
        didSet { UserDefaults.standard.set(showSkillPreview, forKey: "showSkillPreview") }
    }
    @Published var customHubPath: String {
        didSet { UserDefaults.standard.set(customHubPath, forKey: "customHubPath") }
    }
    
    // Onboarding / Setup State
    @Published var isOnboardingComplete: Bool {
        didSet { UserDefaults.standard.set(isOnboardingComplete, forKey: "isOnboardingComplete") }
    }
    @Published var onboardingStep: Int = 1
    @Published var onboardingRepoName: String = "citadel-sync"
    @Published var onboardingRepoIsPrivate: Bool = true
    @Published var hasAuthorizedSigningKey: Bool = false
    @Published var signingKeyFingerprint: String = ""
    @Published var hasGrantedScanPermission: Bool = false
    @Published var isScanningOnboarding: Bool = false
    @Published var onboardingDiscoverySegment: String = "ai_config"
    @Published var showDevResetBadge: Bool = true
    
    // Reset onboarding helper for development and testing
    func restartOnboardingForTesting() {
        self.isOnboardingComplete = false
        self.onboardingStep = 1
        self.hasAuthorizedSigningKey = false
        self.hasGrantedScanPermission = false
        UserDefaults.standard.set(false, forKey: "isOnboardingComplete")
    }
    
    @Published var systemColorScheme: ColorScheme = .light
    
    // Dynamic Computed Palette
    var palette: ThemePalette {
        let isSysDark = (systemColorScheme == .dark)
        return ThemePalette.forPreset(themePreset, isSystemDark: isSysDark)
    }
    
    // Discovery
    @Published var discoveredSkills: [DiscoveredSkill] = []
    @Published var skillGroups: [SkillGroup] = []
    @Published var discoveredMCPs: [DiscoveredMCP] = []
    @Published var discoveredWorkspaces: [DiscoveredWorkspace] = []
    @Published var isScanning: Bool = false
    @Published var discoveryTab: String = "skills"
    @Published var discoverySearchText: String = ""
    @Published var showApprovalSheet: Bool = false
    @Published var itemPendingApproval: String? = nil
    var approvalAction: (() -> Void)? = nil
    @Published var selectedDiscoverySkill: Skill? = nil
    @Published var discoverySkillContent: String = ""
    @Published var showDiscoverySkillPreview: Bool = true
    
    // Marketplace
    @Published var marketQuery: String = ""
    @Published var marketPackages: [NPMSkillPackage] = []
    @Published var isSearchingMarket: Bool = false
    @Published var installingPackage: String? = nil
    
    // Selection
    @Published var searchText: String = ""
    @Published var selectedSkill: Skill? = nil
    @Published var skillContent: String = ""
    
    // Remote Sync State
    @Published var remoteURLString: String = ""
    @Published var remoteStatus: RemoteSyncStatus = RemoteSyncStatus(remoteURL: nil, isConfigured: false, hasUncommittedChanges: false)
    @Published var githubUser: AuthAccount? = nil
    @Published var gitlabUser: AuthAccount? = nil
    @Published var availableRemoteRepos: [GitAuthProvider.RemoteRepositoryInfo] = []
    @Published var isLoadingRepos: Bool = false
    @Published var selectedRepoFullName: String = ""
    @Published var customRepoInput: String = ""
    @Published var showAuthModal: Bool = false
    @Published var showCreateRepoDialog: Bool = false
    @Published var authModalProvider: GitProvider = .github
    @Published var authInputToken: String = ""
    @Published var isAuthenticating: Bool = false
    @Published var oauthDeviceCode: DeviceCodeResponse? = nil
    @Published var oauthStatusMessage: String = ""
    @Published var oauthErrorMessage: String? = nil
    @Published var oauthUserCodeCopied: Bool = false
    @Published var isCloudSyncing: Bool = false
    @Published var cloudSyncSuccess: Bool = false
    @Published var remoteRepoExists: Bool = false
    @Published var repoCreationError: String? = nil
    @Published var isCreatingRepo: Bool = false
    @Published var rollbackNotice: String = ""
    @Published var cliInstallationNotice: String = ""
    @Published var cliErrorMessage: String? = nil
    
    // Existing Sync Repo Detection & Re-use Prompt (Identified by SyncMarker, not by name)
    @Published var existingSyncRepoFound: Bool = false
    @Published var existingSyncRepoName: String = ""
    @Published var existingSyncRepoFullName: String = ""
    @Published var existingSyncRepoCloneURL: String? = nil
    @Published var existingSyncRepoProvider: GitProvider? = nil
    @Published var existingSyncRepoMarker: RemoteSyncManager.SyncMarker? = nil
    @Published var showReuseRepoPrompt: Bool = false
    
    func runRollbackEject() {
        do {
            let res = try RollbackEngine.shared.ejectAndMaterialize()
            self.rollbackNotice = "Ejected (\(res.materializedSkills.count) copied)"
            self.refresh()
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                self.rollbackNotice = ""
            }
        } catch {
            self.rollbackNotice = "Rollback error: \(error.localizedDescription)"
        }
    }
    
    func installCLI() {
        do {
            _ = try CLIManager.shared.installCLI()
            _ = CLIManager.shared.installAutocompletion()
            self.cliInstallationNotice = "Installed to ~/.local/bin with shell autocompletions"
            self.cliErrorMessage = nil
            self.objectWillChange.send()
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                self.cliInstallationNotice = ""
            }
        } catch {
            self.cliErrorMessage = error.localizedDescription
            self.cliInstallationNotice = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.cliErrorMessage = nil
            }
        }
    }
    
    func uninstallCLI() {
        do {
            try CLIManager.shared.uninstallCLI()
            self.cliInstallationNotice = "Uninstalled from ~/.local/bin"
            self.cliErrorMessage = nil
            self.objectWillChange.send()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                self.cliInstallationNotice = ""
            }
        } catch {
            self.cliErrorMessage = error.localizedDescription
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.cliErrorMessage = nil
            }
        }
    }
    
    // Status
    @Published var isSyncing: Bool = false
    @Published var syncNotice: String = "All AI tools in sync"
    @Published var lastSyncTime: String = "Just now"
    
    init() {
        let presetRaw = UserDefaults.standard.string(forKey: "themePreset") ?? ThemePreset.system.rawValue
        self.themePreset = ThemePreset(rawValue: presetRaw) ?? .system
        
        let storedSidebar = UserDefaults.standard.double(forKey: "sidebarWidth")
        self.sidebarWidth = storedSidebar > 0 ? CGFloat(storedSidebar) : 220.0
        self.showSkillPreview = UserDefaults.standard.object(forKey: "showSkillPreview") == nil ? true : UserDefaults.standard.bool(forKey: "showSkillPreview")
        let hubPath = UserDefaults.standard.string(forKey: "customHubPath") ?? "~/.citadel"
        self.customHubPath = hubPath
        
        // Synchronously load remote sync status from git config
        let initialStatus = RemoteSyncManager.shared.getStatus()
        self.remoteStatus = initialStatus
        self.remoteURLString = initialStatus.remoteURL ?? ""
        self.remoteRepoExists = initialStatus.isConfigured
        
        // Detect if Citadel config or central directory is present
        let expanded = (hubPath as NSString).expandingTildeInPath
        let isConfigPresent = FileManager.default.fileExists(atPath: expanded)
        let previouslyCompleted = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
        self.isOnboardingComplete = previouslyCompleted && isConfigPresent
        
        if previouslyCompleted && isConfigPresent {
            refresh()
        }
    }
    
    /// Synchronously re-reads remote status from git configuration and updates published properties
    func refreshRemoteStatus() {
        let status = RemoteSyncManager.shared.getStatus()
        self.remoteStatus = status
        if let r = status.remoteURL {
            self.remoteURLString = r
            self.remoteRepoExists = true
        } else {
            self.remoteRepoExists = false
        }
    }
    
    func refresh() {
        try? HubManager.shared.initializeHub()
        self.skills = HubManager.shared.listArmorySkills()
        self.mcps = HubManager.shared.listArmoryMCPs()
        self.portals = HubManager.shared.loadPortals()
        
        // Immediately query remote status synchronously so UI updates without waiting for network
        refreshRemoteStatus()
        
        Task {
            let gh = await GitAuthProvider.shared.getAuthenticatedUser(for: .github)
            let gl = await GitAuthProvider.shared.getAuthenticatedUser(for: .gitlab)
            await MainActor.run {
                self.githubUser = gh
                self.gitlabUser = gl
                if self.remoteStatus.remoteURL == nil {
                    self.checkExistingSyncRepo()
                }
            }
        }
        
        if selectedSkill == nil, let first = skills.first {
            selectSkill(first)
        }
    }
    
    func selectSkill(_ skill: Skill) {
        self.selectedSkill = skill
        let skillFile = skill.path.appendingPathComponent("SKILL.md")
        if let content = try? String(contentsOf: skillFile, encoding: .utf8) {
            self.skillContent = content
        } else {
            self.skillContent = "// No SKILL.md found at \(skill.path.path)"
        }
    }
    
    func syncAll() {
        isSyncing = true
        syncNotice = "Synchronizing across Antigravity, Claude, and workspaces..."
        
        do {
            let res = try SyncEngine.shared.syncAll()
            HubManager.shared.gitCommit(message: "chore(sync): synchronize skills and portals")
            refresh()
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            self.lastSyncTime = formatter.string(from: Date())
            self.syncNotice = "Multiverse synchronized (\(res.createdSymlinks.count) links verified)"
        } catch {
            self.syncNotice = "Sync failed: \(error.localizedDescription)"
        }
        
        isSyncing = false
    }
    
    func scanFilesystem() {
        guard !isScanning else { return }
        isScanning = true
        
        Task {
            // Progressive background discovery so UI stays fast and interactive
            _ = await MultiverseDiscoveryEngine.shared.runFullDiscoveryAsync { [weak self] partialReport in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if !partialReport.mcps.isEmpty {
                        self.discoveredMCPs = partialReport.mcps
                    }
                    if !partialReport.skills.isEmpty {
                        self.discoveredSkills = partialReport.skills
                        self.skillGroups = SkillGroupManager.shared.groupDiscoveredSkills(partialReport.skills)
                    }
                    if !partialReport.workspaces.isEmpty {
                        self.discoveredWorkspaces = partialReport.workspaces
                    }
                }
            }
            
            // Remote sync status check in background
            let status = await Task.detached(priority: .utility) {
                RemoteSyncManager.shared.getStatus()
            }.value
            
            await MainActor.run {
                self.remoteStatus = status
                if self.remoteURLString.isEmpty, let r = status.remoteURL {
                    self.remoteURLString = r
                }
                self.isScanning = false
            }
        }
    }
    
    func ingestSkill(_ skill: DiscoveredSkill) {
        try? SkillDiscoveryEngine.shared.ingest(skill: skill)
        refresh()
        scanFilesystem()
    }
    
    func unifySkillGroup(_ group: SkillGroup) {
        do {
            _ = try SkillGroupManager.shared.unifyGroup(group)
            refresh()
            scanFilesystem()
        } catch {
            print("Unify error: \(error.localizedDescription)")
        }
    }
    
    func selectDiscoverySkillGroup(_ group: SkillGroup) {
        let bestOccurrence = group.occurrences.first(where: { !$0.isSymlink }) ?? group.occurrences.first
        guard let occ = bestOccurrence else { return }
        
        var parsedMeta = HubManager.ParsedSkillMeta()
        var loadedContent = ""
        let skillFile = occ.path.appendingPathComponent(CitadelConstants.Paths.skillDocFile)
        if let content = try? String(contentsOf: skillFile, encoding: .utf8) {
            loadedContent = content
            parsedMeta = HubManager.shared.parseSkillFrontmatter(from: content)
        } else {
            loadedContent = "// No SKILL.md found at \(occ.path.path)"
        }
        
        let skill = Skill(
            name: parsedMeta.name ?? group.name,
            path: occ.path,
            description: parsedMeta.description ?? group.description,
            isSymlink: occ.isSymlink,
            version: parsedMeta.version,
            author: parsedMeta.author,
            argumentHint: parsedMeta.argumentHint,
            icon: parsedMeta.icon
        )
        
        self.selectedDiscoverySkill = skill
        self.discoverySkillContent = loadedContent
    }
    
    func selectDiscoverySkill(_ skill: Skill) {
        self.selectedDiscoverySkill = skill
        let skillFile = skill.path.appendingPathComponent(CitadelConstants.Paths.skillDocFile)
        if let content = try? String(contentsOf: skillFile, encoding: .utf8) {
            self.discoverySkillContent = content
        } else {
            self.discoverySkillContent = "// No SKILL.md found at \(skill.path.path)"
        }
    }
    
    func searchMarketplace() {
        isSearchingMarket = true
        Task {
            let pkgs = (try? await NPMRegistry.shared.searchSkills(query: marketQuery)) ?? []
            await MainActor.run {
                self.marketPackages = pkgs
                self.isSearchingMarket = false
            }
        }
    }
    
    func installMarketplacePackage(_ pkg: NPMSkillPackage) {
        installingPackage = pkg.name
        Task {
            _ = try? await NPMRegistry.shared.install(packageSpec: pkg.name)
            await MainActor.run {
                self.installingPackage = nil
                self.refresh()
            }
        }
    }
    
    func addProjectPortal() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Connect Repository"
        
        if panel.runModal() == .OK, let url = panel.url {
            var existing = HubManager.shared.loadPortals()
            let allSkills = skills.map { $0.name }
            let allMCPs = mcps.map { $0.name }
            
            if let idx = existing.firstIndex(where: { $0.projectPath.path == url.path }) {
                existing[idx].enabledSkills = allSkills
            } else {
                existing.append(ProjectPortal(projectPath: url, enabledSkills: allSkills, enabledMCPs: allMCPs))
            }
            try? HubManager.shared.savePortals(existing)
            syncAll()
        }
    }
    
    func pushRemote() {
        isCloudSyncing = true
        _ = RemoteSyncManager.shared.push()
        refresh()
        scanFilesystem()
        isCloudSyncing = false
        cloudSyncSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.cloudSyncSuccess = false
        }
    }
    
    func pullRemote() {
        isCloudSyncing = true
        _ = try? RemoteSyncManager.shared.pull()
        refresh()
        scanFilesystem()
        isCloudSyncing = false
        cloudSyncSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.cloudSyncSuccess = false
        }
    }
    
    func fetchAvailableRepos(for provider: GitProvider) {
        isLoadingRepos = true
        Task {
            let repos = await GitAuthProvider.shared.listUserRepositories(provider: provider)
            await MainActor.run {
                self.availableRemoteRepos = repos
                self.isLoadingRepos = false
            }
        }
    }
    
    func selectRemoteRepository(_ repo: GitAuthProvider.RemoteRepositoryInfo) {
        selectedRepoFullName = repo.fullName
        _ = RemoteSyncManager.shared.setRemoteURL(repo.cloneURL)
        remoteRepoExists = true
        refresh()
        scanFilesystem()
    }
    
    func setCustomRemoteRepository(_ customURL: String) {
        guard !customURL.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        _ = RemoteSyncManager.shared.setRemoteURL(customURL.trimmingCharacters(in: .whitespaces))
        remoteRepoExists = true
        refresh()
        scanFilesystem()
    }
    
    func startOAuthFlow(for provider: GitProvider) {
        authModalProvider = provider
        isAuthenticating = true
        oauthDeviceCode = nil
        oauthErrorMessage = nil
        oauthStatusMessage = "Contacting \(provider.rawValue) for authorization code..."
        showAuthModal = true
        
        Task {
            do {
                let devCode = try await GitAuthProvider.shared.startDeviceCodeFlow(provider: provider)
                await MainActor.run {
                    self.oauthDeviceCode = devCode
                    self.oauthStatusMessage = "Code generated. Click 'Open Browser' to authenticate."
                    // Automatically copy user code to clipboard
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(devCode.userCode, forType: .string)
                    self.oauthUserCodeCopied = true
                }
                
                // Open browser directly to authorization URI
                if let url = URL(string: devCode.verificationURI) {
                    NSWorkspace.shared.open(url)
                }
                
                await MainActor.run {
                    self.oauthStatusMessage = "Waiting for authorization in your browser..."
                }
                
                // Poll for token completion
                _ = try await GitAuthProvider.shared.pollDeviceToken(provider: provider, deviceCode: devCode.deviceCode, interval: devCode.interval)
                
                // Repositories remain controlled by user - prompt to reuse if found
                let repos = await GitAuthProvider.shared.listUserRepositories(provider: provider)
                
                await MainActor.run {
                    self.availableRemoteRepos = repos
                    self.isAuthenticating = false
                    self.showAuthModal = false
                    self.oauthErrorMessage = nil
                    self.refresh()
                    self.scanFilesystem()
                    self.checkExistingSyncRepo()
                }
            } catch {
                await MainActor.run {
                    self.oauthStatusMessage = "Authentication cancelled"
                    self.oauthErrorMessage = error.localizedDescription
                    self.isAuthenticating = false
                }
            }
        }
    }
    
    func loginWithToken() {
        guard !authInputToken.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isAuthenticating = true
        let prov = authModalProvider
        let token = authInputToken.trimmingCharacters(in: .whitespaces)
        
        Task {
            _ = GitAuthProvider.shared.saveToken(token, for: prov)
            await MainActor.run {
                self.authInputToken = ""
                self.isAuthenticating = false
                self.showAuthModal = false
                self.refresh()
                self.scanFilesystem()
                self.checkExistingSyncRepo()
            }
        }
    }
    
    func createPrivateStoreWithPermission(provider: GitProvider, repoName: String = "citadel-sync", isPrivate: Bool = true) {
        self.isCreatingRepo = true
        self.repoCreationError = nil
        Task {
            do {
                _ = try await GitAuthProvider.shared.createPrivateRepo(provider: provider, repoName: repoName, isPrivate: isPrivate)
                await MainActor.run {
                    self.remoteRepoExists = true
                    self.isCreatingRepo = false
                    self.repoCreationError = nil
                    self.refresh()
                    self.scanFilesystem()
                }
            } catch {
                await MainActor.run {
                    self.isCreatingRepo = false
                    self.repoCreationError = error.localizedDescription
                }
            }
        }
    }
    
    func completeOnboarding() {
        try? HubManager.shared.initializeHub()
        self.isOnboardingComplete = true
        self.refresh()
        self.scanFilesystem()
    }
    
    func checkExistingSyncRepo() {
        let preferredRepo = onboardingRepoName.isEmpty ? "citadel-sync" : onboardingRepoName
        Task {
            if let _ = self.githubUser {
                if let discovered = await GitAuthProvider.shared.discoverSyncRepository(provider: .github, preferredRepoName: preferredRepo) {
                    await MainActor.run {
                        self.existingSyncRepoFound = true
                        self.existingSyncRepoName = discovered.repoName
                        self.existingSyncRepoFullName = discovered.fullName
                        self.existingSyncRepoCloneURL = discovered.cloneURL
                        self.existingSyncRepoProvider = .github
                        self.existingSyncRepoMarker = discovered.marker
                        self.showReuseRepoPrompt = true
                    }
                    return
                }
            }
            
            if let _ = self.gitlabUser {
                if let discovered = await GitAuthProvider.shared.discoverSyncRepository(provider: .gitlab, preferredRepoName: preferredRepo) {
                    await MainActor.run {
                        self.existingSyncRepoFound = true
                        self.existingSyncRepoName = discovered.repoName
                        self.existingSyncRepoFullName = discovered.fullName
                        self.existingSyncRepoCloneURL = discovered.cloneURL
                        self.existingSyncRepoProvider = .gitlab
                        self.existingSyncRepoMarker = discovered.marker
                        self.showReuseRepoPrompt = true
                    }
                    return
                }
            }
            
            await MainActor.run {
                self.existingSyncRepoFound = false
                self.existingSyncRepoName = ""
                self.existingSyncRepoFullName = ""
                self.existingSyncRepoCloneURL = nil
                self.existingSyncRepoProvider = nil
                self.existingSyncRepoMarker = nil
                self.showReuseRepoPrompt = false
            }
        }
    }
    
    func reuseExistingSyncRepo() {
        guard let cloneURL = existingSyncRepoCloneURL else { return }
        _ = RemoteSyncManager.shared.setRemoteURL(cloneURL)
        self.remoteRepoExists = true
        self.showReuseRepoPrompt = false
        self.refresh()
        self.scanFilesystem()
    }
    
    func declineReuseSyncRepo() {
        self.showReuseRepoPrompt = false
    }
    
    func logout(provider: GitProvider) {
        GitAuthProvider.shared.deleteToken(for: provider)
        refresh()
    }
}

enum NavSection: String, CaseIterable, Identifiable {
    case armory = "The Armory"
    case discovery = "Discovery"
    case marketplace = "Marketplace"
    case workspaces = "Workspaces"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .armory: return "shield.checkered"
        case .discovery: return "sparkle.magnifyingglass"
        case .marketplace: return "shippingbox.fill"
        case .workspaces: return "point.3.connected.trianglepath.dotted"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Onboarding Startup Screen (Step-by-Step)

struct OnboardingStartupView: View {
    @ObservedObject var store: CitadelStore
    
    private var continueButtonText: String {
        switch store.onboardingStep {
        case 2:
            return (store.githubUser == nil && store.gitlabUser == nil) ? "SKIP CLOUD SYNC" : "CONTINUE"
        case 3:
            return store.hasAuthorizedSigningKey ? "CONTINUE" : "GENERATE KEY & CONTINUE"
        default:
            return "CONTINUE"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: BrandSpacing.xs) {
                    CitadelBrandLogoView(size: 20, tint: store.palette.accent)
                    
                    Text("CITADEL")
                        .font(.brandMonoBold)
                        .tracking(1.4)
                        .foregroundColor(store.palette.textPrimary)
                    
                    Text("/")
                        .font(.brandMono)
                        .foregroundColor(store.palette.textMuted)
                    
                    Text("INITIAL SETUP")
                        .font(.brandMonoBadge)
                        .tracking(0.55)
                        .foregroundColor(store.palette.textSecondary)
                    
            // Dev test badge to jump directly between steps removed as requested
                }
                
                Spacer()
                
                // Step Indicator Pills
                HStack(spacing: BrandSpacing.xs) {
                    StepPill(number: 1, title: "Directory", current: store.onboardingStep, accent: store.palette.accent)
                    StepPill(number: 2, title: "Cloud Sync", current: store.onboardingStep, accent: store.palette.accent)
                    StepPill(number: 3, title: "Security Key", current: store.onboardingStep, accent: store.palette.accent)
                    StepPill(number: 4, title: "Appearance", current: store.onboardingStep, accent: store.palette.accent)
                    StepPill(number: 5, title: "Discovery", current: store.onboardingStep, accent: store.palette.accent)
                }
            }
            .padding(.horizontal, BrandSpacing.xl)
            .padding(.top, BrandSpacing.lg)
            .padding(.bottom, BrandSpacing.md)
            
            Divider().background(store.palette.border.opacity(0.3))
            
            Spacer()
            
            // Dynamic Chamber based on step
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: BrandSpacing.lg) {
                    switch store.onboardingStep {
                    case 1:
                        Step1DirectoryChamber(store: store)
                    case 2:
                        Step2CloudSyncChamber(store: store)
                    case 3:
                        Step3SigningKeyChamber(store: store)
                    case 4:
                        Step4ThemeChamber(store: store)
                    case 5:
                        Step5DiscoveryChamber(store: store)
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: 820, alignment: .leading)
                .padding(.horizontal, BrandSpacing.xl)
                .padding(.vertical, BrandSpacing.md)
            }
            
            Spacer()
            
            Divider().background(store.palette.border.opacity(0.3))
            
            // Bottom Action Navigation Bar
            HStack {
                if store.onboardingStep > 1 {
                    Button(action: {
                        withAnimation(BrandMotion.fastSpring) {
                            store.onboardingStep -= 1
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("BACK")
                        }
                        .font(.brandMonoBadge)
                        .foregroundColor(store.palette.textSecondary)
                        .padding(.horizontal, BrandSpacing.md)
                        .padding(.vertical, BrandSpacing.xs)
                        .liquidGlassPill()
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 80)
                }
                
                Spacer()
                
                if store.onboardingStep < 5 {
                    Button(action: {
                        withAnimation(BrandMotion.fastSpring) {
                            store.onboardingStep += 1
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text(continueButtonText)
                            Image(systemName: "chevron.right")
                        }
                        .font(.brandMonoBadge)
                        .foregroundColor(store.palette.textPrimary)
                        .padding(.horizontal, BrandSpacing.lg)
                        .padding(.vertical, BrandSpacing.xs + 2)
                        .liquidGlassPill(tint: store.palette.accent)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: {
                        withAnimation(BrandMotion.fastSpring) {
                            store.completeOnboarding()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("ENTER CITADEL")
                        }
                        .font(.brandMonoBold)
                        .foregroundColor(store.palette.textPrimary)
                        .padding(.horizontal, BrandSpacing.xl)
                        .padding(.vertical, BrandSpacing.sm)
                        .liquidGlassPill(tint: store.palette.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, BrandSpacing.xl)
            .padding(.vertical, BrandSpacing.md)
            .background(store.palette.background.opacity(0.4))
        }
    }
}

// MARK: - Step Indicator Component

private struct StepPill: View {
    let number: Int
    let title: String
    let current: Int
    let accent: Color
    
    var isActive: Bool { current == number }
    var isDone: Bool { current > number }
    
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isDone ? accent : (isActive ? accent.opacity(0.2) : Color.gray.opacity(0.2)))
                    .frame(width: 18, height: 18)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.brandMonoMicro)
                        .foregroundColor(isActive ? accent : Color.gray)
                }
            }
            Text(title)
                .font(.brandMonoBadge)
                .foregroundColor(isActive ? accent : Color.gray)
        }
        .padding(.horizontal, BrandSpacing.sm)
        .padding(.vertical, BrandSpacing.xxs + 1)
        .liquidGlassPill(tint: isActive ? accent : nil)
    }
}

// MARK: - Step 1: Directory Selection & Architecture Explainer

private struct Step1DirectoryChamber: View {
    @ObservedObject var store: CitadelStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.md) {
            VStack(alignment: .leading, spacing: BrandSpacing.xxs) {
                Text("THE ARMORY & ARCHITECTURE")
                    .font(.brandMonoBadge)
                    .tracking(1.0)
                    .foregroundColor(store.palette.accent)
                
                Text("Welcome to Citadel")
                    .font(.brandTitle)
                    .foregroundColor(store.palette.textPrimary)
                
                Text("Citadel is the central source of truth for all your AI skills and tools. Instead of duplicating configurations across half a dozen editors, Citadel stores your skills once in The Armory and injects zero-overhead symlinks into every AI assistant.")
                    .font(.brandBody)
                    .foregroundColor(store.palette.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Explainer Cards: What's the Armory & How It Works
            VStack(spacing: BrandSpacing.sm) {
                HStack(alignment: .top, spacing: BrandSpacing.sm) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 20))
                        .foregroundColor(store.palette.accent)
                        .padding(.top, 2)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("WHAT IS THE ARMORY?")
                            .font(.brandMonoBold)
                            .foregroundColor(store.palette.textPrimary)
                        Text("The Armory is your canonical skill inventory at ~/.citadel/skills. When you create, edit, or install a skill, it lives here. Every edit made in any connected editor updates this central copy in real time.")
                            .font(.brandCaption)
                            .foregroundColor(store.palette.textSecondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(BrandSpacing.sm)
                .liquidGlass(cornerRadius: BrandCornerRadius.md)
                
                HStack(alignment: .top, spacing: BrandSpacing.sm) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 20))
                        .foregroundColor(store.palette.accent)
                        .padding(.top, 2)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("HOW CITADEL WORKS (ZERO-OVERHEAD SYMLINKS)")
                            .font(.brandMonoBold)
                            .foregroundColor(store.palette.textPrimary)
                        Text("Citadel maps filesystem symlinks into Antigravity, Claude, Cursor, Android Studio, Copilot, and Junie. Zero duplicate files, zero sync delays. If you ever leave, Citadel includes an emergency Rollback Eject button to materialize symlinks back into independent copies.")
                            .font(.brandCaption)
                            .foregroundColor(store.palette.textSecondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(BrandSpacing.sm)
                .liquidGlass(cornerRadius: BrandCornerRadius.md)
            }
            
            // Directory Input & Picker
            VStack(alignment: .leading, spacing: BrandSpacing.xs) {
                Text("THE ARMORY CANONICAL STORE PATH")
                    .font(.brandMonoBadge)
                    .foregroundColor(store.palette.textMuted)
                
                HStack(spacing: BrandSpacing.xs) {
                    TextField("~/.citadel", text: $store.customHubPath)
                        .textFieldStyle(.plain)
                        .font(.brandMono)
                        .foregroundColor(store.palette.textPrimary)
                        .padding(BrandSpacing.sm)
                        .liquidGlass(cornerRadius: BrandCornerRadius.sm)
                    
                    Button(action: selectCustomDirectory) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.plus")
                            Text("CHOOSE...")
                        }
                        .font(.brandMonoBadge)
                        .foregroundColor(store.palette.textPrimary)
                        .padding(.horizontal, BrandSpacing.md)
                        .padding(.vertical, BrandSpacing.sm)
                        .liquidGlassPill()
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        store.customHubPath = "~/.citadel"
                    }) {
                        Text("DEFAULT")
                            .font(.brandMonoBadge)
                            .foregroundColor(store.palette.textPrimary)
                            .padding(.horizontal, BrandSpacing.md)
                            .padding(.vertical, BrandSpacing.sm)
                            .liquidGlassPill()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(BrandSpacing.md)
            .liquidGlass(cornerRadius: BrandCornerRadius.md)
            
            // Git Tracking Notice Box (Explicit requirement)
            HStack(alignment: .top, spacing: BrandSpacing.sm) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 20))
                    .foregroundColor(store.palette.accent)
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: BrandSpacing.xxs) {
                    Text("AUTOMATIC GIT REPOSITORY TRACKING")
                        .font(.brandMonoBold)
                        .foregroundColor(store.palette.textPrimary)
                    
                    Text("This directory will be initialized as a Git repository. Every synchronization, skill creation, and workspace portal change will be committed locally with clear version history, ensuring your AI instructions are always recoverable.")
                        .font(.brandCaption)
                        .foregroundColor(store.palette.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(BrandSpacing.md)
            .liquidGlass(cornerRadius: BrandCornerRadius.md, tint: store.palette.accent)
        }
    }
    
    private func selectCustomDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Citadel Directory"
        
        if panel.runModal() == .OK, let url = panel.url {
            store.customHubPath = url.path
        }
    }
}

// MARK: - Step 2: Cloud Sync (GitHub / GitLab OAuth & Repo Selection)

private struct Step2CloudSyncChamber: View {
    @ObservedObject var store: CitadelStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.md) {
            VStack(alignment: .leading, spacing: BrandSpacing.xxs) {
                Text("CLOUD SYNC & BACKUP")
                    .font(.brandMonoBadge)
                    .tracking(1.0)
                    .foregroundColor(store.palette.accent)
                
                Text("Connect Your Git Account")
                    .font(.brandTitle)
                    .foregroundColor(store.palette.textPrimary)
                
                Text("Sync your skills across multiple machines with a private Git repository. You can sign in with GitHub or GitLab via secure OAuth.")
                    .font(.brandBody)
                    .foregroundColor(store.palette.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Zero-Knowledge & Accidental Deletion Protection Callout
            HStack(alignment: .top, spacing: BrandSpacing.sm) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 20))
                    .foregroundColor(store.palette.accent)
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("WHY CLOUD SYNC IS ESSENTIAL (ACCIDENTAL DELETION SAFEGUARD)")
                        .font(.brandMonoBold)
                        .foregroundColor(store.palette.textPrimary)
                    
                    Text("Citadel injects symlinks into your AI tools (.gemini, .claude, .android-studio, .copilot, .junie). If ~/.citadel is ever accidentally deleted, those symlinks break.\n\nWith Cloud Sync, your skills are preserved in your private repository. Citadel stores nothing on third-party servers and sees none of your data — sync communicates directly between your machine and your own personal GitHub/GitLab repository.")
                        .font(.brandCaption)
                        .foregroundColor(store.palette.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(BrandSpacing.md)
            .liquidGlass(cornerRadius: BrandCornerRadius.md, tint: store.palette.accent)
            
            // Provider OAuth Buttons
            HStack(spacing: BrandSpacing.md) {
                // GitHub Card (conditionally visible via FeatureFlags)
                if FeatureFlags.shared.githubIntegrationEnabled {
                    HStack(spacing: BrandSpacing.sm) {
                        Image(systemName: "globe")
                            .font(.system(size: 22))
                            .foregroundColor(store.palette.textPrimary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("GitHub")
                                .font(.brandBodyBold)
                                .foregroundColor(store.palette.textPrimary)
                            if let user = store.githubUser {
                                Text("@\(user.username)")
                                    .font(.brandMono)
                                    .foregroundColor(store.palette.accent)
                            } else {
                                Text("Not connected")
                                    .font(.brandCaption)
                                    .foregroundColor(store.palette.textMuted)
                            }
                        }
                        
                        Spacer()
                        
                        if store.githubUser != nil {
                            Button("Disconnect") { store.logout(provider: .github) }
                                .font(.brandMonoMicro)
                                .foregroundColor(Color.red.opacity(0.8))
                                .buttonStyle(.plain)
                        } else {
                            Button(action: { store.startOAuthFlow(for: .github) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "key.fill")
                                    Text("OAUTH SIGN IN")
                                }
                                .font(.brandMonoBadge)
                                .foregroundColor(store.palette.textPrimary)
                                .padding(.horizontal, BrandSpacing.sm)
                                .padding(.vertical, BrandSpacing.xs)
                                .liquidGlassPill(tint: store.palette.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(BrandSpacing.md)
                    .liquidGlass(cornerRadius: BrandCornerRadius.md)
                }
                
                // GitLab Card (conditionally visible via FeatureFlags)
                if FeatureFlags.shared.gitlabIntegrationEnabled {
                    HStack(spacing: BrandSpacing.sm) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 22))
                            .foregroundColor(Color.orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("GitLab")
                                .font(.brandBodyBold)
                                .foregroundColor(store.palette.textPrimary)
                            if let user = store.gitlabUser {
                                Text("@\(user.username)")
                                    .font(.brandMono)
                                    .foregroundColor(Color.orange)
                            } else {
                                Text("Not connected")
                                    .font(.brandCaption)
                                    .foregroundColor(store.palette.textMuted)
                            }
                        }
                        
                        Spacer()
                        
                        if store.gitlabUser != nil {
                            Button("Disconnect") { store.logout(provider: .gitlab) }
                                .font(.brandMonoMicro)
                                .foregroundColor(Color.red.opacity(0.8))
                                .buttonStyle(.plain)
                        } else {
                            Button(action: { store.startOAuthFlow(for: .gitlab) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "key.fill")
                                    Text("OAUTH SIGN IN")
                                }
                                .font(.brandMonoBadge)
                                .foregroundColor(Color.orange)
                                .padding(.horizontal, BrandSpacing.sm)
                                .padding(.vertical, BrandSpacing.xs)
                                .liquidGlassPill(tint: Color.orange)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(BrandSpacing.md)
                    .liquidGlass(cornerRadius: BrandCornerRadius.md)
                }
            }
            
            // Existing Repository Re-use Banner
            // Existing Repository Re-use Banner (Identified uniquely via SyncMarker)
            if store.showReuseRepoPrompt && store.remoteStatus.remoteURL == nil {
                let detectedName = store.existingSyncRepoFullName.isEmpty ? store.existingSyncRepoName : store.existingSyncRepoFullName
                let displayName = detectedName.isEmpty ? store.onboardingRepoName : detectedName
                
                VStack(alignment: .leading, spacing: BrandSpacing.sm) {
                    HStack(alignment: .top, spacing: BrandSpacing.sm) {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(store.palette.accent)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("CITADEL SYNC STORE DETECTED: \(displayName)")
                                    .font(.brandMonoBold)
                                    .foregroundColor(store.palette.textPrimary)
                                
                                if store.existingSyncRepoMarker != nil {
                                    Text("SYNC MARKER VERIFIED")
                                        .font(.brandMonoMicro)
                                        .foregroundColor(store.palette.accent)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .liquidGlassPill(tint: store.palette.accent)
                                }
                            }
                            
                            if let marker = store.existingSyncRepoMarker {
                                Text("This repository contains a valid Citadel sync marker (`\(CitadelConstants.Paths.syncMarkerFile)`) with store ID `\(marker.syncStoreId.prefix(8))...`, synced by \(marker.deviceUsername) (\(marker.botEmail)). Would you like to re-use this repository as your central store?")
                                    .font(.brandCaption)
                                    .foregroundColor(store.palette.textSecondary)
                                    .lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text("We detected an existing '\(displayName)' repository on your connected account. Would you like to re-use it as your central sync store?")
                                    .font(.brandCaption)
                                    .foregroundColor(store.palette.textSecondary)
                                    .lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    
                    HStack(spacing: BrandSpacing.sm) {
                        Button(action: {
                            withAnimation(BrandMotion.fastSpring) {
                                store.reuseExistingSyncRepo()
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("RE-USE THIS REPOSITORY")
                            }
                            .font(.brandMonoBadge)
                            .foregroundColor(store.palette.textPrimary)
                            .padding(.horizontal, BrandSpacing.md)
                            .padding(.vertical, BrandSpacing.xs + 2)
                            .liquidGlassPill(tint: store.palette.accent)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            withAnimation(BrandMotion.fastSpring) {
                                store.declineReuseSyncRepo()
                            }
                        }) {
                            Text("CREATE NEW / SPECIFY OTHER")
                                .font(.brandMonoBadge)
                                .foregroundColor(store.palette.textMuted)
                                .padding(.horizontal, BrandSpacing.md)
                                .padding(.vertical, BrandSpacing.xs + 2)
                                .liquidGlassPill()
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(BrandSpacing.md)
                .liquidGlass(cornerRadius: BrandCornerRadius.md, tint: store.palette.accent)
            }
            
            // Repository Configuration
            VStack(alignment: .leading, spacing: BrandSpacing.sm) {
                Text("REMOTE REPOSITORY")
                    .font(.brandMonoBadge)
                    .foregroundColor(store.palette.textMuted)
                
                if let activeRemote = store.remoteStatus.remoteURL {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(store.palette.accent)
                        Text(GitAuthProvider.shared.sanitizedRemoteURL(activeRemote))
                            .font(.brandMono)
                            .foregroundColor(store.palette.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Button("Reset") {
                            _ = RemoteSyncManager.shared.setRemoteURL("")
                            store.remoteRepoExists = false
                            store.refresh()
                            store.scanFilesystem()
                        }
                        .font(.brandMonoMicro)
                        .foregroundColor(store.palette.textMuted)
                        .buttonStyle(.plain)
                    }
                    .padding(BrandSpacing.sm)
                    .liquidGlass(cornerRadius: BrandCornerRadius.sm, tint: store.palette.accent)
                } else {
                    // Create default repo box
                    VStack(alignment: .leading, spacing: BrandSpacing.xs) {
                        HStack(spacing: BrandSpacing.xs) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Repository Name")
                                    .font(.brandMonoMicro)
                                    .foregroundColor(store.palette.textMuted)
                                TextField("citadel-sync", text: $store.onboardingRepoName)
                                    .textFieldStyle(.plain)
                                    .font(.brandMono)
                                    .foregroundColor(store.palette.textPrimary)
                                    .padding(8)
                                    .liquidGlass(cornerRadius: BrandCornerRadius.sm)
                            }
                            
                            Toggle("Private", isOn: $store.onboardingRepoIsPrivate)
                                .font(.brandCaption)
                                .toggleStyle(.checkbox)
                                .padding(.horizontal, 4)
                            
                            if let provider = store.githubUser != nil ? GitProvider.github : (store.gitlabUser != nil ? GitProvider.gitlab : nil) {
                                Button(store.isCreatingRepo ? "CREATING..." : "CREATE ON \(provider.rawValue.uppercased())") {
                                    store.createPrivateStoreWithPermission(
                                        provider: provider,
                                        repoName: store.onboardingRepoName.isEmpty ? "citadel-sync" : store.onboardingRepoName,
                                        isPrivate: store.onboardingRepoIsPrivate
                                    )
                                }
                                .font(.brandMonoBadge)
                                .foregroundColor(store.palette.textPrimary)
                                .padding(.horizontal, BrandSpacing.md)
                                .padding(.vertical, BrandSpacing.sm)
                                .liquidGlassPill(tint: store.palette.accent)
                                .buttonStyle(.plain)
                                .disabled(store.isCreatingRepo)
                            }
                        }
                        
                        if let err = store.repoCreationError {
                            Text("Creation failed: \(err)")
                                .font(.brandMonoMicro)
                                .foregroundColor(Color.red)
                                .padding(.top, 2)
                        }
                        
                        Text("Default repository is private 'citadel-sync'. You may customize the name or enter an existing repo URL below.")
                            .font(.brandMonoMicro)
                            .foregroundColor(store.palette.textMuted)
                    }
                    
                    // Or custom repo URL input
                    HStack(spacing: BrandSpacing.xs) {
                        TextField("Or paste git repository URL (e.g. git@github.com:you/my-repo.git)...", text: $store.customRepoInput)
                            .textFieldStyle(.plain)
                            .font(.brandMono)
                            .padding(BrandSpacing.xs)
                            .liquidGlass(cornerRadius: BrandCornerRadius.sm)
                        
                        Button("USE REPO") {
                            store.setCustomRemoteRepository(store.customRepoInput)
                            store.customRepoInput = ""
                        }
                        .font(.brandMonoBadge)
                        .foregroundColor(store.palette.textPrimary)
                        .padding(.horizontal, BrandSpacing.sm)
                        .padding(.vertical, BrandSpacing.xs)
                        .liquidGlassPill()
                        .buttonStyle(.plain)
                        .disabled(store.customRepoInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .padding(BrandSpacing.md)
            .liquidGlass(cornerRadius: BrandCornerRadius.md)
        }
    }
}

// MARK: - Step 3: Key Generation & Keychain Permission

private struct Step3SigningKeyChamber: View {
    @ObservedObject var store: CitadelStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.md) {
            HStack(alignment: .top, spacing: BrandSpacing.sm) {
                Image(systemName: "key.fill")
                    .font(.system(size: 20))
                    .foregroundColor(store.palette.accent)
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: BrandSpacing.xxs) {
                    Text("CRYPTOGRAPHIC COMMIT SIGNING")
                        .font(.brandMonoBold)
                        .foregroundColor(store.palette.textPrimary)
                    
                    Text("Citadel Bot signs all repository commits with an Ed25519 cryptographic key. The private key is securely generated and kept in macOS Keychain under service 'sh.citadel.signing' (account: 'citadel_signing_key'). Commits are author-tagged as 'Citadel Bot <\(CitadelConstants.Git.botEmail)>'.")
                        .font(.brandCaption)
                        .foregroundColor(store.palette.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(BrandSpacing.md)
            .liquidGlass(cornerRadius: BrandCornerRadius.md, tint: store.palette.accent)
            
            // Key details card
            VStack(alignment: .leading, spacing: BrandSpacing.xs) {
                Text("KEYCHAIN METADATA")
                    .font(.brandMonoBadge)
                    .foregroundColor(store.palette.textMuted)
                
                VStack(spacing: 6) {
                    HStack {
                        Text("Keychain Service:")
                            .font(.brandMonoMicro)
                            .foregroundColor(store.palette.textMuted)
                        Spacer()
                        Text("sh.citadel.signing")
                            .font(.brandMonoMicro)
                            .foregroundColor(store.palette.textPrimary)
                    }
                    HStack {
                        Text("Account Name:")
                            .font(.brandMonoMicro)
                            .foregroundColor(store.palette.textMuted)
                        Spacer()
                        Text("citadel_signing_key")
                            .font(.brandMonoMicro)
                            .foregroundColor(store.palette.textPrimary)
                    }
                    HStack {
                        Text("Algorithm:")
                            .font(.brandMonoMicro)
                            .foregroundColor(store.palette.textMuted)
                        Spacer()
                        Text("Ed25519 (OpenSSH)")
                            .font(.brandMonoMicro)
                            .foregroundColor(store.palette.textPrimary)
                    }
                    if !store.signingKeyFingerprint.isEmpty {
                        HStack {
                            Text("Public Fingerprint:")
                                .font(.brandMonoMicro)
                                .foregroundColor(store.palette.textMuted)
                            Spacer()
                            Text(store.signingKeyFingerprint)
                                .font(.brandMonoMicro)
                                .foregroundColor(store.palette.accent)
                        }
                    }
                }
                .padding(BrandSpacing.sm)
                .liquidGlass(cornerRadius: BrandCornerRadius.sm)
            }
            .padding(BrandSpacing.md)
            .liquidGlass(cornerRadius: BrandCornerRadius.md)
            
            HStack {
                if !store.hasAuthorizedSigningKey {
                    Button("AUTHORIZE & GENERATE SIGNING KEY") {
                        generateKey()
                    }
                    .font(.brandMonoBadge)
                    .foregroundColor(store.palette.textPrimary)
                    .padding(.horizontal, BrandSpacing.md)
                    .padding(.vertical, BrandSpacing.sm)
                    .liquidGlassPill(tint: store.palette.accent)
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(store.palette.success)
                        Text("KEY GENERATED & STORED IN KEYCHAIN")
                            .font(.brandMonoBadge)
                            .foregroundColor(store.palette.success)
                    }
                }
            }
            .padding(.top, BrandSpacing.xs)
        }
    }
    
    private func generateKey() {
        let expanded = CitadelUtils.expandTildePath(store.customHubPath)
        let hubURL = URL(fileURLWithPath: expanded)
        let hub = HubManager(customHubURL: hubURL)
        hub.setupSigningKeyAndGitIdentity()
        store.hasAuthorizedSigningKey = true
        if let pub = try? String(contentsOf: hub.signingPubKeyFile, encoding: .utf8) {
            let parts = pub.split(separator: " ")
            if parts.count >= 2 {
                store.signingKeyFingerprint = String(parts[1].prefix(16)) + "..."
            }
        }
    }
}

// MARK: - Step 4: Theme Selector (Light, Dark, System)

private struct Step4ThemeChamber: View {
    @ObservedObject var store: CitadelStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.md) {
            VStack(alignment: .leading, spacing: BrandSpacing.xxs) {
                Text("APPEARANCE")
                    .font(.brandMonoBadge)
                    .tracking(1.0)
                    .foregroundColor(store.palette.accent)
                
                Text("Select Your Appearance")
                    .font(.brandTitle)
                    .foregroundColor(store.palette.textPrimary)
            }
            
            // 3 Clean Cards for Light, Dark, System
            HStack(spacing: BrandSpacing.md) {
                ThemeOptionCard(
                    preset: .system,
                    title: "System (Default)",
                    subtitle: nil,
                    icon: "circle.lefthalf.filled",
                    isSelected: store.themePreset == .system,
                    store: store
                )
                
                ThemeOptionCard(
                    preset: .light,
                    title: "Light",
                    subtitle: nil,
                    icon: "sun.max.fill",
                    isSelected: store.themePreset == .light,
                    store: store
                )
                
                ThemeOptionCard(
                    preset: .dark,
                    title: "Dark",
                    subtitle: nil,
                    icon: "moon.stars.fill",
                    isSelected: store.themePreset == .dark,
                    store: store
                )
            }
            .padding(.top, BrandSpacing.xs)
        }
    }
}

// MARK: - Step 5: System Skill Scan (Final Step with Permission, Excludes Builtin)

private struct Step5DiscoveryChamber: View {
    @ObservedObject var store: CitadelStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.md) {
            VStack(alignment: .leading, spacing: BrandSpacing.xxs) {
                Text("ENVIRONMENT DISCOVERY (FINAL STEP)")
                    .font(.brandMonoBadge)
                    .tracking(1.0)
                    .foregroundColor(store.palette.accent)
                
                Text("Discover Existing AI Skills & Workspaces")
                    .font(.brandTitle)
                    .foregroundColor(store.palette.textPrimary)
                
                Text("Citadel discovers your environment without modifying or connecting anything automatically. Review AI configurations and project workspaces discovered across your system.")
                    .font(.brandBody)
                    .foregroundColor(store.palette.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(alignment: .leading, spacing: BrandSpacing.sm) {
                if !store.hasGrantedScanPermission {
                    VStack(alignment: .leading, spacing: BrandSpacing.xs) {
                        HStack {
                            Image(systemName: "magnifyingglass.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(store.palette.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Permission Request: Scan User Folders & Projects")
                                    .font(.brandBodyBold)
                                    .foregroundColor(store.palette.textPrimary)
                                Text("Discovers skills, MCP configurations, and workspaces without connecting them.")
                                    .font(.brandCaption)
                                    .foregroundColor(store.palette.textSecondary)
                            }
                        }
                        
                        HStack(spacing: BrandSpacing.sm) {
                            Button(action: {
                                runDiscovery()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkle.magnifyingglass")
                                    Text("GRANT ACCESS & SCAN ALL")
                                }
                                .font(.brandMonoBadge)
                                .foregroundColor(store.palette.textPrimary)
                                .padding(.horizontal, BrandSpacing.lg)
                                .padding(.vertical, BrandSpacing.xs + 2)
                                .liquidGlassPill(tint: store.palette.accent)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                pickCustomProjectFolder()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder.badge.plus")
                                    Text("ADD PROJECT FOLDER...")
                                }
                                .font(.brandMonoBadge)
                                .foregroundColor(store.palette.textSecondary)
                                .padding(.horizontal, BrandSpacing.md)
                                .padding(.vertical, BrandSpacing.xs + 2)
                                .liquidGlassPill()
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, BrandSpacing.xs)
                    }
                } else if store.isScanningOnboarding {
                    HStack(spacing: BrandSpacing.sm) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Scanning directories for AI configs and workspaces...")
                            .font(.brandBody)
                            .foregroundColor(store.palette.textSecondary)
                    }
                    .padding(.vertical, BrandSpacing.md)
                } else {
                    VStack(alignment: .leading, spacing: BrandSpacing.sm) {
                        // Segmented Picker: AI Config vs Workspaces
                        HStack {
                            Picker("", selection: $store.onboardingDiscoverySegment) {
                                Text("AI Config (\(store.discoveredSkills.count + store.discoveredMCPs.count))").tag("ai_config")
                                Text("Workspaces (\(store.discoveredWorkspaces.count))").tag("workspaces")
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 320)
                            
                            Spacer()
                            
                            Text("Discovered • Not connected")
                                .font(.brandMonoMicro)
                                .foregroundColor(store.palette.textMuted)
                        }
                        
                        if store.onboardingDiscoverySegment == "ai_config" {
                            // AI Config Segment (Skills & MCP Servers)
                            ScrollView {
                                VStack(alignment: .leading, spacing: 6) {
                                    if !store.discoveredSkills.isEmpty {
                                        Text("SKILLS (\(store.discoveredSkills.count))")
                                            .font(.brandMonoMicro)
                                            .foregroundColor(store.palette.accent)
                                            .padding(.top, 2)
                                        
                                        ForEach(store.discoveredSkills.prefix(6)) { skill in
                                            HStack {
                                                Image(systemName: "sparkles")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(store.palette.accent)
                                                Text(skill.name)
                                                    .font(.brandMono)
                                                    .foregroundColor(store.palette.textPrimary)
                                                Spacer()
                                                Text(skill.sourceKind)
                                                    .font(.brandMonoMicro)
                                                    .foregroundColor(store.palette.textMuted)
                                            }
                                            .padding(.vertical, 2)
                                        }
                                        if store.discoveredSkills.count > 6 {
                                            Text("+ \(store.discoveredSkills.count - 6) more skills")
                                                .font(.brandCaption)
                                                .foregroundColor(store.palette.textMuted)
                                        }
                                    }
                                    
                                    if !store.discoveredMCPs.isEmpty {
                                        Text("MCP CONFIGURATIONS (\(store.discoveredMCPs.count))")
                                            .font(.brandMonoMicro)
                                            .foregroundColor(store.palette.accent)
                                            .padding(.top, 6)
                                        
                                        ForEach(store.discoveredMCPs.prefix(4)) { mcp in
                                            HStack {
                                                Image(systemName: "server.rack")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(store.palette.textMuted)
                                                Text(mcp.name)
                                                    .font(.brandMono)
                                                    .foregroundColor(store.palette.textPrimary)
                                                Spacer()
                                                Text(mcp.clientName)
                                                    .font(.brandMonoMicro)
                                                    .foregroundColor(store.palette.textMuted)
                                            }
                                            .padding(.vertical, 2)
                                        }
                                    }
                                    
                                    if store.discoveredSkills.isEmpty && store.discoveredMCPs.isEmpty {
                                        Text("No existing AI configurations detected.")
                                            .font(.brandCaption)
                                            .foregroundColor(store.palette.textMuted)
                                            .padding(.vertical, 8)
                                    }
                                }
                            }
                            .frame(maxHeight: 140)
                        } else {
                            // Workspaces Segment (Discovered without connecting)
                            ScrollView {
                                VStack(alignment: .leading, spacing: 6) {
                                    if store.discoveredWorkspaces.isEmpty {
                                        Text("No Git workspaces found in standard search roots.")
                                            .font(.brandCaption)
                                            .foregroundColor(store.palette.textMuted)
                                            .padding(.vertical, 8)
                                    } else {
                                        ForEach(store.discoveredWorkspaces.prefix(8)) { ws in
                                            HStack(spacing: 8) {
                                                Image(systemName: "folder")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(store.palette.accent)
                                                
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text(ws.name)
                                                        .font(.brandMono)
                                                        .foregroundColor(store.palette.textPrimary)
                                                    Text(ws.path.path)
                                                        .font(.brandMonoMicro)
                                                        .foregroundColor(store.palette.textMuted)
                                                        .lineLimit(1)
                                                }
                                                
                                                Spacer()
                                                
                                                HStack(spacing: 3) {
                                                    if ws.hasGemini {
                                                        Text("gemini")
                                                            .font(.brandMonoMicro)
                                                            .foregroundColor(store.palette.textSecondary)
                                                            .padding(.horizontal, 4)
                                                            .padding(.vertical, 1)
                                                            .background(store.palette.accentMuted)
                                                            .clipShape(BrandShapes.pill)
                                                    }
                                                    if ws.hasClaude {
                                                        Text("claude")
                                                            .font(.brandMonoMicro)
                                                            .foregroundColor(store.palette.textSecondary)
                                                            .padding(.horizontal, 4)
                                                            .padding(.vertical, 1)
                                                            .background(store.palette.accentMuted)
                                                            .clipShape(BrandShapes.pill)
                                                    }
                                                    if ws.hasCursor {
                                                        Text("cursor")
                                                            .font(.brandMonoMicro)
                                                            .foregroundColor(store.palette.textSecondary)
                                                            .padding(.horizontal, 4)
                                                            .padding(.vertical, 1)
                                                            .background(store.palette.accentMuted)
                                                            .clipShape(BrandShapes.pill)
                                                    }
                                                }
                                                
                                                Text("DISCOVERED")
                                                    .font(.brandMonoMicro)
                                                    .foregroundColor(store.palette.textMuted)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 1)
                                                    .background(store.palette.background)
                                                    .clipShape(BrandShapes.pill)
                                            }
                                            .padding(.vertical, 3)
                                        }
                                        if store.discoveredWorkspaces.count > 8 {
                                            Text("+ \(store.discoveredWorkspaces.count - 8) more workspaces discovered")
                                                .font(.brandCaption)
                                                .foregroundColor(store.palette.textMuted)
                                                .padding(.top, 2)
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 140)
                        }
                    }
                }
            }
            .padding(BrandSpacing.md)
            .liquidGlass(cornerRadius: BrandCornerRadius.md)
        }
    }
    
    private func runDiscovery() {
        store.hasGrantedScanPermission = true
        store.isScanningOnboarding = true
        Task {
            let report = await MultiverseDiscoveryEngine.shared.runFullDiscoveryAsync(workspaceRoots: nil)
            await MainActor.run {
                store.discoveredSkills = report.skills
                store.skillGroups = SkillGroupManager.shared.groupDiscoveredSkills(report.skills)
                store.discoveredMCPs = report.mcps
                store.discoveredWorkspaces = report.workspaces
                store.isScanningOnboarding = false
            }
        }
    }
    
    private func pickCustomProjectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Grant Access & Scan"
        if panel.runModal() == .OK {
            store.hasGrantedScanPermission = true
            store.isScanningOnboarding = true
            let selectedURLs = panel.urls
            Task {
                var roots = SkillDiscoveryEngine.shared.defaultScanRoots
                roots.append(contentsOf: selectedURLs)
                let report = await MultiverseDiscoveryEngine.shared.runFullDiscoveryAsync(workspaceRoots: roots)
                await MainActor.run {
                    store.discoveredSkills = report.skills
                    store.skillGroups = SkillGroupManager.shared.groupDiscoveredSkills(report.skills)
                    store.discoveredMCPs = report.mcps
                    store.discoveredWorkspaces = report.workspaces
                    store.isScanningOnboarding = false
                }
            }
        }
    }
}

private struct ThemeOptionCard: View {
    let preset: ThemePreset
    let title: String
    let subtitle: String?
    let icon: String
    let isSelected: Bool
    @ObservedObject var store: CitadelStore
    
    var body: some View {
        Button(action: {
            withAnimation(BrandMotion.fastSpring) {
                store.themePreset = preset
            }
        }) {
            VStack(alignment: .leading, spacing: BrandSpacing.sm) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? store.palette.accent : store.palette.textSecondary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(store.palette.accent)
                    }
                }
                
                Text(title)
                    .font(.brandHeadline)
                    .foregroundColor(store.palette.textPrimary)
                
                if let sub = subtitle {
                    Text(sub)
                        .font(.brandCaption)
                        .foregroundColor(store.palette.textSecondary)
                        .lineSpacing(2)
                }
                
                Spacer()
            }
            .padding(BrandSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 90)
            .liquidGlass(cornerRadius: BrandCornerRadius.lg, tint: isSelected ? store.palette.accent : nil)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Root Window

struct CitadelRootView: View {
    @ObservedObject var store: CitadelStore
    @Environment(\.colorScheme) private var systemScheme
    
    var preferredScheme: ColorScheme? {
        switch store.themePreset {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
    
    var body: some View {
        CitadelBodyView(store: store)
            .preferredColorScheme(preferredScheme)
    }
}

private struct CitadelBodyView: View {
    @ObservedObject var store: CitadelStore
    @Environment(\.colorScheme) private var envScheme
    
    var effectivePalette: ThemePalette {
        let isSystemDark: Bool
        if store.themePreset == .system {
            // When user chooses System, read macOS system setting directly
            if let appearance = NSApp?.effectiveAppearance,
               let match = appearance.bestMatch(from: [.darkAqua, .aqua]) {
                isSystemDark = (match == .darkAqua)
            } else if let globalDict = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain),
                      let style = globalDict["AppleInterfaceStyle"] as? String {
                isSystemDark = style.caseInsensitiveCompare("dark") == .orderedSame
            } else {
                isSystemDark = false
            }
        } else {
            isSystemDark = (envScheme == .dark)
        }
        return ThemePalette.forPreset(store.themePreset, isSystemDark: isSystemDark)
    }
    
    var body: some View {
        ZStack {
            // Native Window Liquid Glass Base
            NativeBlurBackground(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            effectivePalette.background.opacity(effectivePalette.isDark ? 0.75 : 0.82)
                .ignoresSafeArea()
            
            if !store.isOnboardingComplete {
                OnboardingStartupView(store: store)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                VStack(spacing: 0) {
                    // Liquid Glass Floating Top Navigation
                    HeaderChrome(store: store)
                        .padding(.horizontal, BrandSpacing.md)
                        .padding(.top, BrandSpacing.sm)
                        .padding(.bottom, BrandSpacing.xs)
                    
                    Divider()
                        .background(store.palette.border.opacity(0.4))
                    
                    // Studio Body with Draggable Sidebar (HSplitView)
                    HSplitView {
                        SidebarDeck(store: store)
                            .frame(minWidth: 160, idealWidth: store.sidebarWidth, maxWidth: 340)
                        
                        Group {
                            switch store.selectedNav {
                            case .armory:
                                ArmoryChamber(store: store)
                            case .discovery:
                                DiscoveryChamber(store: store)
                            case .marketplace:
                                MarketplaceChamber(store: store)
                            case .workspaces:
                                WorkspacesChamber(store: store)
                            case .settings:
                                SettingsChamber(store: store)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    Divider()
                        .background(store.palette.border.opacity(0.4))
                    
                    // Status Deck
                    StatusDeck(store: store)
                }
            }
        }
        .frame(minWidth: 1040, minHeight: 640)
        .onAppear {
            syncSystemColorScheme()
        }
        .onChange(of: envScheme) { _, _ in
            syncSystemColorScheme()
        }
        .sheet(isPresented: $store.showAuthModal) {
            OAuthModalSheet(store: store)
        }
    }
    
    private func syncSystemColorScheme() {
        if let appearance = NSApp?.effectiveAppearance,
           let match = appearance.bestMatch(from: [.darkAqua, .aqua]) {
            store.systemColorScheme = (match == .darkAqua) ? .dark : .light
        } else if let globalDict = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain),
                  let style = globalDict["AppleInterfaceStyle"] as? String,
                  style.caseInsensitiveCompare("dark") == .orderedSame {
            store.systemColorScheme = .dark
        } else {
            store.systemColorScheme = .light
        }
        store.objectWillChange.send()
    }
}

// MARK: - OAuth Modal Sheet (Available in both Onboarding and Settings)

struct OAuthModalSheet: View {
    @ObservedObject var store: CitadelStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "safari.fill")
                    .foregroundColor(store.palette.accent)
                    .font(.system(size: 20))
                Text("\(store.authModalProvider.rawValue) OAuth Authentication")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(store.palette.textPrimary)
            }
            
            if let devCode = store.oauthDeviceCode {
                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Confirm this 8-digit verification code:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(store.palette.textSecondary)
                    
                    HStack(spacing: 12) {
                        Text(devCode.userCode)
                            .font(.system(size: 26, weight: .black, design: .monospaced))
                            .tracking(4)
                            .foregroundColor(store.palette.accent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(store.palette.accentMuted)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.palette.accent.opacity(0.4), lineWidth: 1))
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(devCode.userCode, forType: .string)
                            store.oauthUserCodeCopied = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: store.oauthUserCodeCopied ? "checkmark" : "doc.on.doc")
                                Text(store.oauthUserCodeCopied ? "Copied" : "Copy Code")
                            }
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(store.palette.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(store.palette.card)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(store.palette.borderStrong, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text("2. Authorize in your default browser:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(store.palette.textSecondary)
                    
                    Button(action: {
                        if let url = URL(string: devCode.verificationURI) {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square.fill")
                            Text("OPEN \(store.authModalProvider.rawValue.uppercased()) VERIFICATION PAGE")
                        }
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(store.palette.background)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(store.palette.accent)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    HStack(spacing: 8) {
                        if store.isAuthenticating {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else if store.oauthErrorMessage != nil {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color.orange)
                        }
                        Text(store.oauthStatusMessage)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(store.oauthErrorMessage != nil ? Color.orange : store.palette.textMuted)
                    }
                    .padding(.top, 4)
                    
                    if let err = store.oauthErrorMessage {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "xmark.octagon.fill")
                                .foregroundColor(Color.red)
                                .font(.system(size: 14))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Authorization Declined or Failed")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(store.palette.textPrimary)
                                Text(err)
                                    .font(.system(size: 11))
                                    .foregroundColor(store.palette.textSecondary)
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
                        if store.isAuthenticating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if store.oauthErrorMessage != nil {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color.orange)
                        }
                        Text(store.oauthStatusMessage)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(store.oauthErrorMessage != nil ? Color.orange : store.palette.textSecondary)
                    }
                    
                    if let err = store.oauthErrorMessage {
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundColor(Color.red)
                    }
                }
                .padding(.vertical, 16)
            }
            
            Divider().background(store.palette.border)
            
            // Fallback token option
            DisclosureGroup("Or enter Personal Access Token directly") {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("Token...", text: $store.authInputToken)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                    
                    Button("Sign In with Token") {
                        store.loginWithToken()
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.authInputToken.isEmpty)
                }
                .padding(.top, 6)
            }
            .font(.system(size: 11))
            .foregroundColor(store.palette.textMuted)
            
            HStack {
                Spacer()
                Button("Cancel") { store.showAuthModal = false }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 490)
        .background(store.palette.card)
    }
}

// MARK: - Header Chrome

struct HeaderChrome: View {
    @ObservedObject var store: CitadelStore
    
    var body: some View {
        HStack(spacing: BrandSpacing.sm) {
            // Drag Region / Traffic Lights Spacer
            Spacer().frame(width: 68)
            
            HStack(spacing: BrandSpacing.xs) {
                CitadelBrandLogoView(size: 20, tint: store.palette.accent)
                
                Text("CITADEL")
                    .font(.brandMonoBold)
                    .tracking(1.4)
                    .foregroundColor(store.palette.textPrimary)
                
                Text("/")
                    .font(.brandMono)
                    .foregroundColor(store.palette.textMuted)
                
                Text(store.selectedNav.rawValue.uppercased())
                    .font(.brandMonoBadge)
                    .tracking(0.55)
                    .foregroundColor(store.palette.textSecondary)
            }
            
            Spacer()
            
            // Multiverse Sync Status Pill (Liquid Glass)
            HStack(spacing: BrandSpacing.xxs + 2) {
                Circle()
                    .fill(store.palette.accent)
                    .frame(width: 6, height: 6)
                Text(store.isSyncing ? "SYNCING..." : "MULTIVERSE IN SYNC")
                    .font(.brandMonoBadge)
                    .tracking(0.5)
                    .foregroundColor(store.palette.textSecondary)
            }
            .padding(.horizontal, BrandSpacing.sm)
            .padding(.vertical, BrandSpacing.xxs + 2)
            .liquidGlassPill()
            
            // Cloud Sync Status Indicator (Liquid Glass)
            if store.remoteStatus.isConfigured {
                HStack(spacing: BrandSpacing.xxs + 2) {
                    Image(systemName: store.isCloudSyncing ? "arrow.triangle.2.circlepath" : (store.cloudSyncSuccess ? "checkmark.icloud.fill" : "icloud.fill"))
                        .font(.system(size: 11))
                        .foregroundColor(store.palette.accent)
                    Text(store.isCloudSyncing ? "CLOUD SYNCING..." : (store.cloudSyncSuccess ? "CLOUD SYNCED" : "CLOUD CONNECTED"))
                        .font(.brandMonoBadge)
                        .tracking(0.5)
                        .foregroundColor(store.palette.accent)
                }
                .padding(.horizontal, BrandSpacing.sm)
                .padding(.vertical, BrandSpacing.xxs + 2)
                .liquidGlassPill(tint: store.palette.accent)
            } else {
                HStack(spacing: BrandSpacing.xxs + 1) {
                    Image(systemName: "icloud.slash")
                        .font(.system(size: 10))
                        .foregroundColor(store.palette.textMuted)
                    Text("LOCAL ONLY")
                        .font(.brandMonoMicro)
                        .foregroundColor(store.palette.textMuted)
                }
                .padding(.horizontal, BrandSpacing.sm)
                .padding(.vertical, BrandSpacing.xxs + 2)
                .liquidGlassPill()
            }
            
            // Sync Button (Liquid Glass Interactive)
            Button(action: {
                store.syncAll()
            }) {
                HStack(spacing: BrandSpacing.xxs + 2) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .bold))
                        .rotationEffect(.degrees(store.isSyncing ? 360 : 0))
                        .animation(store.isSyncing ? Animation.linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: store.isSyncing)
                    Text("SYNC ALL")
                        .font(.brandMonoBadge)
                }
                .foregroundColor(store.palette.textPrimary)
                .padding(.horizontal, BrandSpacing.md)
                .padding(.vertical, BrandSpacing.xs)
                .liquidGlassPill(tint: store.palette.accent)
            }
            .buttonStyle(.plain)
            .disabled(store.isSyncing)
        }
    }
}

// MARK: - Sidebar Deck

struct SidebarDeck: View {
    @ObservedObject var store: CitadelStore
    
    var visibleNavSections: [NavSection] {
        NavSection.allCases.filter { section in
            switch section {
            case .marketplace:
                return FeatureFlags.shared.npmMarketplaceEnabled
            case .workspaces:
                return FeatureFlags.shared.workspacePortalsEnabled
            default:
                return true
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("THE COUNCIL")
                .font(.brandMonoBadge)
                .tracking(1.0)
                .foregroundColor(store.palette.textMuted)
                .padding(.horizontal, BrandSpacing.sm)
                .padding(.top, BrandSpacing.md)
                .padding(.bottom, BrandSpacing.xs)
            
            ForEach(visibleNavSections) { section in
                Button(action: {
                    store.selectedNav = section
                }) {
                    HStack(spacing: BrandSpacing.xs + 2) {
                        Image(systemName: section.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 18)
                            .foregroundColor(store.selectedNav == section ? store.palette.accent : store.palette.textSecondary)
                        
                        Text(section.rawValue)
                            .font(store.selectedNav == section ? .brandBodyBold : .brandBody)
                            .foregroundColor(store.selectedNav == section ? store.palette.textPrimary : store.palette.textSecondary)
                        
                        Spacer()
                        
                        if section == .armory {
                            Text("\(store.skills.count)")
                                .font(.brandMonoBadge)
                                .foregroundColor(store.selectedNav == section ? store.palette.accent : store.palette.textMuted)
                                .padding(.horizontal, BrandSpacing.xs)
                                .padding(.vertical, 2)
                                .background(store.palette.card)
                                .clipShape(BrandShapes.pill)
                        }
                    }
                    .padding(.horizontal, BrandSpacing.sm)
                    .padding(.vertical, BrandSpacing.xs)
                    .background {
                        if store.selectedNav == section {
                            store.palette.accentMuted
                                .clipShape(BrandShapes.pill)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, BrandSpacing.xs)
            }
            
            Spacer()
            
            // Storage Target Tag (Liquid Glass Pill)
            VStack(alignment: .leading, spacing: BrandSpacing.xxs) {
                Text("CENTRAL HUB")
                    .font(.brandMonoBadge)
                    .foregroundColor(store.palette.textMuted)
                Text(store.customHubPath)
                    .font(.brandMono)
                    .foregroundColor(store.palette.accent)
            }
            .padding(.horizontal, BrandSpacing.sm)
            .padding(.vertical, BrandSpacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(cornerRadius: BrandCornerRadius.md)
            .padding(BrandSpacing.sm)
        }
        .background(store.palette.card.opacity(0.2))
    }
}

// MARK: - Armory Chamber

struct ArmoryChamber: View {
    @ObservedObject var store: CitadelStore
    
    var filteredSkills: [Skill] {
        if store.searchText.isEmpty { return store.skills }
        return store.skills.filter { skill in
            skill.name.localizedCaseInsensitiveContains(store.searchText) ||
            (skill.description?.localizedCaseInsensitiveContains(store.searchText) ?? false) ||
            (skill.author?.localizedCaseInsensitiveContains(store.searchText) ?? false) ||
            (skill.version?.localizedCaseInsensitiveContains(store.searchText) ?? false)
        }
    }
    
    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                // Minimalist Search Bar with Toggle Preview Button
                HStack(spacing: BrandSpacing.xs) {
                    HStack(spacing: BrandSpacing.xs) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(store.palette.textMuted)
                            .font(.system(size: 12))
                        TextField("Search skills...", text: $store.searchText)
                            .textFieldStyle(.plain)
                            .font(.brandMono)
                            .foregroundColor(store.palette.textPrimary)
                    }
                    .padding(.horizontal, BrandSpacing.sm)
                    .padding(.vertical, BrandSpacing.xs)
                    .liquidGlassPill()
                    
                    // Toggle preview inspector button
                    Button(action: {
                        withAnimation(BrandMotion.fastSpring) {
                            store.showSkillPreview.toggle()
                        }
                    }) {
                        Image(systemName: store.showSkillPreview ? "sidebar.right" : "sidebar.squares.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(store.showSkillPreview ? store.palette.accent : store.palette.textMuted)
                            .frame(width: 30, height: 30)
                            .liquidGlassPill(tint: store.showSkillPreview ? store.palette.accent : nil)
                    }
                    .buttonStyle(.plain)
                    .help(store.showSkillPreview ? "Hide skill preview pane" : "Show skill preview pane")
                }
                .padding(BrandSpacing.sm)
                
                Divider()
                    .background(store.palette.border.opacity(0.4))
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredSkills) { skill in
                            Button(action: { store.selectSkill(skill) }) {
                                VStack(alignment: .leading, spacing: BrandSpacing.xxs + 1) {
                                    // Row 1: Name, Icon/Version, Active Dot
                                    HStack(spacing: BrandSpacing.xs) {
                                        if let icon = skill.icon, !icon.isEmpty {
                                            Image(systemName: icon)
                                                .font(.system(size: 11))
                                                .foregroundColor(store.palette.accent)
                                        }
                                        
                                        Text(skill.name)
                                            .font(.brandMonoBold)
                                            .foregroundColor(store.selectedSkill?.id == skill.id ? store.palette.accent : store.palette.textPrimary)
                                        
                                        if let ver = skill.version, !ver.isEmpty {
                                            Text("v\(ver)")
                                                .font(.brandMonoMicro)
                                                .foregroundColor(store.palette.textMuted)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(store.palette.card)
                                                .clipShape(BrandShapes.pill)
                                        }
                                        
                                        Spacer()
                                        
                                        if store.selectedSkill?.id == skill.id {
                                            Circle()
                                                .fill(store.palette.accent)
                                                .frame(width: 5, height: 5)
                                                .shadow(color: store.palette.accent.opacity(0.6), radius: 3)
                                        }
                                    }
                                    
                                    // Row 2: Description
                                    if let d = skill.description, !d.isEmpty {
                                        Text(d)
                                            .font(.brandCaption)
                                            .foregroundColor(store.palette.textSecondary)
                                            .lineLimit(2)
                                    }
                                    
                                    // Row 3: Metadata chips (Author, Argument hint, Symlink badge)
                                    HStack(spacing: BrandSpacing.xs) {
                                        if let author = skill.author, !author.isEmpty {
                                            Text(author)
                                                .font(.brandMonoMicro)
                                                .foregroundColor(store.palette.textMuted)
                                        }
                                        
                                        if let hint = skill.argumentHint, !hint.isEmpty {
                                            Text(hint)
                                                .font(.brandMonoMicro)
                                                .foregroundColor(store.palette.accent)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(store.palette.accentMuted)
                                                .clipShape(BrandShapes.pill)
                                                .lineLimit(1)
                                        }
                                        
                                        if skill.isSymlink {
                                            Text("LINKED")
                                                .font(.brandMonoMicro)
                                                .foregroundColor(store.palette.textMuted)
                                        }
                                    }
                                    .padding(.top, 2)
                                }
                                .padding(.horizontal, BrandSpacing.md)
                                .padding(.vertical, BrandSpacing.sm)
                                .background {
                                    if store.selectedSkill?.id == skill.id {
                                        store.palette.accentMuted
                                    } else {
                                        Color.clear
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                                .background(store.palette.border.opacity(0.25))
                        }
                    }
                }
            }
            .frame(minWidth: 280, idealWidth: 340, maxWidth: store.showSkillPreview ? 460 : .infinity)
            .background(store.palette.background.opacity(0.3))
            
            // Skill Preview Pane (Hideable)
            if store.showSkillPreview {
                Group {
                    if let skill = store.selectedSkill {
                        SkillDetailView(
                            skill: skill,
                            content: store.skillContent,
                            palette: store.palette,
                            onClose: {
                                withAnimation(BrandMotion.fastSpring) {
                                    store.showSkillPreview = false
                                }
                            }
                        )
                    } else {
                        VStack(spacing: BrandSpacing.xs) {
                            Text("Select a skill from the Armory")
                                .font(.brandSubheadline)
                                .foregroundColor(store.palette.textMuted)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(minWidth: 420)
            }
        }
    }
}

// MARK: - Settings & Theme Overrides Chamber

struct SettingsChamber: View {
    @ObservedObject var store: CitadelStore
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrandSpacing.lg) {
                Text("SYSTEM & CLOUD PREFERENCES")
                    .font(.brandMonoBadge)
                    .tracking(1.0)
                    .foregroundColor(store.palette.textMuted)
                
                // 1. Theme Presets (System, Light, Dark)
                VStack(alignment: .leading, spacing: BrandSpacing.sm) {
                    Text("Appearance")
                        .font(.brandHeadline)
                        .foregroundColor(store.palette.textPrimary)
                    
                    HStack(spacing: BrandSpacing.sm) {
                        ForEach(ThemePreset.allCases) { preset in
                            Button(action: { store.themePreset = preset }) {
                                HStack(spacing: BrandSpacing.xs) {
                                    Image(systemName: preset == .system ? "circle.lefthalf.filled" : (preset == .light ? "sun.max.fill" : "moon.stars.fill"))
                                        .font(.system(size: 13))
                                    Text(preset.rawValue)
                                        .font(.brandBodyBold)
                                }
                                .foregroundColor(store.themePreset == preset ? store.palette.accent : store.palette.textPrimary)
                                .padding(.horizontal, BrandSpacing.md)
                                .padding(.vertical, BrandSpacing.xs + 2)
                                .liquidGlassPill(tint: store.themePreset == preset ? store.palette.accent : nil)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(BrandSpacing.md)
                .liquidGlass(cornerRadius: BrandCornerRadius.lg)
                
                // 2. Cloud Sync & Git Provider Section
                VStack(alignment: .leading, spacing: BrandSpacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cloud Sync & Multi-Device Backup")
                                .font(.brandHeadline)
                                .foregroundColor(store.palette.textPrimary)
                            Text("Optional remote synchronization via your personal GitHub or GitLab account.")
                                .font(.brandCaption)
                                .foregroundColor(store.palette.textMuted)
                        }
                        Spacer()
                        if store.remoteStatus.isConfigured {
                            HStack(spacing: BrandSpacing.xs) {
                                Button(action: { store.pullRemote() }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "arrow.down.circle")
                                        Text("PULL")
                                    }
                                    .font(.brandMonoBadge)
                                    .foregroundColor(store.palette.textPrimary)
                                    .padding(.horizontal, BrandSpacing.sm)
                                    .padding(.vertical, BrandSpacing.xxs + 2)
                                    .liquidGlassPill()
                                }
                                .buttonStyle(.plain)
                                .disabled(store.isCloudSyncing)
                                
                                Button(action: { store.pushRemote() }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: store.isCloudSyncing ? "arrow.triangle.2.circlepath" : "arrow.up.circle.fill")
                                        Text(store.isCloudSyncing ? "SYNCING..." : "PUSH")
                                    }
                                    .font(.brandMonoBadge)
                                    .foregroundColor(store.palette.accent)
                                    .padding(.horizontal, BrandSpacing.sm)
                                    .padding(.vertical, BrandSpacing.xxs + 2)
                                    .liquidGlassPill(tint: store.palette.accent)
                                }
                                .buttonStyle(.plain)
                                .disabled(store.isCloudSyncing)
                            }
                        }
                    }
                    
                    Divider().background(store.palette.border.opacity(0.3))
                    
                    // Connected Accounts Row
                    HStack(spacing: BrandSpacing.md) {
                        // GitHub Account Box (Feature flag gated)
                        if FeatureFlags.shared.githubIntegrationEnabled {
                            HStack(spacing: BrandSpacing.sm) {
                                Image(systemName: "globe")
                                    .font(.system(size: 20))
                                    .foregroundColor(store.palette.textPrimary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("GitHub")
                                        .font(.brandBodyBold)
                                        .foregroundColor(store.palette.textPrimary)
                                    if let user = store.githubUser {
                                        Text("@\(user.username)")
                                            .font(.brandMono)
                                            .foregroundColor(store.palette.accent)
                                    } else {
                                        Text("Not signed in")
                                            .font(.brandCaption)
                                            .foregroundColor(store.palette.textMuted)
                                    }
                                }
                                Spacer()
                                if let _ = store.githubUser {
                                    Button("Disconnect") { store.logout(provider: .github) }
                                        .font(.brandMonoMicro)
                                        .foregroundColor(Color.red.opacity(0.8))
                                        .buttonStyle(.plain)
                                } else {
                                    Button("OAuth Sign In") {
                                        store.startOAuthFlow(for: .github)
                                    }
                                    .font(.brandMonoBadge)
                                    .foregroundColor(store.palette.accent)
                                    .padding(.horizontal, BrandSpacing.sm)
                                    .padding(.vertical, BrandSpacing.xxs)
                                    .liquidGlassPill(tint: store.palette.accent)
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(BrandSpacing.md)
                            .liquidGlass(cornerRadius: BrandCornerRadius.md)
                        }
                        
                        // GitLab Account Box (Feature flag gated)
                        if FeatureFlags.shared.gitlabIntegrationEnabled {
                            HStack(spacing: BrandSpacing.sm) {
                                Image(systemName: "server.rack")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color.orange)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("GitLab")
                                        .font(.brandBodyBold)
                                        .foregroundColor(store.palette.textPrimary)
                                    if let user = store.gitlabUser {
                                        Text("@\(user.username)")
                                            .font(.brandMono)
                                            .foregroundColor(store.palette.accent)
                                    } else {
                                        Text("Not signed in")
                                            .font(.brandCaption)
                                            .foregroundColor(store.palette.textMuted)
                                    }
                                }
                                Spacer()
                                if let _ = store.gitlabUser {
                                    Button("Disconnect") { store.logout(provider: .gitlab) }
                                        .font(.brandMonoMicro)
                                        .foregroundColor(Color.red.opacity(0.8))
                                        .buttonStyle(.plain)
                                } else {
                                    Button("OAuth Sign In") {
                                        store.startOAuthFlow(for: .gitlab)
                                    }
                                    .font(.brandMonoBadge)
                                    .foregroundColor(Color.orange)
                                    .padding(.horizontal, BrandSpacing.sm)
                                    .padding(.vertical, BrandSpacing.xxs)
                                    .liquidGlassPill(tint: Color.orange)
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(BrandSpacing.md)
                            .liquidGlass(cornerRadius: BrandCornerRadius.md)
                        }
                    }
                    
                    // Remote Target Selection & Custom Repo Input
                    VStack(alignment: .leading, spacing: BrandSpacing.sm) {
                        HStack {
                            Text("Remote Store Repository")
                                .font(.brandBodyBold)
                                .foregroundColor(store.palette.textSecondary)
                            Spacer()
                            if let prov = store.githubUser != nil ? GitProvider.github : (store.gitlabUser != nil ? GitProvider.gitlab : nil) {
                                Button(action: { store.fetchAvailableRepos(for: prov) }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: store.isLoadingRepos ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                                        Text(store.isLoadingRepos ? "Loading..." : "Refresh User Repos")
                                    }
                                    .font(.brandMonoMicro)
                                    .foregroundColor(store.palette.accent)
                                }
                                .buttonStyle(.plain)
                                .disabled(store.isLoadingRepos)
                            }
                        }
                        
                        // Active Configured Remote URL
                        if let activeRemote = store.remoteStatus.remoteURL {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(store.palette.accent)
                                Text(GitAuthProvider.shared.sanitizedRemoteURL(activeRemote))
                                    .font(.brandMono)
                                    .foregroundColor(store.palette.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                
                                if let webURL = GitAuthProvider.shared.webURL(forRemote: activeRemote) {
                                    Button(action: {
                                        NSWorkspace.shared.open(webURL)
                                    }) {
                                        HStack(spacing: 3) {
                                            Image(systemName: "arrow.up.right.square")
                                            Text("Open")
                                        }
                                        .font(.brandMonoMicro)
                                        .foregroundColor(store.palette.accent)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Button("Change") {
                                    _ = RemoteSyncManager.shared.setRemoteURL("")
                                    store.remoteRepoExists = false
                                    store.refresh()
                                    store.scanFilesystem()
                                }
                                .font(.brandMonoMicro)
                                .foregroundColor(store.palette.textMuted)
                                .buttonStyle(.plain)
                            }
                            .padding(BrandSpacing.sm)
                            .liquidGlass(cornerRadius: BrandCornerRadius.sm, tint: store.palette.accent)
                        } else {
                            // Picker for User Repositories if fetched
                            if !store.availableRemoteRepos.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Select from your account repositories:")
                                        .font(.brandCaption)
                                        .foregroundColor(store.palette.textMuted)
                                    
                                    ScrollView {
                                        LazyVStack(spacing: 4) {
                                            ForEach(store.availableRemoteRepos) { repo in
                                                Button(action: { store.selectRemoteRepository(repo) }) {
                                                    HStack {
                                                        Image(systemName: repo.isPrivate ? "lock.fill" : "globe")
                                                            .font(.system(size: 10))
                                                            .foregroundColor(store.palette.textMuted)
                                                        Text(repo.fullName)
                                                            .font(.brandMono)
                                                            .foregroundColor(store.palette.textPrimary)
                                                        Spacer()
                                                        Text("SELECT")
                                                            .font(.brandMonoBadge)
                                                            .foregroundColor(store.palette.accent)
                                                    }
                                                    .padding(.horizontal, BrandSpacing.sm)
                                                    .padding(.vertical, BrandSpacing.xs)
                                                    .liquidGlass(cornerRadius: BrandCornerRadius.sm)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                    .frame(maxHeight: 120)
                                }
                            }
                            
                            // Custom Git URL or Create Default Repo
                            HStack(spacing: BrandSpacing.xs) {
                                TextField("Enter any git repository URL (e.g. git@github.com:you/store.git)...", text: $store.customRepoInput)
                                    .textFieldStyle(.plain)
                                    .font(.brandMono)
                                    .padding(BrandSpacing.xs)
                                    .liquidGlass(cornerRadius: BrandCornerRadius.sm)
                                
                                Button("SET REPO") {
                                    store.setCustomRemoteRepository(store.customRepoInput)
                                    store.customRepoInput = ""
                                }
                                .font(.brandMonoBadge)
                                .foregroundColor(store.palette.textPrimary)
                                .padding(.horizontal, BrandSpacing.sm)
                                .padding(.vertical, BrandSpacing.xs)
                                .liquidGlassPill()
                                .buttonStyle(.plain)
                                .disabled(store.customRepoInput.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            
                            // Permission-based creation button
                            if store.githubUser != nil || store.gitlabUser != nil {
                                HStack {
                                    Text("Or create a brand new private repository:")
                                        .font(.brandCaption)
                                        .foregroundColor(store.palette.textMuted)
                                    Spacer()
                                    Button("Create Private 'citadel-sync'...") {
                                        store.showCreateRepoDialog = true
                                    }
                                    .font(.brandMonoMicro)
                                    .foregroundColor(store.palette.accent)
                                    .padding(.horizontal, BrandSpacing.sm)
                                    .padding(.vertical, BrandSpacing.xxs)
                                    .liquidGlassPill(tint: store.palette.accent)
                                    .buttonStyle(.plain)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
                .padding(BrandSpacing.md)
                .liquidGlass(cornerRadius: BrandCornerRadius.lg)
                
                // 3. Central Storage Directory
                VStack(alignment: .leading, spacing: BrandSpacing.md) {
                    Text("Central Citadel Hub Directory")
                        .font(.brandHeadline)
                        .foregroundColor(store.palette.textPrimary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hub Storage Path")
                            .font(.brandBodyBold)
                            .foregroundColor(store.palette.textPrimary)
                        HStack {
                            TextField("~/.citadel", text: $store.customHubPath)
                                .textFieldStyle(.plain)
                                .font(.brandMono)
                                .padding(BrandSpacing.xs)
                                .liquidGlass(cornerRadius: BrandCornerRadius.sm)
                            
                            Button("Reset to Default") {
                                store.customHubPath = "~/.citadel"
                            }
                            .font(.brandCaption)
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    Divider().background(store.palette.border.opacity(0.3))
                    
                    // Optional CLI Installation Card
                    VStack(alignment: .leading, spacing: BrandSpacing.xs) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Command Line Interface (CLI)")
                                        .font(.brandBodyBold)
                                        .foregroundColor(store.palette.textPrimary)
                                    Text(CLIManager.shared.isInstalled ? "INSTALLED" : "OPTIONAL")
                                        .font(.brandMonoMicro)
                                        .foregroundColor(CLIManager.shared.isInstalled ? store.palette.accent : store.palette.textMuted)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(CLIManager.shared.isInstalled ? store.palette.accentMuted : Color.clear)
                                        .clipShape(BrandShapes.pill)
                                }
                                Text(CLIManager.shared.isInstalled ? "citadel and ctdl are installed in ~/.local/bin." : "Install 'citadel' and 'ctdl' commands into ~/.local/bin (never forced).")
                                    .font(.brandCaption)
                                    .foregroundColor(store.palette.textMuted)
                            }
                            Spacer()
                            
                            HStack(spacing: BrandSpacing.xs) {
                                // View CLI Docs in default browser
                                Button(action: {
                                    NSWorkspace.shared.open(CitadelConstants.Web.docsURL)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "book.pages")
                                        Text("View Docs")
                                    }
                                    .font(.brandMonoBadge)
                                    .foregroundColor(store.palette.textSecondary)
                                    .padding(.horizontal, BrandSpacing.sm)
                                    .padding(.vertical, BrandSpacing.xxs)
                                    .liquidGlassPill()
                                }
                                .buttonStyle(.plain)
                                
                                if CLIManager.shared.isInstalled {
                                    Button("Uninstall CLI") {
                                        store.uninstallCLI()
                                    }
                                    .font(.brandMonoBadge)
                                    .foregroundColor(Color.red.opacity(0.8))
                                    .padding(.horizontal, BrandSpacing.sm)
                                    .padding(.vertical, BrandSpacing.xxs)
                                    .buttonStyle(.plain)
                                } else {
                                    Button("Install CLI") {
                                        store.installCLI()
                                    }
                                    .font(.brandMonoBadge)
                                    .foregroundColor(store.palette.accent)
                                    .padding(.horizontal, BrandSpacing.sm)
                                    .padding(.vertical, BrandSpacing.xxs)
                                    .liquidGlassPill(tint: store.palette.accent)
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        if !store.cliInstallationNotice.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(store.palette.accent)
                                Text(store.cliInstallationNotice)
                                    .font(.brandMonoMicro)
                                    .foregroundColor(store.palette.accent)
                            }
                            .padding(.top, 2)
                        } else if let errorMsg = store.cliErrorMessage {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(Color.red)
                                Text(errorMsg)
                                    .font(.brandMonoMicro)
                                    .foregroundColor(Color.red)
                            }
                            .padding(.top, 2)
                        }
                    }
                    
                    #if DEBUG
                    Divider().background(store.palette.border.opacity(0.3))
                    
                    // Testing & Developer Controls
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Re-test Onboarding Flow")
                                .font(.brandBodyBold)
                                .foregroundColor(store.palette.textPrimary)
                            Text("Reset onboarding state and test all 5 onboarding chambers.")
                                .font(.brandCaption)
                                .foregroundColor(store.palette.textMuted)
                        }
                        Spacer()
                        Button("Restart Onboarding") {
                            withAnimation(BrandMotion.fastSpring) {
                                store.restartOnboardingForTesting()
                            }
                        }
                        .font(.brandMonoBadge)
                        .foregroundColor(store.palette.accent)
                        .padding(.horizontal, BrandSpacing.sm)
                        .padding(.vertical, BrandSpacing.xxs)
                        .liquidGlassPill(tint: store.palette.accent)
                        .buttonStyle(.plain)
                    }
                    #endif
                }
                .padding(BrandSpacing.md)
                .liquidGlass(cornerRadius: BrandCornerRadius.lg)
                
                #if DEBUG
                // 4. Feature Flags (Experimental Lab) - Debug Only
                VStack(alignment: .leading, spacing: BrandSpacing.md) {
                    HStack(spacing: BrandSpacing.xs) {
                        Image(systemName: "flask.fill")
                            .foregroundColor(store.palette.accent)
                        Text("Feature Flags (Experimental Lab)")
                            .font(.brandHeadline)
                            .foregroundColor(store.palette.textPrimary)
                    }
                    
                    Text("Toggle isolated modules and experimental behaviors.")
                        .font(.brandCaption)
                        .foregroundColor(store.palette.textMuted)
                    
                    VStack(spacing: BrandSpacing.sm) {
                        Toggle(isOn: Binding(
                            get: { FeatureFlags.shared.githubIntegrationEnabled },
                            set: { FeatureFlags.shared.githubIntegrationEnabled = $0; store.objectWillChange.send() }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("GitHub Cloud Integration")
                                    .font(.brandBodyBold)
                                    .foregroundColor(store.palette.textPrimary)
                                Text("Repo-scoped sync and device authorization with GitHub App.")
                                    .font(.brandCaption)
                                    .foregroundColor(store.palette.textMuted)
                            }
                        }
                        .toggleStyle(.switch)
                        
                        Divider().background(store.palette.border.opacity(0.3))
                        
                        Toggle(isOn: Binding(
                            get: { FeatureFlags.shared.gitlabIntegrationEnabled },
                            set: { FeatureFlags.shared.gitlabIntegrationEnabled = $0; store.objectWillChange.send() }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("GitLab Cloud Integration")
                                    .font(.brandBodyBold)
                                    .foregroundColor(store.palette.textPrimary)
                                Text("Connect and synchronize with GitLab accounts.")
                                    .font(.brandCaption)
                                    .foregroundColor(store.palette.textMuted)
                            }
                        }
                        .toggleStyle(.switch)
                        
                        Divider().background(store.palette.border.opacity(0.3))
                        
                        Toggle(isOn: Binding(
                            get: { FeatureFlags.shared.npmMarketplaceEnabled },
                            set: { FeatureFlags.shared.npmMarketplaceEnabled = $0; store.objectWillChange.send() }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("NPM Skills Marketplace")
                                    .font(.brandBodyBold)
                                    .foregroundColor(store.palette.textPrimary)
                                Text("Explore and install skills directly from the NPM package ecosystem.")
                                    .font(.brandCaption)
                                    .foregroundColor(store.palette.textMuted)
                            }
                        }
                        .toggleStyle(.switch)
                        
                        Divider().background(store.palette.border.opacity(0.3))
                        
                        Toggle(isOn: Binding(
                            get: { FeatureFlags.shared.mcpSyncEnabled },
                            set: { FeatureFlags.shared.mcpSyncEnabled = $0; store.objectWillChange.send() }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("MCP Server Synchronization")
                                    .font(.brandBodyBold)
                                    .foregroundColor(store.palette.textPrimary)
                                Text("Automatically inject central MCP servers into client desktop configurations.")
                                    .font(.brandCaption)
                                    .foregroundColor(store.palette.textMuted)
                            }
                        }
                        .toggleStyle(.switch)
                        
                        Divider().background(store.palette.border.opacity(0.3))
                        
                        Toggle(isOn: Binding(
                            get: { FeatureFlags.shared.commitSigningEnabled },
                            set: { FeatureFlags.shared.commitSigningEnabled = $0; store.objectWillChange.send() }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Cryptographic Commit Signing")
                                    .font(.brandBodyBold)
                                    .foregroundColor(store.palette.textPrimary)
                                Text("Sign all Git commits using Citadel's Keychain Ed25519 identity.")
                                    .font(.brandCaption)
                                    .foregroundColor(store.palette.textMuted)
                            }
                        }
                        .toggleStyle(.switch)
                        
                        Divider().background(store.palette.border.opacity(0.3))
                        
                        Toggle(isOn: Binding(
                            get: { FeatureFlags.shared.workspacePortalsEnabled },
                            set: { FeatureFlags.shared.workspacePortalsEnabled = $0; store.objectWillChange.send() }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("In-Project Workspace Portals")
                                    .font(.brandBodyBold)
                                    .foregroundColor(store.palette.textPrimary)
                                Text("Inject skills into local .gemini and .claude project folders.")
                                    .font(.brandCaption)
                                    .foregroundColor(store.palette.textMuted)
                            }
                        }
                        .toggleStyle(.switch)
                        
                        Divider().background(store.palette.border.opacity(0.3))
                        
                        Toggle(isOn: Binding(
                            get: { FeatureFlags.shared.includeBuiltinInDiscoveryEnabled },
                            set: { FeatureFlags.shared.includeBuiltinInDiscoveryEnabled = $0; store.objectWillChange.send() }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Include Builtin Skills in Discovery")
                                    .font(.brandBodyBold)
                                    .foregroundColor(store.palette.textPrimary)
                                Text("Include builtin vendor skills during filesystem discovery scans.")
                                    .font(.brandCaption)
                                    .foregroundColor(store.palette.textMuted)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                }
                .padding(BrandSpacing.md)
                .liquidGlass(cornerRadius: BrandCornerRadius.lg)
                #endif
                
                // 5. Emergency Rollback & Decouple (Danger Zone)
                VStack(alignment: .leading, spacing: BrandSpacing.md) {
                    HStack(spacing: BrandSpacing.xs) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .foregroundColor(Color.orange)
                        Text("Rollback & Materialization (Decouple from Citadel)")
                            .font(.brandHeadline)
                            .foregroundColor(store.palette.textPrimary)
                    }
                    
                    Text("If you ever decide to remove or uninstall Citadel, this operation converts all symlinks across .gemini, .claude, .android-studio, .copilot, and .junie into standalone independent copies so your tools never lose their skills.")
                        .font(.brandCaption)
                        .foregroundColor(store.palette.textSecondary)
                        .lineSpacing(2)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Materialize All Symlinks")
                                .font(.brandBodyBold)
                                .foregroundColor(store.palette.textPrimary)
                            Text("Replaces symlinks with real directories across all client apps.")
                                .font(.brandCaption)
                                .foregroundColor(store.palette.textMuted)
                        }
                        Spacer()
                        Button(action: {
                            store.runRollbackEject()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc.fill")
                                Text(store.rollbackNotice.isEmpty ? "EJECT & MATERIALIZE" : store.rollbackNotice)
                            }
                            .font(.brandMonoBadge)
                            .foregroundColor(Color.orange)
                            .padding(.horizontal, BrandSpacing.sm)
                            .padding(.vertical, BrandSpacing.xxs + 2)
                            .liquidGlassPill(tint: Color.orange)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Divider().background(store.palette.border.opacity(0.3))
                    
                    HStack(spacing: BrandSpacing.xs) {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 11))
                            .foregroundColor(store.palette.textMuted)
                        Text("Standalone recovery script kept updated at ~/.citadel/rollback.sh")
                            .font(.brandMonoMicro)
                            .foregroundColor(store.palette.textMuted)
                    }
                }
                .padding(BrandSpacing.md)
                .liquidGlass(cornerRadius: BrandCornerRadius.lg)
            }
            .padding(BrandSpacing.lg)
        }
        .sheet(isPresented: $store.showAuthModal) {
            OAuthModalSheet(store: store)
        }
        .sheet(isPresented: $store.showCreateRepoDialog) {
            let prov = store.githubUser != nil ? GitProvider.github : GitProvider.gitlab
            let username = (store.githubUser?.username ?? store.gitlabUser?.username) ?? "user"
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "shield.lefthalf.filled.trianglebadge.exclamationmark")
                        .foregroundColor(Color.yellow)
                    Text("Permission Request: Create Repository")
                        .font(.system(size: 15, weight: .bold))
                }
                
                Text("Citadel proposes to create a private repository on your \(prov.rawValue) account:")
                    .font(.system(size: 12))
                    .foregroundColor(store.palette.textSecondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Repository: @\(username)/citadel-sync")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                    Text("Visibility: Private")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(store.palette.accent)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(store.palette.card)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(store.palette.border, lineWidth: 1))
                
                HStack {
                    Spacer()
                    Button("Cancel") { store.showCreateRepoDialog = false }
                        .keyboardShortcut(.cancelAction)
                    
                    Button("Approve & Create Private Repo") {
                        store.createPrivateStoreWithPermission(provider: prov)
                        store.showCreateRepoDialog = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(store.palette.accent)
                }
            }
            .padding(24)
            .frame(width: 480)
            .background(store.palette.card)
        }
        .onAppear {
            store.refreshRemoteStatus()
        }
    }
}

// MARK: - Discovery Chamber

struct DiscoveryChamber: View {
    @ObservedObject var store: CitadelStore
    
    private func sanitizeSearchPath(_ fullPath: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if fullPath.hasPrefix(home) {
            let relative = String(fullPath.dropFirst(home.count))
            return relative.hasPrefix("/") ? String(relative.dropFirst()) : relative
        }
        return fullPath
    }
    
    private var filteredSkillGroups: [SkillGroup] {
        let q = store.discoverySearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return store.skillGroups }
        return store.skillGroups.filter { group in
            if group.name.lowercased().contains(q) { return true }
            return group.occurrences.contains { occ in
                let relative = sanitizeSearchPath(occ.path.path).lowercased()
                return relative.contains(q)
            }
        }
    }
    
    private var filteredDiscoveredMCPs: [DiscoveredMCP] {
        let q = store.discoverySearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return store.discoveredMCPs }
        return store.discoveredMCPs.filter { mcp in
            if mcp.name.lowercased().contains(q) ||
               mcp.clientName.lowercased().contains(q) ||
               mcp.command.lowercased().contains(q) ||
               mcp.args.joined(separator: " ").lowercased().contains(q) {
                return true
            }
            let relative = sanitizeSearchPath(mcp.foundInPath.path).lowercased()
            return relative.contains(q)
        }
    }
    
    private var filteredDiscoveredWorkspaces: [DiscoveredWorkspace] {
        let q = store.discoverySearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return store.discoveredWorkspaces }
        return store.discoveredWorkspaces.filter { ws in
            if ws.name.lowercased().contains(q) { return true }
            let relative = sanitizeSearchPath(ws.path.path).lowercased()
            return relative.contains(q)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: BrandSpacing.sm) {
                Picker("", selection: $store.discoveryTab) {
                    Text("Skills (\(store.discoveredSkills.count))").tag("skills")
                    Text("MCPs (\(store.discoveredMCPs.count))").tag("mcps")
                    Text("Workspaces (\(store.discoveredWorkspaces.count))").tag("workspaces")
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
                
                // Search Bar
                HStack(spacing: BrandSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(store.palette.textMuted)
                        .font(.system(size: 11))
                    TextField("Filter discovered...", text: $store.discoverySearchText)
                        .textFieldStyle(.plain)
                        .font(.brandMono)
                        .foregroundColor(store.palette.textPrimary)
                    if !store.discoverySearchText.isEmpty {
                        Button(action: { store.discoverySearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(store.palette.textMuted)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, BrandSpacing.sm)
                .padding(.vertical, BrandSpacing.xs)
                .liquidGlassPill()
                .frame(maxWidth: 280)
                
                Spacer()
                
                // Toggle preview inspector button (when skills tab is selected)
                if store.discoveryTab == "skills" {
                    Button(action: {
                        withAnimation(BrandMotion.fastSpring) {
                            store.showDiscoverySkillPreview.toggle()
                        }
                    }) {
                        Image(systemName: store.showDiscoverySkillPreview ? "sidebar.right" : "sidebar.squares.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(store.showDiscoverySkillPreview ? store.palette.accent : store.palette.textMuted)
                            .frame(width: 30, height: 30)
                            .liquidGlassPill(tint: store.showDiscoverySkillPreview ? store.palette.accent : nil)
                    }
                    .buttonStyle(.plain)
                    .help(store.showDiscoverySkillPreview ? "Hide skill details pane" : "Show skill details pane")
                }
                
                Button(action: { store.scanFilesystem() }) {
                    HStack(spacing: BrandSpacing.xs) {
                        Image(systemName: "sparkle.magnifyingglass")
                        Text(store.isScanning ? "SCANNING..." : "SCAN SYSTEM")
                            .font(.brandMonoBadge)
                    }
                    .foregroundColor(store.palette.textPrimary)
                    .padding(.horizontal, BrandSpacing.md)
                    .padding(.vertical, BrandSpacing.xs)
                    .liquidGlassPill(tint: store.palette.accent)
                }
                .buttonStyle(.plain)
                .disabled(store.isScanning)
            }
            .padding(BrandSpacing.md)
            
            Divider().background(store.palette.border.opacity(0.3))
            
            HSplitView {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if store.discoveryTab == "skills" {
                            ForEach(filteredSkillGroups) { group in
                                VStack(alignment: .leading, spacing: BrandSpacing.xs) {
                                    HStack {
                                        Text(group.name)
                                            .font(.brandHeadline)
                                            .foregroundColor(store.palette.textPrimary)
                                        
                                        if group.occurrences.count > 1 {
                                            Text("\(group.occurrences.count) LOCATIONS")
                                                .font(.brandMonoBadge)
                                                .foregroundColor(store.palette.accent)
                                                .padding(.horizontal, BrandSpacing.xs)
                                                .padding(.vertical, BrandSpacing.xxs - 1)
                                                .background(store.palette.accentMuted)
                                                .clipShape(BrandShapes.pill)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            withAnimation(BrandMotion.fastSpring) {
                                                store.selectDiscoverySkillGroup(group)
                                                store.showDiscoverySkillPreview = true
                                            }
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "doc.text.magnifyingglass")
                                                Text("VIEW SKILL")
                                            }
                                            .font(.brandMonoBadge)
                                            .foregroundColor(store.selectedDiscoverySkill?.name == group.name ? store.palette.accent : store.palette.textSecondary)
                                            .padding(.horizontal, BrandSpacing.sm)
                                            .padding(.vertical, BrandSpacing.xs - 2)
                                            .liquidGlassPill(tint: store.selectedDiscoverySkill?.name == group.name ? store.palette.accent : nil)
                                        }
                                        .buttonStyle(.plain)
                                        .help("View skill instructions, author, and documentation")
                                        
                                        if !group.isFullyUnified {
                                            Button("UNIFY GROUP") {
                                                store.itemPendingApproval = "Unify '\(group.name)' across \(group.occurrences.count) locations into ~/.citadel/skills/\(group.name)"
                                                store.approvalAction = { store.unifySkillGroup(group) }
                                                store.showApprovalSheet = true
                                            }
                                            .font(.brandMonoBadge)
                                            .foregroundColor(store.palette.background)
                                            .padding(.horizontal, BrandSpacing.sm)
                                            .padding(.vertical, BrandSpacing.xs - 2)
                                            .background(store.palette.accent)
                                            .clipShape(BrandShapes.pill)
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    
                                    ForEach(group.occurrences) { occ in
                                        HStack(spacing: BrandSpacing.xs) {
                                            Circle()
                                                .fill(occ.isSymlink ? store.palette.accent : Color.orange)
                                                .frame(width: 5, height: 5)
                                            Text(occ.path.path)
                                                .font(.brandMono)
                                                .foregroundColor(store.palette.textMuted)
                                            Spacer()
                                            Text(occ.isSymlink ? "symlink" : "real copy")
                                                .font(.brandMonoMicro)
                                                .foregroundColor(occ.isSymlink ? store.palette.accent : store.palette.textSecondary)
                                        }
                                    }
                                }
                                .padding(BrandSpacing.md)
                                .background {
                                    if store.selectedDiscoverySkill?.name == group.name {
                                        store.palette.accentMuted
                                    } else {
                                        store.palette.background
                                    }
                                }
                                
                                Divider().background(store.palette.border)
                            }
                        } else if store.discoveryTab == "mcps" {
                            ForEach(filteredDiscoveredMCPs) { mcp in
                                HStack {
                                    VStack(alignment: .leading, spacing: BrandSpacing.xxs) {
                                        HStack(spacing: BrandSpacing.xs) {
                                            Text(mcp.name)
                                                .font(.brandHeadline)
                                                .foregroundColor(store.palette.textPrimary)
                                            Text(mcp.clientName.uppercased())
                                                .font(.brandMonoBadge)
                                                .foregroundColor(store.palette.accent)
                                                .padding(.horizontal, BrandSpacing.xs)
                                                .padding(.vertical, BrandSpacing.xxs - 1)
                                                .background(store.palette.accentMuted)
                                                .clipShape(BrandShapes.pill)
                                        }
                                        Text("\(mcp.command) \(mcp.args.joined(separator: " "))")
                                            .font(.brandMono)
                                            .foregroundColor(store.palette.textMuted)
                                    }
                                    Spacer()
                                    Button("IMPORT CONFIG") {
                                        store.itemPendingApproval = "MCP Server: \(mcp.name) [from \(mcp.clientName)]"
                                        store.approvalAction = {
                                            try? MultiverseDiscoveryEngine.shared.ingestMCP(mcp)
                                            store.refresh()
                                        }
                                        store.showApprovalSheet = true
                                    }
                                    .font(.brandMonoBadge)
                                    .foregroundColor(store.palette.background)
                                    .padding(.horizontal, BrandSpacing.sm)
                                    .padding(.vertical, BrandSpacing.xs - 2)
                                    .background(store.palette.accent)
                                    .clipShape(BrandShapes.pill)
                                    .buttonStyle(.plain)
                                }
                                .padding(BrandSpacing.md)
                                .background(store.palette.background)
                                
                                Divider().background(store.palette.border)
                            }
                        } else {
                            ForEach(filteredDiscoveredWorkspaces) { ws in
                                HStack {
                                    VStack(alignment: .leading, spacing: BrandSpacing.xxs) {
                                        HStack(spacing: BrandSpacing.xs) {
                                            Text(ws.name)
                                                .font(.brandHeadline)
                                                .foregroundColor(store.palette.textPrimary)
                                            if ws.isAlreadyPortal {
                                                Text("CONNECTED")
                                                    .font(.brandMonoBadge)
                                                    .foregroundColor(store.palette.accent)
                                                    .padding(.horizontal, BrandSpacing.xs)
                                                    .padding(.vertical, BrandSpacing.xxs - 1)
                                                    .background(store.palette.accentMuted)
                                                    .clipShape(BrandShapes.pill)
                                            }
                                        }
                                        Text(ws.path.path)
                                            .font(.brandMono)
                                            .foregroundColor(store.palette.textMuted)
                                    }
                                    Spacer()
                                    if !ws.isAlreadyPortal {
                                        Button("CONNECT PORTAL") {
                                            store.itemPendingApproval = "Workspace Portal: \(ws.name) (\(ws.path.path))"
                                            store.approvalAction = {
                                                try? MultiverseDiscoveryEngine.shared.connectWorkspaceAsPortal(ws)
                                                store.syncAll()
                                            }
                                            store.showApprovalSheet = true
                                        }
                                        .font(.brandMonoBadge)
                                        .foregroundColor(store.palette.background)
                                        .padding(.horizontal, BrandSpacing.sm)
                                        .padding(.vertical, BrandSpacing.xs - 2)
                                        .background(store.palette.accent)
                                        .clipShape(BrandShapes.pill)
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(BrandSpacing.md)
                                .background(store.palette.background)
                                
                                Divider().background(store.palette.border)
                            }
                        }
                    }
                }
                .frame(minWidth: 320, idealWidth: 420, maxWidth: (store.discoveryTab == "skills" && store.showDiscoverySkillPreview && store.selectedDiscoverySkill != nil) ? 520 : .infinity)
                
                // Shared Skill Detail / Inspection View
                if store.discoveryTab == "skills" && store.showDiscoverySkillPreview {
                    Group {
                        if let skill = store.selectedDiscoverySkill {
                            SkillDetailView(
                                skill: skill,
                                content: store.discoverySkillContent,
                                palette: store.palette,
                                onClose: {
                                    withAnimation(BrandMotion.fastSpring) {
                                        store.showDiscoverySkillPreview = false
                                    }
                                }
                            )
                        } else {
                            VStack(spacing: BrandSpacing.xs) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 28))
                                    .foregroundColor(store.palette.textMuted.opacity(0.6))
                                Text("Select \"VIEW SKILL\" on any discovered skill")
                                    .font(.brandSubheadline)
                                    .foregroundColor(store.palette.textMuted)
                                Text("Inspect what the skill does, who authored it, and its complete instructions.")
                                    .font(.brandCaption)
                                    .foregroundColor(store.palette.textMuted.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, BrandSpacing.lg)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(minWidth: 380)
                }
            }
        }
        .sheet(isPresented: $store.showApprovalSheet) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color.yellow)
                    Text("User Permission Request")
                        .font(.system(size: 15, weight: .bold))
                }
                
                Text("Citadel proposes to import the following configuration into your central store (~/.citadel):")
                    .font(.system(size: 12))
                    .foregroundColor(store.palette.textSecondary)
                
                if let item = store.itemPendingApproval {
                    Text(item)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(10)
                        .background(store.palette.card)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(store.palette.border, lineWidth: 1))
                }
                
                Text("What will happen: The configuration will be stored canonically in ~/.citadel. A symbolic link will replace the original path so all AI assistants share the exact same files.")
                    .font(.system(size: 11))
                    .foregroundColor(store.palette.textMuted)
                
                HStack {
                    Spacer()
                    Button("Cancel") { store.showApprovalSheet = false }
                        .keyboardShortcut(.cancelAction)
                    
                    Button("Grant Permission & Ingest") {
                        store.approvalAction?()
                        store.showApprovalSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(store.palette.accent)
                }
            }
            .padding(24)
            .frame(width: 480)
            .background(store.palette.card)
        }
        .onAppear {
            if store.discoveredSkills.isEmpty { store.scanFilesystem() }
        }
    }
}

// MARK: - Marketplace Chamber

struct MarketplaceChamber: View {
    @ObservedObject var store: CitadelStore
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: BrandSpacing.xs) {
                Image(systemName: "shippingbox.fill")
                    .foregroundColor(store.palette.textMuted)
                TextField("Search npm for 'citadel-skill' packages...", text: $store.marketQuery)
                    .textFieldStyle(.plain)
                    .font(.brandMono)
                    .foregroundColor(store.palette.textPrimary)
                    .onSubmit { store.searchMarketplace() }
                
                Button(action: { store.searchMarketplace() }) {
                    Text("SEARCH NPM")
                        .font(.brandMonoBadge)
                        .foregroundColor(store.palette.textPrimary)
                        .padding(.horizontal, BrandSpacing.sm)
                        .padding(.vertical, BrandSpacing.xs)
                        .background(store.palette.card)
                        .clipShape(BrandShapes.pill)
                        .overlay(BrandShapes.pill.stroke(store.palette.borderStrong, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(BrandSpacing.md)
            .background(store.palette.card.opacity(0.35))
            
            Divider().background(store.palette.border)
            
            if store.marketPackages.isEmpty && !store.isSearchingMarket {
                VStack(spacing: BrandSpacing.xs) {
                    Text("NPM DECENTRALIZED SKILL REGISTRY")
                        .font(.brandHeadline)
                        .foregroundColor(store.palette.textSecondary)
                    Text("Type a keyword above to discover community skills published on npm.")
                        .font(.brandCaption)
                        .foregroundColor(store.palette.textMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(store.palette.background)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.marketPackages) { pkg in
                            HStack {
                                VStack(alignment: .leading, spacing: BrandSpacing.xxs) {
                                    HStack(spacing: BrandSpacing.xs) {
                                        Text(pkg.name)
                                            .font(.brandHeadline)
                                            .foregroundColor(store.palette.textPrimary)
                                        Text("v" + pkg.version)
                                            .font(.brandMonoBadge)
                                            .foregroundColor(store.palette.accent)
                                            .padding(.horizontal, BrandSpacing.xs)
                                            .padding(.vertical, BrandSpacing.xxs - 2)
                                            .background(store.palette.accentMuted)
                                            .clipShape(BrandShapes.pill)
                                    }
                                    if let desc = pkg.description {
                                        Text(desc)
                                            .font(.brandCaption)
                                            .foregroundColor(store.palette.textSecondary)
                                    }
                                }
                                Spacer()
                                Button(action: { store.installMarketplacePackage(pkg) }) {
                                    Text(store.installingPackage == pkg.name ? "INSTALLING..." : "INSTALL")
                                        .font(.brandMonoBadge)
                                        .foregroundColor(store.palette.background)
                                        .padding(.horizontal, BrandSpacing.sm)
                                        .padding(.vertical, BrandSpacing.xs - 2)
                                        .background(store.palette.accent)
                                        .clipShape(BrandShapes.pill)
                                }
                                .buttonStyle(.plain)
                                .disabled(store.installingPackage != nil)
                            }
                            .padding(BrandSpacing.md)
                            .background(store.palette.background)
                            
                            Divider().background(store.palette.border)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Workspaces Chamber

struct WorkspacesChamber: View {
    @ObservedObject var store: CitadelStore
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: BrandSpacing.xxs) {
                    Text("IN-PROJECT PORTALS")
                        .font(.brandHeadline)
                        .foregroundColor(store.palette.textPrimary)
                    Text("Projects with active .gemini/skills and .claude/skills symlink injection.")
                        .font(.brandCaption)
                        .foregroundColor(store.palette.textSecondary)
                }
                Spacer()
                Button(action: { store.addProjectPortal() }) {
                    HStack(spacing: BrandSpacing.xs) {
                        Image(systemName: "plus")
                        Text("CONNECT REPO")
                            .font(.brandMonoBadge)
                    }
                    .foregroundColor(store.palette.textPrimary)
                    .padding(.horizontal, BrandSpacing.md)
                    .padding(.vertical, BrandSpacing.xs)
                    .liquidGlassPill(tint: store.palette.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(BrandSpacing.md)
            
            Divider().background(store.palette.border.opacity(0.3))
            
            if store.portals.isEmpty {
                VStack(spacing: BrandSpacing.xs) {
                    Text("NO ACTIVE PROJECT PORTALS")
                        .font(.brandHeadline)
                        .foregroundColor(store.palette.textSecondary)
                    Text("Click 'CONNECT REPO' or run 'ctdl portal .' inside any project directory.")
                        .font(.brandCaption)
                        .foregroundColor(store.palette.textMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(store.palette.background)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.portals) { portal in
                            VStack(alignment: .leading, spacing: BrandSpacing.xs) {
                                HStack {
                                    Text(portal.projectPath.lastPathComponent)
                                        .font(.brandHeadline)
                                        .foregroundColor(store.palette.textPrimary)
                                    Spacer()
                                    Text("PORTAL ACTIVE")
                                        .font(.brandMonoBadge)
                                        .foregroundColor(store.palette.accent)
                                        .padding(.horizontal, BrandSpacing.xs)
                                        .padding(.vertical, BrandSpacing.xxs - 1)
                                        .background(store.palette.accentMuted)
                                        .clipShape(BrandShapes.pill)
                                }
                                Text(portal.projectPath.path)
                                    .font(.brandMonoMicro)
                                    .foregroundColor(store.palette.textMuted)
                                
                                HStack(spacing: BrandSpacing.sm) {
                                    Text("\(portal.enabledSkills.count) SKILLS INJECTED")
                                        .font(.brandMonoBadge)
                                        .foregroundColor(store.palette.accent)
                                    Text("•").foregroundColor(store.palette.textMuted)
                                    Text(".gemini & .claude linked")
                                        .font(.brandCaption)
                                        .foregroundColor(store.palette.textSecondary)
                                }
                            }
                            .padding(BrandSpacing.md)
                            .background(store.palette.background)
                            
                            Divider().background(store.palette.border)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Status Deck

struct StatusDeck: View {
    @ObservedObject var store: CitadelStore
    
    var body: some View {
        HStack {
            Text(store.syncNotice)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(store.palette.textSecondary)
            Spacer()
            Text("Last synced: \(store.lastSyncTime)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(store.palette.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(store.palette.background.opacity(0.8))
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    var statusItem: NSStatusItem?
    let store = CitadelStore()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        
        // Set application Dock icon dynamically (for both app bundle and raw binary execution)
        if let iconImage = NSImage(contentsOfFile: "branding/production/citadel-logo-app-icon-512.png") ?? NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = iconImage
        }
        
        setupWindow()
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "shield.checkered", accessibilityDescription: "Citadel")
        }
        
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open Citadel Window", action: #selector(showWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)
        
        let syncItem = NSMenuItem(title: "Sync Multiverse Now", action: #selector(syncNow), keyEquivalent: "s")
        syncItem.target = self
        menu.addItem(syncItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Citadel", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        item.menu = menu
        self.statusItem = item
    }
    
    private func setupWindow() {
        let win = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1120, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = "Citadel"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.isReleasedWhenClosed = false
        win.center()
        
        let hostingView = NSHostingView(rootView: CitadelRootView(store: store))
        win.contentView = hostingView
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func syncNow() {
        store.syncAll()
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
