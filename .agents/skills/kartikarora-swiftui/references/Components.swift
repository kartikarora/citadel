import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/**
 * @kartikarora Brand SwiftUI Production Components (v2.0.0).
 * Implements signature brand components in compliance with @kartikarora design system:
 * 1. BrandButton (Primary, Outline, Ghost, Small)
 * 2. StatusBadge (GDE, Win, Loss, Draft)
 * 3. CLICommandPill (Terminal command copy pill)
 * 4. ArtifactRow (Full-bleed software showcase row)
 * 5. StanceView (Architectural invariant presentation)
 * 6. KeynoteRow (Conference ledger entry)
 * 7. BrandStatement (Editorial blockquote with Signal accent rule)
 */

// MARK: - 1. BrandButton

public enum BrandButtonStyleVariant {
    case primary
    case outline
    case ghost
    case small
    case liquidGlass
}

public struct BrandButtonStyle: ButtonStyle {
    public let variant: BrandButtonStyleVariant
    @Environment(\.isEnabled) private var isEnabled

    public init(variant: BrandButtonStyleVariant = .primary) {
        self.variant = variant
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(variant == .small ? .brandCaption : .brandBodyBold)
            .padding(.horizontal, variant == .small ? BrandSpacing.sm : BrandSpacing.md)
            .padding(.vertical, variant == .small ? BrandSpacing.xxs + 2 : BrandSpacing.xs + 2)
            .background(background(isPressed: configuration.isPressed))
            .foregroundColor(foregroundColor(isPressed: configuration.isPressed))
            .clipShape(BrandShapes.pill)
            .overlay {
                if variant == .liquidGlass {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(configuration.isPressed ? 0.45 : 0.28),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                } else {
                    BrandShapes.pill
                        .stroke(borderColor(isPressed: configuration.isPressed), lineWidth: 1)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(BrandMotion.fastSpring, value: configuration.isPressed)
            .opacity(isEnabled ? 1.0 : 0.45)
    }

    @ViewBuilder
    private func background(isPressed: Bool) -> some View {
        switch variant {
        case .primary:
            Color.brand.ink
        case .outline:
            isPressed ? Color.brand.surfaceSunken : Color.clear
        case .ghost:
            isPressed ? Color.brand.surfaceSunken : Color.clear
        case .small:
            Color.brand.surfaceSunken
        case .liquidGlass:
            ZStack {
                Capsule().fill(.ultraThinMaterial)
                Capsule().fill(isPressed ? Color.brand.signalWash.opacity(0.4) : Color.brand.signalWash.opacity(0.2))
            }
        }
    }

    private func foregroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            Color.brand.canvas
        case .outline, .ghost:
            isPressed ? Color.brand.signal : Color.brand.ink
        case .small:
            Color.brand.ink
        case .liquidGlass:
            isPressed ? Color.brand.signal : Color.brand.ink
        }
    }

    private func borderColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary, .liquidGlass:
            Color.clear
        case .outline:
            isPressed ? Color.brand.signal : Color.brand.rule
        case .ghost:
            Color.clear
        case .small:
            Color.brand.rule
        }
    }
}

public struct BrandButton: View {
    public let title: String
    public let icon: String?
    public let style: BrandButtonStyleVariant
    public let action: () -> Void

    public init(
        _ title: String,
        icon: String? = nil,
        style: BrandButtonStyleVariant = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: BrandSpacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .imageScale(.small)
                }
                Text(title)
            }
        }
        .buttonStyle(BrandButtonStyle(variant: style))
    }
}

// MARK: - 2. StatusBadge

public enum StatusBadgeVariant {
    case gde
    case win
    case loss
    case draft

    var textColor: Color {
        switch self {
        case .gde: return Color.brand.signal
        case .win: return Color.brand.success
        case .loss: return Color.brand.danger
        case .draft: return Color.brand.warning
        }
    }

    var backgroundColor: Color {
        textColor.opacity(0.12)
    }

    var borderColor: Color {
        textColor.opacity(0.32)
    }
}

public struct StatusBadge: View {
    public let label: String
    public let variant: StatusBadgeVariant

    public init(_ label: String, variant: StatusBadgeVariant = .gde) {
        self.label = label
        self.variant = variant
    }

    public var body: some View {
        Text(label)
            .brandMonoBadgeStyle()
            .foregroundColor(variant.textColor)
            .padding(.horizontal, BrandSpacing.xs + 2)
            .padding(.vertical, BrandSpacing.xxs)
            .background(variant.backgroundColor)
            .clipShape(BrandShapes.pill)
            .overlay(
                BrandShapes.pill
                    .stroke(variant.borderColor, lineWidth: 1)
            )
    }
}

// MARK: - 3. CLICommandPill

public struct CLICommandPill: View {
    public let command: String
    public let isGlass: Bool
    @State private var isCopied = false

    public init(command: String, isGlass: Bool = false) {
        self.command = command
        self.isGlass = isGlass
    }

    public var body: some View {
        Button(action: copyToClipboard) {
            HStack(spacing: BrandSpacing.xs) {
                Text("$")
                    .font(.brandMono)
                    .foregroundColor(Color.brand.inkMuted)

                Text(command)
                    .font(.brandMono)
                    .foregroundColor(Color.brand.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: BrandSpacing.xs)

                HStack(spacing: 4) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isCopied ? Color.brand.success : Color.brand.inkMuted)

                    if isCopied {
                        Text("Copied")
                            .font(.brandMonoMicro)
                            .foregroundColor(Color.brand.success)
                    }
                }
            }
            .padding(.horizontal, BrandSpacing.sm)
            .padding(.vertical, BrandSpacing.xs)
            .background {
                if isGlass {
                    Capsule().fill(.ultraThinMaterial)
                } else {
                    Capsule().fill(Color.brand.surfaceSunken)
                }
            }
            .clipShape(BrandShapes.pill)
            .overlay {
                if isGlass {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                } else {
                    BrandShapes.pill
                        .stroke(Color.brand.rule, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func copyToClipboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = command
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        #endif

        withAnimation(BrandMotion.fastSpring) {
            isCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(BrandMotion.fastSpring) {
                isCopied = false
            }
        }
    }
}

// MARK: - 4. ArtifactRow (Minimalist Showcase Row)

public struct ArtifactRow: View {
    public let tag: String
    public let badge: String?
    public let title: String
    public let summary: String
    public let cliCommand: String?
    public let actionTitle: String?
    public let action: (() -> Void)?

    public init(
        tag: String,
        badge: String? = nil,
        title: String,
        summary: String,
        cliCommand: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.tag = tag
        self.badge = badge
        self.title = title
        self.summary = summary
        self.cliCommand = cliCommand
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.sm) {
            // Meta Row
            HStack(spacing: BrandSpacing.sm) {
                Text(tag)
                    .brandMonoBadgeStyle()
                    .foregroundColor(Color.brand.inkMuted)

                if let badge = badge {
                    StatusBadge(badge, variant: .gde)
                }

                Spacer()
            }

            // Title & Summary
            Text(title)
                .font(.brandTitle)
                .foregroundColor(Color.brand.ink)

            Text(summary)
                .font(.brandBody)
                .foregroundColor(Color.brand.inkMuted)
                .lineSpacing(4)

            // CLI Pill (if provided)
            if let cli = cliCommand {
                CLICommandPill(command: cli)
                    .padding(.top, BrandSpacing.xxs)
            }

            // Action Button (if provided)
            if let actionTitle = actionTitle, let action = action {
                HStack {
                    Spacer()
                    BrandButton(actionTitle, icon: "arrow.up.right", style: .outline, action: action)
                }
                .padding(.top, BrandSpacing.xs)
            }

            // Full-bleed bottom divider
            Rectangle()
                .fill(Color.brand.rule)
                .frame(height: 1)
                .padding(.top, BrandSpacing.md)
        }
        .padding(.vertical, BrandSpacing.md)
    }
}

// MARK: - 5. StanceView (Architectural Invariant)

public struct StanceView: View {
    public let title: String
    public let bodyText: String

    public init(title: String, bodyText: String) {
        self.title = title
        self.bodyText = bodyText
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.xs) {
            Text(title)
                .font(.brandHeadline)
                .foregroundColor(Color.brand.ink)

            Text(bodyText)
                .font(.brandBody)
                .foregroundColor(Color.brand.inkMuted)
                .lineSpacing(4)

            Rectangle()
                .fill(Color.brand.rule)
                .frame(height: 1)
                .padding(.top, BrandSpacing.sm)
        }
        .padding(.vertical, BrandSpacing.sm)
    }
}

// MARK: - 6. KeynoteRow (Symposium Ledger)

public struct KeynoteRow: View {
    public let year: String
    public let location: String
    public let title: String
    public let event: String
    public let slidesURL: URL?
    public let videoURL: URL?

    public init(
        year: String,
        location: String,
        title: String,
        event: String,
        slidesURL: URL? = nil,
        videoURL: URL? = nil
    ) {
        self.year = year
        self.location = location
        self.title = title
        self.event = event
        self.slidesURL = slidesURL
        self.videoURL = videoURL
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.xs) {
            HStack(spacing: BrandSpacing.sm) {
                Text("\(year) · \(location)")
                    .brandMonoBadgeStyle()
                    .foregroundColor(Color.brand.inkMuted)

                Spacer()

                if let videoURL = videoURL {
                    Link(destination: videoURL) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.circle")
                            Text("Video")
                        }
                        .font(.brandCaption)
                        .foregroundColor(Color.brand.signal)
                    }
                }

                if let slidesURL = slidesURL {
                    Link(destination: slidesURL) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                            Text("Slides")
                        }
                        .font(.brandCaption)
                        .foregroundColor(Color.brand.signal)
                    }
                }
            }

            Text(title)
                .font(.brandHeadline)
                .foregroundColor(Color.brand.ink)

            Text(event)
                .font(.brandCaption)
                .foregroundColor(Color.brand.inkMuted)

            Rectangle()
                .fill(Color.brand.rule)
                .frame(height: 1)
                .padding(.top, BrandSpacing.xs)
        }
        .padding(.vertical, BrandSpacing.xs)
    }
}

// MARK: - 7. BrandStatement (Editorial Quote)

public struct BrandStatement: View {
    public let quote: String
    public let citation: String?

    public init(quote: String, citation: String? = nil) {
        self.quote = quote
        self.citation = citation
    }

    public var body: some View {
        HStack(alignment: .top, spacing: BrandSpacing.md) {
            // Signal Accent Left Border
            Rectangle()
                .fill(Color.brand.signal)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: BrandSpacing.xs) {
                Text(quote)
                    .font(.brandTitle)
                    .foregroundColor(Color.brand.ink)
                    .lineSpacing(6)

                if let citation = citation {
                    Text(citation)
                        .font(.brandMono)
                        .foregroundColor(Color.brand.inkMuted)
                }
            }
        }
        .padding(.vertical, BrandSpacing.sm)
    }
}

// MARK: - 8. LiquidGlassCard (Refractive Frosted Container)

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

// MARK: - 9. LiquidGlassPill (Refractive Capsule Container)

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
