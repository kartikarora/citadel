import Foundation

public struct RollbackResult: Sendable {
    public let materializedSkills: [String]
    public let removedSymlinks: [String]
    public let warnings: [String]
    
    public init(materializedSkills: [String], removedSymlinks: [String], warnings: [String]) {
        self.materializedSkills = materializedSkills
        self.removedSymlinks = removedSymlinks
        self.warnings = warnings
    }
}

/// Handles emergency rollback, decoupling, and materialization of symlinks back into real standalone directories
public final class RollbackEngine: @unchecked Sendable {
    public static let shared = RollbackEngine()
    
    private let fileManager = FileManager.default
    private let paths = UniversalPaths.shared
    
    public init() {}
    
    /// Target directories where AI tools store their skills
    public var targetSkillDirectories: [URL] {
        return [
            paths.home.appendingPathComponent(".gemini/config/skills"),
            paths.home.appendingPathComponent(".claude/skills"),
            paths.home.appendingPathComponent(".android-studio/skills"),
            paths.home.appendingPathComponent(".copilot/skills"),
            paths.home.appendingPathComponent(".junie/skills")
        ]
    }
    
    /// Replaces all symlinks pointing into Citadel Hub with actual standalone directory copies
    @discardableResult
    public func ejectAndMaterialize(customHubURL: URL? = nil) throws -> RollbackResult {
        let hubURL = customHubURL ?? UniversalPaths.shared.citadelHome
        let hubSkillsURL = hubURL.appendingPathComponent(CitadelConstants.Paths.skillsFolder)
        
        var materialized: [String] = []
        var removedLinks: [String] = []
        var warnings: [String] = []
        
        var allTargetDirs = targetSkillDirectories
        
        // Also include project portal targets if portals.json exists
        let portalsFile = hubURL.appendingPathComponent(CitadelConstants.Paths.portalsFile)
        if let data = try? Data(contentsOf: portalsFile),
           let portals = try? JSONDecoder().decode([ProjectPortal].self, from: data) {
            for portal in portals {
                allTargetDirs.append(portal.projectPath.appendingPathComponent(".gemini/skills"))
                allTargetDirs.append(portal.projectPath.appendingPathComponent(".claude/skills"))
            }
        }
        
        for dir in allTargetDirs {
            guard fileManager.fileExists(atPath: dir.path) else { continue }
            guard let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isSymbolicLinkKey]) else { continue }
            
            for item in contents {
                let isLink = (try? item.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false
                guard isLink else { continue }
                
                guard let destination = try? fileManager.destinationOfSymbolicLink(atPath: item.path) else { continue }
                let destURL = URL(fileURLWithPath: destination)
                
                // Check if this symlink points to Citadel Hub
                if destURL.path.hasPrefix(hubSkillsURL.path) || destURL.path.hasPrefix(hubURL.path) {
                    do {
                        // Check if real source exists
                        if fileManager.fileExists(atPath: destURL.path) {
                            try fileManager.removeItem(at: item)
                            try fileManager.copyItem(at: destURL, to: item)
                            materialized.append("\(item.path) <- \(destURL.lastPathComponent)")
                        } else {
                            // Dangling pointer, remove it
                            try fileManager.removeItem(at: item)
                            removedLinks.append(item.path)
                        }
                    } catch {
                        warnings.append("Failed to materialize \(item.path): \(error.localizedDescription)")
                    }
                }
            }
        }
        
        return RollbackResult(
            materializedSkills: materialized,
            removedSymlinks: removedLinks,
            warnings: warnings
        )
    }
    
    /// Generates or refreshes a standalone POSIX shell script inside ~/.citadel/rollback.sh
    public func generateStandaloneRollbackScript(hubURL: URL) {
        let scriptPath = hubURL.appendingPathComponent(CitadelConstants.Paths.rollbackScriptFile)
        let script = """
        #!/usr/bin/env bash
        # ==============================================================================
        # Citadel Standalone Emergency Rollback & Materialization Script
        # ==============================================================================
        # If you ever want to uninstall or remove Citadel without losing your skills:
        # Running this script replaces every symlink in .gemini, .claude, .android-studio,
        # .copilot, and .junie with full, independent folder copies of your skills.
        #
        # Run: bash ~/.citadel/rollback.sh
        # ==============================================================================
        set -euo pipefail

        CITADEL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        CITADEL_SKILLS="$CITADEL_DIR/skills"

        echo "🏰 CITADEL EMERGENCY ROLLBACK & MATERIALIZATION"
        echo "Source skills directory: $CITADEL_SKILLS"
        echo "=================================================="

        TARGETS=(
            "$HOME/.gemini/config/skills"
            "$HOME/.claude/skills"
            "$HOME/.android-studio/skills"
            "$HOME/.copilot/skills"
            "$HOME/.junie/skills"
        )

        MATERIALIZED_COUNT=0

        for target_dir in "${TARGETS[@]}"; do
            if [ -d "$target_dir" ]; then
                echo "Inspecting: $target_dir"
                for skill_path in "$target_dir"/*; do
                    if [ -L "$skill_path" ]; then
                        target_link="$(readlink "$skill_path" || true)"
                        if [[ "$target_link" == *"$CITADEL_DIR"* ]]; then
                            skill_name="$(basename "$skill_path")"
                            real_source="$CITADEL_SKILLS/$skill_name"
                            if [ -d "$real_source" ]; then
                                rm -f "$skill_path"
                                cp -R "$real_source" "$skill_path"
                                echo "  [MATERIALIZED] $skill_name -> $target_dir/$skill_name"
                                MATERIALIZED_COUNT=$((MATERIALIZED_COUNT + 1))
                            else
                                rm -f "$skill_path"
                                echo "  [REMOVED DANGLING] $skill_path"
                            fi
                        fi
                    fi
                done
            fi
        done

        echo "=================================================="
        echo "✅ Rollback complete! Materialized $MATERIALIZED_COUNT skills into standalone folders."
        echo "Your AI tools now operate completely independently without Citadel."
        """
        
        try? script.write(to: scriptPath, atomically: true, encoding: .utf8)
        _ = CitadelUtils.runProcess(executable: "/bin/chmod", arguments: ["+x", scriptPath.path])
    }
}
