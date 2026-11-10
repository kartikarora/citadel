import SwiftUI
import Combine
import CitadelCore

@MainActor
public final class MarketplaceViewModel: ObservableObject {
    @Published public var marketQuery: String = ""
    @Published public var marketPackages: [NPMSkillPackage] = []
    @Published public var isSearchingMarket: Bool = false
    @Published public var installingPackage: String? = nil
    @Published public var removingPackage: String? = nil
    @Published public var installationNotice: String = ""
    
    public init() {}
    
    public func searchPackages(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            self.marketPackages = []
            return
        }
        
        isSearchingMarket = true
        Task {
            do {
                let packages = try await NPMRegistry.shared.searchSkills(query: query)
                await MainActor.run {
                    self.marketPackages = packages
                    self.isSearchingMarket = false
                }
            } catch {
                await MainActor.run {
                    self.marketPackages = []
                    self.isSearchingMarket = false
                }
            }
        }
    }
    
    public func installPackage(_ pkg: NPMSkillPackage, onComplete: @escaping () -> Void) {
        installingPackage = pkg.name
        Task {
            do {
                _ = try await NPMRegistry.shared.install(packageSpec: pkg.name)
                await MainActor.run {
                    self.installingPackage = nil
                    self.installationNotice = "Installed \(pkg.name) via NPX"
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    self.installingPackage = nil
                    self.installationNotice = "Installation failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    public func removePackage(skillName: String, onComplete: @escaping () -> Void) {
        removingPackage = skillName
        Task {
            do {
                try await NPMRegistry.shared.remove(skillName: skillName)
                await MainActor.run {
                    self.removingPackage = nil
                    self.installationNotice = "Removed \(skillName) via NPX"
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    self.removingPackage = nil
                    self.installationNotice = "Removal failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
