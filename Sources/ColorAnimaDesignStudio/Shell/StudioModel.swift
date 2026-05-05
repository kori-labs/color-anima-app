import ColorAnimaDesignStudioIntegratedPreview
import ColorAnimaDesignStudioTokenManifest
import ColorAnimaDesignStudioWriteBack
import Foundation
import Observation

/// Top-level sidebar sections.
enum StudioSidebarSection: Hashable {
    case tokenCategory(TokenCategory)
    case integratedPreviews
}

/// Categories displayed in the studio sidebar.
enum TokenCategory: String, CaseIterable, Identifiable {
    case colors = "Colors"
    case spacing = "Spacing"
    case typography = "Typography"
    case cornerRadii = "Corner Radii"

    var id: String { rawValue }
}

// MARK: - Undo entry

/// One reversible edit on the token lists.
enum UndoEntry {
    case color(index: Int, old: ColorToken, new: ColorToken)
    case spacing(index: Int, old: SpacingToken, new: SpacingToken)
    case typography(index: Int, old: TypographyToken, new: TypographyToken)
    case cornerRadius(index: Int, old: CornerRadiusToken, new: CornerRadiusToken)
}

// MARK: - StudioModel

/// Central model for the Design Studio. Loads the bundled manifest at startup
/// and holds a mutable in-memory copy. Apply wiring, file watcher, and undo/redo
/// are implemented in Wave 7 (Child 8).
@Observable
final class StudioModel {

    // MARK: - Manifest data (mutable in-memory copies)

    var colors: [ColorToken]
    var spacing: [SpacingToken]
    var typography: [TypographyToken]
    var cornerRadii: [CornerRadiusToken]

    // MARK: - UI state

    var selectedCategory: TokenCategory = .colors
    var selectedSection: StudioSidebarSection = .tokenCategory(.colors)
    var selectedIntegratedScreen: IntegratedPreviewScreen = .intake
    var isDirty: Bool = false
    var loadError: String?

    // MARK: - Apply state

    /// Whether the design-system source root was found and write-back can run.
    var applyAvailable: Bool = false
    /// Non-blocking banner messages for apply results (success or error).
    var applyBannerMessage: String? = nil
    var applyBannerIsError: Bool = false

    // MARK: - External-edit state

    /// Set when an external file change is detected while the user has dirty edits.
    var externalChangeDetected: Bool = false

    // MARK: - Undo/redo (bounded ring buffer, max 20)

    private var undoStack: [UndoEntry] = []
    private var redoStack: [UndoEntry] = []
    private let undoLimit = 20

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Internals

    private var designSystemRoot: URL? = nil
    private var fileWatcherSource: DispatchSourceFileSystemObject? = nil
    private var debounceWorkItem: DispatchWorkItem? = nil

    // MARK: - Init

    init() {
        colors = []
        spacing = []
        typography = []
        cornerRadii = []
        load()
        designSystemRoot = resolveDesignSystemRoot()
        applyAvailable = designSystemRoot != nil
        if designSystemRoot == nil {
            applyBannerMessage = "Source repo root not found — running detached; Apply is disabled in this build"
            applyBannerIsError = false
        }
        if let root = designSystemRoot {
            installFileWatcher(designSystemSourcesDir: root.appendingPathComponent("ColorAnimaAppWorkspaceDesignSystem"))
        }
    }

    // MARK: - Load

    private func load() {
        do {
            let manifest = try TokenManifestLoader.bundled()
            applyManifest(manifest)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func applyManifest(_ manifest: TokenManifest) {
        colors = manifest.colors
        spacing = manifest.spacing
        typography = manifest.typography
        cornerRadii = manifest.cornerRadii
    }

    // MARK: - Repo root resolution

    /// Walks up from the executable's current directory to find a folder
    /// containing Sources/ColorAnimaAppWorkspaceDesignSystem/.
    private func resolveDesignSystemRoot() -> URL? {
        let fm = FileManager.default
        var candidate = URL(fileURLWithPath: fm.currentDirectoryPath)
        for _ in 0..<12 {
            let probe = candidate
                .appendingPathComponent("Sources")
                .appendingPathComponent("ColorAnimaAppWorkspaceDesignSystem")
            if fm.fileExists(atPath: probe.path) {
                return candidate
            }
            let parent = candidate.deletingLastPathComponent()
            if parent == candidate { break }
            candidate = parent
        }
        return nil
    }

    // MARK: - Apply

    func applyToSource() {
        guard let root = designSystemRoot else { return }
        let manifest = TokenManifest(
            schemaVersion: 1,
            extractedAt: ISO8601DateFormatter().string(from: Date()),
            colors: colors,
            spacing: spacing,
            typography: typography,
            cornerRadii: cornerRadii
        )
        do {
            let designSystemRoot = root
                .appendingPathComponent("Sources")
                .appendingPathComponent("ColorAnimaAppWorkspaceDesignSystem")
            let changed = try WriteBackOperation.apply(
                mutated: manifest,
                designSystemRoot: designSystemRoot
            )
            isDirty = false
            applyBannerIsError = false
            applyBannerMessage = changed.isEmpty
                ? "No changes to write back"
                : "Applied — \(changed.count) file(s) updated"
        } catch {
            applyBannerIsError = true
            applyBannerMessage = "Apply failed: \(error.localizedDescription)"
        }
    }

    func dismissApplyBanner() {
        applyBannerMessage = nil
    }

    // MARK: - File watcher

    private func installFileWatcher(designSystemSourcesDir: URL) {
        let fd = open(designSystemSourcesDir.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .attrib],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            self?.scheduleExternalReload()
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        fileWatcherSource = source
    }

    private func scheduleExternalReload() {
        debounceWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.handleExternalChange()
        }
        debounceWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }

    private func handleExternalChange() {
        guard let root = designSystemRoot else { return }
        guard let freshManifest = reextract(sourcesRoot: root.appendingPathComponent("Sources")) else { return }

        if isDirty {
            externalChangeDetected = true
        } else {
            applyManifest(freshManifest)
        }
    }

    func discardAndReloadFromExternal() {
        guard let root = designSystemRoot,
              let freshManifest = reextract(sourcesRoot: root.appendingPathComponent("Sources")) else { return }
        applyManifest(freshManifest)
        undoStack.removeAll()
        redoStack.removeAll()
        isDirty = false
        externalChangeDetected = false
    }

    func dismissExternalChangeBanner() {
        externalChangeDetected = false
    }

    private func reextract(sourcesRoot: URL) -> TokenManifest? {
        try? WriteBackOperation.extractManifest(sourcesRoot: sourcesRoot)
    }

    // MARK: - Undo / Redo

    func undo() {
        guard let entry = undoStack.popLast() else { return }
        applyUndo(entry)
        redoStack.append(entry)
    }

    func redo() {
        guard let entry = redoStack.popLast() else { return }
        applyRedo(entry)
        undoStack.append(entry)
        if undoStack.count > undoLimit { undoStack.removeFirst() }
    }

    private func applyUndo(_ entry: UndoEntry) {
        switch entry {
        case let .color(index, old, _):
            guard index < colors.count else { return }
            colors[index] = old
        case let .spacing(index, old, _):
            guard index < spacing.count else { return }
            spacing[index] = old
        case let .typography(index, old, _):
            guard index < typography.count else { return }
            typography[index] = old
        case let .cornerRadius(index, old, _):
            guard index < cornerRadii.count else { return }
            cornerRadii[index] = old
        }
        isDirty = !undoStack.isEmpty
    }

    private func applyRedo(_ entry: UndoEntry) {
        switch entry {
        case let .color(index, _, new):
            guard index < colors.count else { return }
            colors[index] = new
        case let .spacing(index, _, new):
            guard index < spacing.count else { return }
            spacing[index] = new
        case let .typography(index, _, new):
            guard index < typography.count else { return }
            typography[index] = new
        case let .cornerRadius(index, _, new):
            guard index < cornerRadii.count else { return }
            cornerRadii[index] = new
        }
        isDirty = true
    }

    // MARK: - Mutation helpers (feed undo stack)

    func updateColor(_ token: ColorToken, at index: Int) {
        guard index < colors.count else { return }
        let old = colors[index]
        colors[index] = token
        isDirty = true
        pushUndo(.color(index: index, old: old, new: token))
    }

    func updateSpacing(_ token: SpacingToken, at index: Int) {
        guard index < spacing.count else { return }
        let old = spacing[index]
        spacing[index] = token
        isDirty = true
        pushUndo(.spacing(index: index, old: old, new: token))
    }

    func updateTypography(_ token: TypographyToken, at index: Int) {
        guard index < typography.count else { return }
        let old = typography[index]
        typography[index] = token
        isDirty = true
        pushUndo(.typography(index: index, old: old, new: token))
    }

    func updateCornerRadius(_ token: CornerRadiusToken, at index: Int) {
        guard index < cornerRadii.count else { return }
        let old = cornerRadii[index]
        cornerRadii[index] = token
        isDirty = true
        pushUndo(.cornerRadius(index: index, old: old, new: token))
    }

    private func pushUndo(_ entry: UndoEntry) {
        redoStack.removeAll()
        undoStack.append(entry)
        if undoStack.count > undoLimit { undoStack.removeFirst() }
    }
}
