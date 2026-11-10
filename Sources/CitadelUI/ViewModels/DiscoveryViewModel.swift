import SwiftUI
import Combine
import CitadelCore

@MainActor
public final class DiscoveryViewModel: ObservableObject {
    @Published public var discoveredSkills: [DiscoveredSkill] = []
    @Published public var skillGroups: [SkillGroup] = []
    @Published public var discoveredMCPs: [DiscoveredMCP] = []
    @Published public var discoveredWorkspaces: [DiscoveredWorkspace] = []
    @Published public var isScanning: Bool = false
    @Published public var discoveryTab: String = "skills"
    
    // Approval sheet
    @Published public var showApprovalSheet: Bool = false
    @Published public var itemPendingApproval: String? = nil
    public var approvalAction: (() -> Void)? = nil
    
    // Skill Inspection / Detail View
    @Published public var selectedSkill: Skill? = nil
    @Published public var skillContent: String = ""
    @Published public var showSkillDetail: Bool = false
    
    public init() {}
    
    public func scanFilesystem(onRemoteStatus: ((RemoteSyncStatus) -> Void)? = nil) {
        guard !isScanning else { return }
        isScanning = true
        
        Task {
            // Progressive background discovery so UI stays fast and interactive
            _ = await MultiverseDiscoveryEngine.shared.runFullDiscoveryAsync { [weak self] partialReport in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if !partialReport.mcps.isEmpty {
                        self.discoveredMCPs = partialReport.mcps
                    }
                    if !partialReport.skills.isEmpty {
                        self.discoveredSkills = partialReport.skills
                        self.skillGroups = SkillGroupManager.shared.groupDiscoveredSkills(partialReport.skills)
                    }
                    if !partialReport.workspaces.isEmpty {
                        self.discoveredWorkspaces = partialReport.workspaces
                    }
                }
            }
            
            // Remote sync status check in background
            let status = await Task.detached(priority: .utility) {
                RemoteSyncManager.shared.getStatus()
            }.value
            
            await MainActor.run {
                self.isScanning = false
                onRemoteStatus?(status)
            }
        }
    }
    
    public func requestApproval(for itemName: String, action: @escaping () -> Void) {
        self.itemPendingApproval = itemName
        self.approvalAction = action
        self.showApprovalSheet = true
    }
    
    public func inspectSkill(_ skill: Skill) {
        self.selectedSkill = skill
        let skillFile = skill.path.appendingPathComponent(CitadelConstants.Paths.skillDocFile)
        if let content = try? String(contentsOf: skillFile, encoding: .utf8) {
            self.skillContent = content
        } else {
            self.skillContent = "// No SKILL.md found at \(skill.path.path)"
        }
        self.showSkillDetail = true
    }
    
    public func inspectSkillGroup(_ group: SkillGroup) {
        let bestOccurrence = group.occurrences.first(where: { !$0.isSymlink }) ?? group.occurrences.first
        guard let occ = bestOccurrence else { return }
        
        var parsedMeta = HubManager.ParsedSkillMeta()
        var loadedContent = ""
        let skillFile = occ.path.appendingPathComponent(CitadelConstants.Paths.skillDocFile)
        if let content = try? String(contentsOf: skillFile, encoding: .utf8) {
            loadedContent = content
            parsedMeta = HubManager.shared.parseSkillFrontmatter(from: content)
        } else {
            loadedContent = "// No SKILL.md found at \(occ.path.path)"
        }
        
        let skill = Skill(
            name: parsedMeta.name ?? group.name,
            path: occ.path,
            description: parsedMeta.description ?? group.description,
            isSymlink: occ.isSymlink,
            version: parsedMeta.version,
            author: parsedMeta.author,
            argumentHint: parsedMeta.argumentHint,
            icon: parsedMeta.icon
        )
        
        self.selectedSkill = skill
        self.skillContent = loadedContent
        self.showSkillDetail = true
    }
}
