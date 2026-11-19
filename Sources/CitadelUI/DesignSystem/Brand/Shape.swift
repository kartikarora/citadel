import SwiftUI

/**
 * @kartikarora Brand Shapes & Corner Radii (v2.0.0).
 * AUTO-GENERATED from tokens/design-tokens.json. DO NOT EDIT DIRECTLY.
 * Run 'node scripts/generate-tokens.js' to re-generate.
 */
public struct BrandCornerRadius {
    /// 6pt --radius-sm (Badges, tags, inputs)
    public static let sm: CGFloat = 6.0
    /// 12pt --radius-md (Standard cards, code blocks)
    public static let md: CGFloat = 12.0
    /// 16pt --radius-lg (Modal sheets, large cards)
    public static let lg: CGFloat = 16.0
    /// 9999pt --radius-pill (Buttons, tabs, and pills)
    public static let pill: CGFloat = 9999.0
}

public struct BrandShapes {
    public static let small = RoundedRectangle(cornerRadius: BrandCornerRadius.sm, style: .continuous)
    public static let medium = RoundedRectangle(cornerRadius: BrandCornerRadius.md, style: .continuous)
    public static let large = RoundedRectangle(cornerRadius: BrandCornerRadius.lg, style: .continuous)
    public static let pill = Capsule()
}
