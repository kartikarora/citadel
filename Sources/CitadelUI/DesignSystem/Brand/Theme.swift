import SwiftUI

/**
 * @kartikarora Brand Theme System (v2.0.0).
 * Provides view modifiers and environment configuration for:
 * 1. Adaptive Brand Theme (.brandTheme()) - Responsive light/dark mode
 * 2. Signature Studio Theme (.brandStudioTheme()) - Option 03 pitch-black experience
 */

public struct BrandThemeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public func body(content: Content) -> some View {
        content
            .background(Color.brand.canvas.ignoresSafeArea())
            .foregroundColor(Color.brand.ink)
            .tint(Color.brand.signal)
    }
}

public struct BrandStudioDarkModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .preferredColorScheme(.dark)
            .background(Color(hex: "0xFF000000").ignoresSafeArea())
            .foregroundColor(Color(hex: "0xFFF0F4F8"))
            .tint(Color(hex: "0xFF818CF8"))
    }
}

public extension View {
    /// Applies the adaptive @kartikarora brand theme (light/dark responsive).
    func brandTheme() -> some View {
        modifier(BrandThemeModifier())
    }

    /// Locks the view into the signature Option 03 pitch-black Studio theme.
    func brandStudioTheme() -> some View {
        modifier(BrandStudioDarkModifier())
    }
}

// MARK: - Motion Specs

public enum BrandMotion {
    /// Fast tactile spring animation for buttons and interactive controls (0.22s response)
    public static let fastSpring = Animation.spring(response: 0.22, dampingFraction: 0.8)

    /// Smooth ease-out for sheet presentations and modal reveals
    public static let easeOut = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.28)
}

// MARK: - Liquid Glass Surface & Material System

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
                    // 1. Refractive Apple Material Layer
                    shape
                        .fill(blurMaterial)

                    // 2. Translucent Ambient Wash (Optional tint or signal wash)
                    if let tint = tint {
                        shape
                            .fill(tint.opacity(isDark ? 0.12 : 0.06))
                    } else {
                        shape
                            .fill(Color.brand.signalWash.opacity(isDark ? 0.35 : 0.15))
                    }

                    // 3. Specular Edge Highlight (Brighter at top-left, subtler at bottom-right)
                    shape
                        .strokeBorder(
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
                    capsule
                        .fill(.ultraThinMaterial)

                    if let tint = tint {
                        capsule
                            .fill(tint.opacity(isDark ? 0.14 : 0.08))
                    } else {
                        capsule
                            .fill(Color.brand.signalWash.opacity(isDark ? 0.3 : 0.12))
                    }

                    capsule
                        .strokeBorder(
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
    /// Applies an Apple-grade Liquid Glass surface with ultra-thin material refraction, specular border, and ambient depth.
    func liquidGlass(
        cornerRadius: CGFloat = BrandCornerRadius.lg,
        tint: Color? = nil,
        material: Material = .ultraThinMaterial
    ) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius, tint: tint, material: material))
    }

    /// Applies Liquid Glass styling formatted to a full-round pill or capsule.
    func liquidGlassPill(tint: Color? = nil) -> some View {
        modifier(LiquidGlassPillModifier(tint: tint))
    }
}
