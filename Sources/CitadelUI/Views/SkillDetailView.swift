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
    public var portals: [ProjectPortal] = []
    public var onToggleWorkspacePortal: ((URL) -> Void)? = nil
    
    public init(
        skill: Skill,
        content: String,
        palette: ThemePalette,
        onClose: (() -> Void)? = nil,
        portals: [ProjectPortal] = [],
        onToggleWorkspacePortal: ((URL) -> Void)? = nil
    ) {
        self.skill = skill
        self.content = content
        self.palette = palette
        self.onClose = onClose
        self.portals = portals
        self.onToggleWorkspacePortal = onToggleWorkspacePortal
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
            
            // Workspace Portals Section: choose which workspaces this skill is symlinked into
            if !portals.isEmpty {
                VStack(alignment: .leading, spacing: BrandSpacing.xs) {
                    HStack {
                        Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                            .font(.system(size: 11))
                            .foregroundColor(palette.accent)
                        Text("WORKSPACE SYMLINKS")
                            .font(.brandMonoBadge)
                            .foregroundColor(palette.textPrimary)
                        Spacer()
                        Text("Select workspaces to symlink this skill")
                            .font(.brandCaption)
                            .foregroundColor(palette.textMuted)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: BrandSpacing.xs) {
                            ForEach(portals) { portal in
                                let isLinked = portal.enabledSkills.contains(skill.name)
                                Button(action: {
                                    onToggleWorkspacePortal?(portal.projectPath)
                                }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: isLinked ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 10))
                                            .foregroundColor(isLinked ? palette.accent : palette.textMuted)
                                        Text(portal.projectPath.lastPathComponent)
                                            .font(.brandMono)
                                            .foregroundColor(isLinked ? palette.textPrimary : palette.textSecondary)
                                    }
                                    .padding(.horizontal, BrandSpacing.sm)
                                    .padding(.vertical, BrandSpacing.xxs + 1)
                                    .liquidGlassPill(tint: isLinked ? palette.accent : nil)
                                }
                                .buttonStyle(.plain)
                                .help(isLinked ? "Symlinked in \(portal.projectPath.path). Click to remove." : "Not linked in \(portal.projectPath.path). Click to symlink.")
                            }
                        }
                    }
                }
                .padding(.horizontal, BrandSpacing.md)
                .padding(.vertical, BrandSpacing.sm)
                .background(palette.card.opacity(0.4))
                
                Divider().background(palette.border.opacity(0.3))
            }
            
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
