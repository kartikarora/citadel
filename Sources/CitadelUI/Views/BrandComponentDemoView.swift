import SwiftUI

/// Pure @kartikarora v2.0.0 Brand Component Demo (no customisation).
public struct BrandComponentDemoView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrandSpacing.lg) {
                // Typography & BrandStatement
                VStack(alignment: .leading, spacing: BrandSpacing.sm) {
                    Text("@kartikarora v2.0.0")
                        .font(.brandMonoBadge)
                        .foregroundColor(Color.brand.signal)

                    Text("SwiftUI Component System")
                        .font(.brandDisplay)
                        .foregroundColor(Color.brand.ink)

                    BrandStatement(
                        quote: "High-contrast typography, 8pt spacing, and tactile liquid glass surfaces."
                    )
                }

                Divider().background(Color.brand.rule)

                // BrandButton variants
                VStack(alignment: .leading, spacing: BrandSpacing.sm) {
                    Text("BrandButton")
                        .font(.brandHeadline)
                        .foregroundColor(Color.brand.ink)

                    HStack(spacing: BrandSpacing.sm) {
                        BrandButton("Primary", style: .primary) {}
                        BrandButton("Outline", style: .outline) {}
                        BrandButton("Ghost", style: .ghost) {}
                        BrandButton("Small", style: .small) {}
                    }
                }

                Divider().background(Color.brand.rule)

                // StatusBadge variants
                VStack(alignment: .leading, spacing: BrandSpacing.sm) {
                    Text("StatusBadge")
                        .font(.brandHeadline)
                        .foregroundColor(Color.brand.ink)

                    HStack(spacing: BrandSpacing.sm) {
                        StatusBadge("Verified", variant: .win)
                        StatusBadge("Blocked", variant: .loss)
                        StatusBadge("Draft", variant: .draft)
                        StatusBadge("GDE Android", variant: .gde)
                    }
                }

                Divider().background(Color.brand.rule)

                // CLICommandPill
                VStack(alignment: .leading, spacing: BrandSpacing.sm) {
                    Text("CLICommandPill")
                        .font(.brandHeadline)
                        .foregroundColor(Color.brand.ink)

                    CLICommandPill(command: "npx skills install https://distribute.kartikarora.me/ai/kartikarora-swiftui.skill")
                    CLICommandPill(command: "brew install --cask --no-quarantine citadel")
                }

                Divider().background(Color.brand.rule)

                // Tokyo Neo-Brutalist Card
                VStack(alignment: .leading, spacing: BrandSpacing.sm) {
                    Text("Tokyo Card")
                        .font(.brandHeadline)
                        .foregroundColor(Color.brand.ink)

                    VStack(alignment: .leading, spacing: BrandSpacing.xs) {
                        Text("Canonical Store")
                            .font(.brandHeadline)
                            .foregroundColor(Color.brand.ink)
                        Text("Solid surface with 2px ruleStrong border and 4px hard offset shadow.")
                            .font(.brandBody)
                            .foregroundColor(Color.brand.inkMuted)
                    }
                    .padding(BrandSpacing.md)
                    .background(Color.brand.card)
                    .clipShape(RoundedRectangle(cornerRadius: BrandCornerRadius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BrandCornerRadius.sm, style: .continuous)
                            .stroke(Color.brand.ruleStrong, lineWidth: 2)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: BrandCornerRadius.sm, style: .continuous)
                            .fill(Color.brand.ruleStrong)
                            .offset(x: 4, y: 4)
                    )
                }

                Divider().background(Color.brand.rule)

                // ArtifactRow
                VStack(alignment: .leading, spacing: BrandSpacing.sm) {
                    Text("ArtifactRow")
                        .font(.brandHeadline)
                        .foregroundColor(Color.brand.ink)

                    ArtifactRow(
                        tag: "Tooling / 2026",
                        badge: "Swift 6",
                        title: "Citadel",
                        summary: "Canonical skill and MCP store with isolated GitHub sync.",
                        cliCommand: "ctdl sync",
                        actionTitle: "Inspect",
                        action: {}
                    )
                }

                Divider().background(Color.brand.rule)

                // StanceView
                VStack(alignment: .leading, spacing: BrandSpacing.sm) {
                    Text("StanceView")
                        .font(.brandHeadline)
                        .foregroundColor(Color.brand.ink)

                    StanceView(
                        title: "Brand Fidelity",
                        bodyText: "All views use Color.brand, Font.brand*, BrandSpacing, and BrandCornerRadius."
                    )
                }

                Divider().background(Color.brand.rule)

                // KeynoteRow
                VStack(alignment: .leading, spacing: BrandSpacing.sm) {
                    Text("KeynoteRow")
                        .font(.brandHeadline)
                        .foregroundColor(Color.brand.ink)

                    KeynoteRow(
                        year: "2026",
                        location: "Sydney, AU",
                        title: "Design System Integration",
                        event: "Citadel v2.0.0"
                    )
                }
            }
            .padding(BrandSpacing.lg)
        }
        .background(Color.brand.canvas)
    }
}

struct BrandComponentDemoView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BrandComponentDemoView()
                .preferredColorScheme(.light)
                .frame(width: 820, height: 900)
                .previewDisplayName("Light Mode")

            BrandComponentDemoView()
                .preferredColorScheme(.dark)
                .frame(width: 820, height: 900)
                .previewDisplayName("Dark Mode")
        }
    }
}
