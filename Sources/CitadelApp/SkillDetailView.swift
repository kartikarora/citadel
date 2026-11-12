import SwiftUI
import CitadelCore
import CitadelUI

struct SkillDetailView: View {
    let skill: Skill
    let content: String
    let palette: ThemePalette
    var onClose: (() -> Void)? = nil
    var portals: [ProjectPortal] = []
    var onToggleWorkspacePortal: ((URL) -> Void)? = nil

    var body: some View {
        let uiPalette = CitadelUI.ThemePalette(
            isDark: palette.isDark,
            background: palette.background,
            card: palette.card,
            cardHover: palette.cardHover,
            cardSelected: palette.cardSelected,
            border: palette.border,
            borderStrong: palette.borderStrong,
            textPrimary: palette.textPrimary,
            textSecondary: palette.textSecondary,
            textMuted: palette.textMuted,
            accent: palette.accent,
            accentMuted: palette.accentMuted,
            success: palette.success,
            danger: palette.danger,
            warning: palette.warning
        )

        CitadelUI.SkillDetailView(
            skill: skill,
            content: content,
            palette: uiPalette,
            onClose: onClose,
            portals: portals,
            onToggleWorkspacePortal: onToggleWorkspacePortal
        )
    }
}
