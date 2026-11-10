import SwiftUI
import AppKit
import CitadelCore

/// Shared Skill Detail & Inspection View
/// Can be presented in Armory Chamber, Discovery Chamber, sheets, or split views.
public struct SkillDetailView: View {
    public let skill: Skill
    public let content: String
    public let palette: ThemePalette
    public var onClose: (() -> Void)? = nil
    
    public init(
        skill: Skill,
        content: String,
        palette: ThemePalette,
        onClose: (() -> Void)? = nil
    ) {
        self.skill = skill
        self.content = content
        self.palette = palette
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: BrandSpacing.xxs) {
                    HStack(spacing: BrandSpacing.xs) {
                        if let icon = skill.icon, !icon.isEmpty {
                            Image(systemName: icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(palette.accent)
                        }
                        
                        Text(skill.name)
                            .font(.brandHeadline)
                            .foregroundColor(palette.textPrimary)
                        
                        Text(skill.isSymlink ? "LINKED" : "CANONICAL")
                            .font(.brandMonoBadge)
                            .foregroundColor(palette.accent)
                            .padding(.horizontal, BrandSpacing.xs)
                            .padding(.vertical, BrandSpacing.xxs - 1)
                            .liquidGlassPill(tint: palette.accent)
                        
                        if let ver = skill.version, !ver.isEmpty {
                            Text("v\(ver)")
                                .font(.brandMonoBadge)
                                .foregroundColor(palette.textSecondary)
                                .padding(.horizontal, BrandSpacing.xs)
                                .padding(.vertical, BrandSpacing.xxs - 1)
                                .liquidGlassPill()
                        }
                    }
                    
                    Text(skill.path.path)
                        .font(.brandMonoMicro)
                        .foregroundColor(palette.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    if let author = skill.author, !author.isEmpty {
                        Text("Maintained by \(author)")
                            .font(.brandCaption)
                            .foregroundColor(palette.textSecondary)
                            .padding(.top, 2)
                    }
                    
                    if let desc = skill.description, !desc.isEmpty {
                        Text(desc)
                            .font(.brandBody)
                            .foregroundColor(palette.textSecondary)
                            .padding(.top, 2)
                    }
                }
                
                Spacer()
                
                if let onClose = onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(palette.textMuted)
                            .frame(width: 24, height: 24)
                            .liquidGlassPill()
                    }
                    .buttonStyle(.plain)
                    .help("Close skill view")
                }
            }
            .padding(BrandSpacing.md)
            .background(palette.background.opacity(0.2))
            
            Divider().background(palette.border.opacity(0.4))
            
            // Skill markdown instruction body
            ScrollView {
                Text(content)
                    .font(.brandMono)
                    .lineSpacing(5)
                    .foregroundColor(palette.textPrimary)
                    .textSelection(.enabled)
                    .padding(BrandSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
