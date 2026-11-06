import SwiftUI
import AppKit

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
                        capsule.fill(tint.opacity(isDark ? 0.18 : 0.10))
                    } else {
                        capsule.fill(Color.brand.signalWash.opacity(isDark ? 0.40 : 0.20))
                    }
                    capsule.strokeBorder(
                        LinearGradient(
                            colors: isDark
                                ? [Color.white.opacity(0.30), Color.white.opacity(0.08), Color.white.opacity(0.02)]
                                : [Color.white.opacity(0.95), Color.black.opacity(0.10), Color.black.opacity(0.04)],
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

public struct NativeBlurBackground: NSViewRepresentable {
    public var material: NSVisualEffectView.Material = .sidebar
    public var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    
    public init(material: NSVisualEffectView.Material = .sidebar, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
