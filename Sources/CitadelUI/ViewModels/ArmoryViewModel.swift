import SwiftUI
import Combine
import CitadelCore

@MainActor
public final class ArmoryViewModel: ObservableObject {
    @Published public var skills: [Skill] = []
    @Published public var mcps: [MCPServer] = []
    @Published public var portals: [ProjectPortal] = []
    
    @Published public var searchText: String = ""
    @Published public var selectedSkill: Skill? = nil
    @Published public var skillContent: String = ""
    @Published public var showSkillPreview: Bool = true
    
    public init() {}
    
    public var filteredSkills: [Skill] {
        guard !searchText.isEmpty else { return skills }
        return skills.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    public func selectSkill(_ skill: Skill) {
        self.selectedSkill = skill
        let skillFile = skill.path.appendingPathComponent(CitadelConstants.Paths.skillDocFile)
        if let content = try? String(contentsOf: skillFile, encoding: .utf8) {
            self.skillContent = content
        } else {
            self.skillContent = "// No SKILL.md found at \(skill.path.path)"
        }
    }
    
    public func reloadArmory() {
        self.skills = HubManager.shared.listArmorySkills()
        self.mcps = HubManager.shared.listArmoryMCPs()
        self.portals = HubManager.shared.loadPortals()
        
        if selectedSkill == nil, let first = skills.first {
            selectSkill(first)
        }
    }
}
