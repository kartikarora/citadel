import SwiftUI
import Combine
import CitadelCore

@MainActor
public final class WorkspacesViewModel: ObservableObject {
    @Published public var discoveredWorkspaces: [DiscoveredWorkspace] = []
    @Published public var portals: [ProjectPortal] = []
    @Published public var workspaceSearchText: String = ""
    @Published public var actionNotice: String = ""
    
    public init() {}
    
    public var filteredWorkspaces: [DiscoveredWorkspace] {
        guard !workspaceSearchText.isEmpty else { return discoveredWorkspaces }
        return discoveredWorkspaces.filter {
            $0.name.localizedCaseInsensitiveContains(workspaceSearchText) ||
            $0.path.path.localizedCaseInsensitiveContains(workspaceSearchText)
        }
    }
    
    public func reloadWorkspaces() {
        self.portals = HubManager.shared.loadPortals()
    }
    
    public func addPortal(for url: URL, skills: [String] = [], mcps: [String] = [], onComplete: @escaping () -> Void) {
        var existing = HubManager.shared.loadPortals()
        if let idx = existing.firstIndex(where: { $0.projectPath.path == url.path }) {
            existing[idx].enabledSkills = skills
        } else {
            existing.append(ProjectPortal(projectPath: url, enabledSkills: skills, enabledMCPs: mcps))
        }
        do {
            try HubManager.shared.savePortals(existing)
            _ = try SyncEngine.shared.syncAll()
            self.actionNotice = "Connected workspace: \(url.lastPathComponent)"
            reloadWorkspaces()
            onComplete()
        } catch {
            self.actionNotice = "Failed to connect: \(error.localizedDescription)"
        }
    }
}
