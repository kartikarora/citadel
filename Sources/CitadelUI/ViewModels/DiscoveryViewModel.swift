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
    
    public init() {}
    
    public func scanFilesystem(onRemoteStatus: ((RemoteSyncStatus) -> Void)? = nil) {
        isScanning = true
        Task {
            let report = MultiverseDiscoveryEngine.shared.runFullDiscovery()
            let groups = SkillGroupManager.shared.groupDiscoveredSkills(report.skills)
            let status = RemoteSyncManager.shared.getStatus()
            
            await MainActor.run {
                self.discoveredSkills = report.skills
                self.skillGroups = groups
                self.discoveredMCPs = report.mcps
                self.discoveredWorkspaces = report.workspaces
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
}
