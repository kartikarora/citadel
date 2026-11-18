import SwiftUI
import AppKit

public struct LiquidGlassModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    public let cornerRadius: CGFloat
    public let tint: Color?
    public let blurMaterial: Material

    public init(
        cornerRadius: CGFloat = BrandCornerRadius.md,
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
        let strokeColor = tint ?? (isDark ? Color(red: 51/255, green: 65/255, blue: 85/255) : Color(red: 31/255, green: 36/255, blue: 44/255))
        let shadowColor = isDark ? Color(red: 0, green: 0, blue: 0, opacity: 0.8) : Color(red: 31/255, green: 36/255, blue: 44/255, opacity: 0.35)

        content
            .background {
                ZStack {
                    shape.fill(blurMaterial)
                    if let tint = tint {
                        shape.fill(tint.opacity(isDark ? 0.15 : 0.08))
                    } else {
                        shape.fill(isDark ? Color(red: 18/255, green: 24/255, blue: 36/255).opacity(0.85) : Color(red: 244/255, green: 246/255, blue: 250/255).opacity(0.85))
                    }
                    shape.strokeBorder(strokeColor, lineWidth: 2)
                }
            }
            .clipShape(shape)
            .shadow(
                color: shadowColor,
                radius: 0,
                x: 4,
                y: 4
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
        let strokeColor = tint ?? (isDark ? Color(red: 51/255, green: 65/255, blue: 85/255) : Color(red: 31/255, green: 36/255, blue: 44/255))
        let shadowColor = tint != nil
            ? (tint == Color(red: 255/255, green: 230/255, blue: 0/255) || tint == Color(red: 230/255, green: 184/255, blue: 0/255) ? Color(red: 255/255, green: 230/255, blue: 0/255, opacity: 0.6) : strokeColor.opacity(0.4))
            : (isDark ? Color.black.opacity(0.7) : Color(red: 31/255, green: 36/255, blue: 44/255, opacity: 0.25))

        content
            .background {
                ZStack {
                    capsule.fill(.ultraThinMaterial)
                    if let tint = tint {
                        capsule.fill(tint.opacity(isDark ? 0.20 : 0.12))
                    } else {
                        capsule.fill(isDark ? Color(red: 18/255, green: 24/255, blue: 36/255).opacity(0.75) : Color(red: 244/255, green: 246/255, blue: 250/255).opacity(0.75))
                    }
                    capsule.strokeBorder(strokeColor, lineWidth: 2)
                }
            }
            .clipShape(capsule)
            .shadow(
                color: shadowColor,
                radius: 0,
                x: 3,
                y: 3
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
