import Foundation

/// A grouped skill that exists across multiple tool locations
public struct SkillGroup: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let occurrences: [DiscoveredSkill]
    public let isFullyUnified: Bool
    public let description: String?
    
    public init(name: String, occurrences: [DiscoveredSkill]) {
        self.name = name
        self.occurrences = occurrences
        self.isFullyUnified = occurrences.allSatisfy { $0.isSymlink }
        self.description = occurrences.compactMap { $0.description }.first
    }
}

public final class SkillGroupManager: @unchecked Sendable {
    public static let shared = SkillGroupManager()
    
    private let fileManager = FileManager.default
    
    /// Groups all discovered skills by their canonical name
    public func groupDiscoveredSkills(_ skills: [DiscoveredSkill]) -> [SkillGroup] {
        var grouped: [String: [DiscoveredSkill]] = [:]
        for skill in skills {
            grouped[skill.name, default: []].append(skill)
        }
        return grouped.map { SkillGroup(name: $0.key, occurrences: $0.value) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
    
    /// Unifies a skill group: copies the freshest copy to ~/.citadel/skills and replaces all occurrences with symlinks
    public func unifyGroup(_ group: SkillGroup) throws -> Int {
        let hub = HubManager.shared
        try hub.initializeHub()
        
        let canonicalTarget = hub.skillsURL.appendingPathComponent(group.name)
        
        // Find best source (prefer non-symlink with newest modification date)
        var bestSource: URL? = nil
        var bestDate: Date = Date.distantPast
        
        for occ in group.occurrences {
            if !occ.isSymlink {
                let attr = try? fileManager.attributesOfItem(atPath: occ.path.path)
                let date = (attr?[.modificationDate] as? Date) ?? Date.distantPast
                if date >= bestDate {
                    bestDate = date
                    bestSource = occ.path
                }
            }
        }
        
        // If all are already symlinks, or no non-symlink exists, check if canonical target already exists
        if bestSource == nil && fileManager.fileExists(atPath: canonicalTarget.path) {
            bestSource = canonicalTarget
        } else if let source = bestSource, source.path != canonicalTarget.path {
            if fileManager.fileExists(atPath: canonicalTarget.path) {
                try? fileManager.removeItem(at: canonicalTarget)
            }
            try fileManager.copyItem(at: source, to: canonicalTarget)
        }
        
        guard fileManager.fileExists(atPath: canonicalTarget.path) else {
            throw NSError(domain: "Citadel", code: 404, userInfo: [NSLocalizedDescriptionKey: "No valid source found to unify \(group.name)"])
        }
        
        // Now convert all occurrences to symlinks pointing to canonicalTarget
        var unifiedCount = 0
        for occ in group.occurrences {
            if occ.path.path == canonicalTarget.path { continue }
            
            // If already pointing to canonical target, skip
            if let dest = try? fileManager.destinationOfSymbolicLink(atPath: occ.path.path),
               dest == canonicalTarget.path {
                continue
            }
            
            try? fileManager.removeItem(at: occ.path)
            try? fileManager.createSymbolicLink(at: occ.path, withDestinationURL: canonicalTarget)
            unifiedCount += 1
        }
        
        return unifiedCount
    }
}
