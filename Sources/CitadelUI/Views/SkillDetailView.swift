import SwiftUI
import AppKit
import CitadelCore

/// Representation of a file or directory node inside a skill package
public struct SkillPackageNode: Identifiable, Hashable, Sendable {
    public var id: String { relativePath }
    public let name: String
    public let relativePath: String
    public let url: URL
    public let isDirectory: Bool
    public var children: [SkillPackageNode]?
    public let sizeInBytes: Int64
    
    public init(
        name: String,
        relativePath: String,
        url: URL,
        isDirectory: Bool,
        children: [SkillPackageNode]? = nil,
        sizeInBytes: Int64 = 0
    ) {
        self.name = name
        self.relativePath = relativePath
        self.url = url
        self.isDirectory = isDirectory
        self.children = children
        self.sizeInBytes = sizeInBytes
    }
    
    public static func scan(rootURL: URL) -> [SkillPackageNode] {
        return scanDirectory(directoryURL: rootURL, relativePrefix: "")
    }
    
    private static func scanDirectory(directoryURL: URL, relativePrefix: String) -> [SkillPackageNode] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        var nodes: [SkillPackageNode] = []
        for entry in entries {
            let name = entry.lastPathComponent
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let fileSize = Int64((try? entry.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            let rel = relativePrefix.isEmpty ? name : "\(relativePrefix)/\(name)"
            
            if isDir {
                let subNodes = scanDirectory(directoryURL: entry, relativePrefix: rel)
                nodes.append(SkillPackageNode(
                    name: name,
                    relativePath: rel,
                    url: entry,
                    isDirectory: true,
                    children: subNodes,
                    sizeInBytes: 0
                ))
            } else {
                nodes.append(SkillPackageNode(
                    name: name,
                    relativePath: rel,
                    url: entry,
                    isDirectory: false,
                    children: nil,
                    sizeInBytes: fileSize
                ))
            }
        }
        
        // Sort directories first, then alphabetically
        return nodes.sorted {
            if $0.isDirectory != $1.isDirectory {
                return $0.isDirectory && !$1.isDirectory
            }
            return $0.name.localizedCompare($1.name) == .orderedAscending
        }
    }
}

/// Shared Skill Detail & Inspection View
/// Can be presented in Armory Chamber, Discovery Chamber, sheets, or split views.
public struct SkillDetailView: View {
    public let skill: Skill
    public let content: String
    public let palette: ThemePalette
    public var onClose: (() -> Void)? = nil
    public var portals: [ProjectPortal] = []
    public var onToggleWorkspacePortal: ((URL) -> Void)? = nil
    
    private var _packageNodes = SwiftUI.State(initialValue: [SkillPackageNode]())
    private var packageNodes: [SkillPackageNode] {
        get { _packageNodes.wrappedValue }
        nonmutating set { _packageNodes.wrappedValue = newValue }
    }
    
    private var _selectedFileRelPath = SwiftUI.State(initialValue: "SKILL.md")
    private var selectedFileRelPath: String {
        get { _selectedFileRelPath.wrappedValue }
        nonmutating set { _selectedFileRelPath.wrappedValue = newValue }
    }
    
    private var _displayedContent = SwiftUI.State(initialValue: "")
    private var displayedContent: String {
        get { _displayedContent.wrappedValue }
        nonmutating set { _displayedContent.wrappedValue = newValue }
    }
    
    private var _selectedFileURL = SwiftUI.State<URL?>(initialValue: nil)
    private var selectedFileURL: URL? {
        get { _selectedFileURL.wrappedValue }
        nonmutating set { _selectedFileURL.wrappedValue = newValue }
    }
    
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
                
                HStack(spacing: BrandSpacing.xs) {
                    // Reveal in Finder Button
                    Button(action: {
                        revealInFinder()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Reveal in Finder")
                                .font(.brandMonoMicro)
                        }
                        .foregroundColor(palette.textPrimary)
                        .padding(.horizontal, BrandSpacing.xs + 2)
                        .padding(.vertical, BrandSpacing.xxs + 1)
                        .liquidGlassPill()
                    }
                    .buttonStyle(.plain)
                    .help("Reveal this skill package in macOS Finder")
                    
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
            
            // Package File Explorer + File Content View
            HSplitView {
                // Left pane: Package File Tree Navigator
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 10))
                            .foregroundColor(palette.accent)
                        Text("PACKAGE FILES")
                            .font(.brandMonoBadge)
                            .foregroundColor(palette.textPrimary)
                        Spacer()
                        Text("\(countTotalFiles(in: packageNodes)) files")
                            .font(.brandMonoMicro)
                            .foregroundColor(palette.textMuted)
                    }
                    .padding(.horizontal, BrandSpacing.sm)
                    .padding(.vertical, BrandSpacing.xs)
                    .background(palette.background.opacity(0.4))
                    
                    Divider().background(palette.border.opacity(0.2))
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(packageNodes) { node in
                                PackageNodeRow(
                                    node: node,
                                    selectedPath: selectedFileRelPath,
                                    palette: palette,
                                    level: 0,
                                    onSelectFile: { selectedNode in
                                        loadFile(node: selectedNode)
                                    }
                                )
                            }
                        }
                        .padding(.vertical, BrandSpacing.xs)
                    }
                }
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)
                .background(palette.card.opacity(0.25))
                
                // Right pane: Current File Inspector & Viewer
                VStack(alignment: .leading, spacing: 0) {
                    // File path breadcrumbs & action bar
                    HStack(spacing: BrandSpacing.xs) {
                        Image(systemName: iconForPath(selectedFileRelPath))
                            .font(.system(size: 11))
                            .foregroundColor(palette.accent)
                        
                        Text(selectedFileRelPath)
                            .font(.brandMonoBold)
                            .foregroundColor(palette.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button(action: {
                            if let target = selectedFileURL {
                                NSWorkspace.shared.activateFileViewerSelecting([target])
                            } else {
                                revealInFinder()
                            }
                        }) {
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 10))
                                .foregroundColor(palette.textMuted)
                        }
                        .buttonStyle(.plain)
                        .help("Reveal selected file in Finder")
                    }
                    .padding(.horizontal, BrandSpacing.md)
                    .padding(.vertical, BrandSpacing.xs + 2)
                    .background(palette.card.opacity(0.35))
                    
                    Divider().background(palette.border.opacity(0.2))
                    
                    // File text/code body
                    ScrollView {
                        Text(displayedContent)
                            .font(.brandMono)
                            .lineSpacing(5)
                            .foregroundColor(palette.textPrimary)
                            .textSelection(.enabled)
                            .padding(BrandSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(minWidth: 260, maxWidth: .infinity)
            }
        }
        .onAppear {
            refreshPackageNodes()
        }
        .onChange(of: skill.path) { _ in
            refreshPackageNodes()
        }
    }
    
    private func revealInFinder() {
        let target = skill.path
        if FileManager.default.fileExists(atPath: target.path) {
            NSWorkspace.shared.activateFileViewerSelecting([target])
        }
    }
    
    private func refreshPackageNodes() {
        let nodes = SkillPackageNode.scan(rootURL: skill.path)
        self.packageNodes = nodes
        
        // Default to SKILL.md if present, or first file
        if let skillNode = nodes.first(where: { $0.relativePath.lowercased() == "skill.md" }) {
            loadFile(node: skillNode)
        } else if let firstFile = findFirstFile(in: nodes) {
            loadFile(node: firstFile)
        } else {
            self.selectedFileRelPath = "SKILL.md"
            self.displayedContent = content
            self.selectedFileURL = skill.path.appendingPathComponent("SKILL.md")
        }
    }
    
    private func loadFile(node: SkillPackageNode) {
        guard !node.isDirectory else { return }
        self.selectedFileRelPath = node.relativePath
        self.selectedFileURL = node.url
        
        if let text = try? String(contentsOf: node.url, encoding: .utf8) {
            self.displayedContent = text
        } else {
            self.displayedContent = "// Binary or unreadable file: \(node.name) (\(node.sizeInBytes) bytes)"
        }
    }
    
    private func findFirstFile(in nodes: [SkillPackageNode]) -> SkillPackageNode? {
        for node in nodes {
            if !node.isDirectory { return node }
            if let children = node.children, let found = findFirstFile(in: children) {
                return found
            }
        }
        return nil
    }
    
    private func countTotalFiles(in nodes: [SkillPackageNode]) -> Int {
        var count = 0
        for node in nodes {
            if !node.isDirectory {
                count += 1
            } else if let children = node.children {
                count += countTotalFiles(in: children)
            }
        }
        return count
    }
    
    private func iconForPath(_ path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "md", "markdown", "txt":
            return "doc.text"
        case "sh", "bash", "zsh":
            return "terminal"
        case "py", "swift", "js", "ts", "rb":
            return "chevron.left.forwardslash.chevron.right"
        case "json", "yaml", "yml", "toml":
            return "gearshape"
        case "png", "jpg", "jpeg", "svg", "ico":
            return "photo"
        default:
            return "doc"
        }
    }
}

/// Recursive Tree Row View for file nodes in a skill package
fileprivate struct PackageNodeRow: View {
    let node: SkillPackageNode
    let selectedPath: String
    let palette: ThemePalette
    let level: Int
    let onSelectFile: (SkillPackageNode) -> Void
    
    private var _isExpanded = SwiftUI.State(initialValue: true)
    private var isExpanded: Bool {
        get { _isExpanded.wrappedValue }
        nonmutating set { _isExpanded.wrappedValue = newValue }
    }

    init(
        node: SkillPackageNode,
        selectedPath: String,
        palette: ThemePalette,
        level: Int,
        onSelectFile: @escaping (SkillPackageNode) -> Void
    ) {
        self.node = node
        self.selectedPath = selectedPath
        self.palette = palette
        self.level = level
        self.onSelectFile = onSelectFile
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                if node.isDirectory {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } else {
                    onSelectFile(node)
                }
            }) {
                HStack(spacing: 5) {
                    // Indentation
                    if level > 0 {
                        Spacer()
                            .frame(width: CGFloat(level * 12))
                    }
                    
                    // Folder disclosure or file icon
                    if node.isDirectory {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(palette.textMuted)
                            .frame(width: 10)
                        
                        Image(systemName: "folder.fill")
                            .font(.system(size: 11))
                            .foregroundColor(palette.accent.opacity(0.85))
                    } else {
                        Image(systemName: iconForNode(node))
                            .font(.system(size: 10))
                            .foregroundColor(node.relativePath == selectedPath ? palette.accent : palette.textMuted)
                            .frame(width: 10)
                    }
                    
                    Text(node.name)
                        .font(.brandMono)
                        .foregroundColor(node.relativePath == selectedPath ? palette.accent : palette.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                }
                .padding(.horizontal, BrandSpacing.xs)
                .padding(.vertical, 4)
                .background {
                    if node.relativePath == selectedPath && !node.isDirectory {
                        palette.accentMuted
                    } else {
                        Color.clear
                    }
                }
                .clipShape(BrandShapes.sm)
            }
            .buttonStyle(.plain)
            
            // Sub-tree for directories
            if node.isDirectory && isExpanded, let children = node.children {
                ForEach(children) { child in
                    PackageNodeRow(
                        node: child,
                        selectedPath: selectedPath,
                        palette: palette,
                        level: level + 1,
                        onSelectFile: onSelectFile
                    )
                }
            }
        }
    }
    
    private func iconForNode(_ node: SkillPackageNode) -> String {
        let ext = (node.name as NSString).pathExtension.lowercased()
        switch ext {
        case "md", "markdown", "txt":
            return "doc.text"
        case "sh", "bash", "zsh":
            return "terminal"
        case "py", "swift", "js", "ts", "rb":
            return "chevron.left.forwardslash.chevron.right"
        case "json", "yaml", "yml", "toml":
            return "gearshape"
        case "png", "jpg", "jpeg", "svg", "ico":
            return "photo"
        default:
            return "doc"
        }
    }
}
