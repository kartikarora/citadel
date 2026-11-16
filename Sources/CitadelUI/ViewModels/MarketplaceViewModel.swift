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
    @Published public var selectedDetailPackage: NPMSkillPackage? = nil
    
    private var searchTask: Task<Void, Never>? = nil
    private var cancellables = Set<AnyCancellable>()
    
    public init(autoSearchDebounceMs: Int = 300) {
        if autoSearchDebounceMs > 0 {
            $marketQuery
                .dropFirst()
                .debounce(for: .milliseconds(autoSearchDebounceMs), scheduler: DispatchQueue.main)
                .removeDuplicates()
                .sink { [weak self] query in
                    self?.searchPackages(query: query)
                }
                .store(in: &cancellables)
        }
    }
    
    public func searchPackages(query: String) {
        // Cancel any in-flight search task before starting a new one
        searchTask?.cancel()
        searchTask = nil
        
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            self.marketPackages = []
            self.isSearchingMarket = false
            return
        }
        
        isSearchingMarket = true
        searchTask = Task {
            do {
                let packages = try await NPMRegistry.shared.searchSkills(query: trimmed)
                guard !Task.isCancelled else { return }
                self.marketPackages = packages
                self.isSearchingMarket = false
            } catch {
                guard !Task.isCancelled else { return }
                self.marketPackages = []
                self.isSearchingMarket = false
            }
        }
    }
    
    public func selectPackageForDetail(_ pkg: NPMSkillPackage?) {
        self.selectedDetailPackage = pkg
    }
    
    public func openPackageURL(_ pkg: NPMSkillPackage) -> URL? {
        let destination = pkg.homepageURL ?? pkg.repositoryURL ?? pkg.npmURL
        if let destination = destination {
            NSWorkspace.shared.open(destination)
        }
        return destination
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
