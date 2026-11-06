import SwiftUI

public struct CitadelBrandLogoView: View {
    public var size: CGFloat = 20
    public var tint: Color? = nil
    
    public init(size: CGFloat = 20, tint: Color? = nil) {
        self.size = size
        self.tint = tint
    }
    
    public var body: some View {
        ZStack {
            // Dual layered fortress shield
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
                context.fill(outerShield, with: .color(Color(hex: "#0f172a")))
                
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
                context.fill(innerPlate, with: .color(Color(hex: "#1e1b4b")))
                
                // Neural Synapse Network Conduits
                let accentColor = tint ?? Color(hex: "#818cf8")
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
                    context.fill(Path(ellipseIn: CGRect(x: pt.x - 7 * scale, y: pt.y - 7 * scale, width: 14 * scale, height: 14 * scale)), with: .color(Color(hex: "#6366f1")))
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
