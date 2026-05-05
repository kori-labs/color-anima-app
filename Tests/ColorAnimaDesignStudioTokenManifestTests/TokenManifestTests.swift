import Testing
import Foundation
@testable import ColorAnimaDesignStudioTokenManifest
import ColorAnimaDesignStudioExtractorCore

@Suite("TokenManifest")
struct TokenManifestTests {

    // MARK: - Test 1: bundled manifest loads

    @Test("bundled manifest loads and is non-empty")
    func bundledManifestLoads() throws {
        let manifest = try TokenManifestLoader.bundled()
        #expect(manifest.schemaVersion == 1)
        #expect(!manifest.colors.isEmpty, "colors should be non-empty")
        #expect(!manifest.spacing.isEmpty, "spacing should be non-empty")
        #expect(!manifest.typography.isEmpty, "typography should be non-empty")
        #expect(!manifest.cornerRadii.isEmpty, "cornerRadii should be non-empty")
    }

    // MARK: - Test 2: manifest covers every design-system source file

    /// Verifies that every design-system source file that has token declarations
    /// contributes at least one token to the manifest.
    ///
    /// Source files that are pure UI components with no static token declarations
    /// are explicitly listed as UI-only and excluded from the assertion:
    ///   - ChromePrimitives.swift     — ButtonStyle + ViewModifier structs only
    ///   - HoverDeleteConfirmButton.swift — View struct only
    ///   - InlineRenameField.swift    — View struct + NSViewRepresentable only
    ///   - WorkspaceChromeAppearance.swift — utility functions / NSColor helpers only
    @Test("manifest covers all token-bearing design-system source files")
    func manifestCoversAllSourceFiles() throws {
        let manifest = try TokenManifestLoader.bundled()

        // These surfaces must appear in the manifest (they have static token declarations)
        let requiredSurfaces: Set<String> = [
            "WorkspaceFoundation",
            "WorkspaceChromeStyle",   // covers WorkspaceChromeStyle.swift + +ProjectTree.swift
        ]

        var presentSurfaces = Set<String>()
        manifest.colors.forEach      { presentSurfaces.insert($0.surface) }
        manifest.spacing.forEach     { presentSurfaces.insert($0.surface) }
        manifest.typography.forEach  { presentSurfaces.insert($0.surface) }
        manifest.cornerRadii.forEach { presentSurfaces.insert($0.surface) }

        for surface in requiredSurfaces {
            #expect(
                presentSurfaces.contains(surface),
                "surface '\(surface)' has no tokens in manifest"
            )
        }

        // Verify specific token sub-namespaces are represented
        let colorNames = Set(manifest.colors.map { $0.name })
        #expect(colorNames.contains(where: { $0.hasPrefix("WorkspaceFoundation.Surface.") }),
                "WorkspaceFoundation.Surface tokens missing")
        #expect(colorNames.contains(where: { $0.hasPrefix("WorkspaceFoundation.Stroke.") }),
                "WorkspaceFoundation.Stroke tokens missing")
        #expect(colorNames.contains(where: { $0.hasPrefix("WorkspaceFoundation.Foreground.") }),
                "WorkspaceFoundation.Foreground tokens missing")
        #expect(colorNames.contains(where: { $0.hasPrefix("WorkspaceChromeStyle.Sidebar.") }),
                "WorkspaceChromeStyle.Sidebar tokens missing")
        #expect(colorNames.contains(where: { $0.hasPrefix("WorkspaceChromeStyle.tree") }),
                "WorkspaceChromeStyle treeRow tokens (from +ProjectTree.swift) missing")

        // Spacing + typography from WorkspaceFoundation.Metrics / Typography
        let spacingNames = Set(manifest.spacing.map { $0.name })
        #expect(spacingNames.contains(where: { $0.hasPrefix("WorkspaceFoundation.Metrics.") }),
                "WorkspaceFoundation.Metrics spacing tokens missing")
    }

    // MARK: - Test 3: extractor is deterministic

    @Test("extractor produces byte-identical output on two runs")
    func extractorIsDeterministic() throws {
        let sourcesRoot = try resolveSourcesRoot()

        let data1 = try runExtraction(sourcesRoot: sourcesRoot)
        let data2 = try runExtraction(sourcesRoot: sourcesRoot)

        #expect(data1 == data2, "extractor output differs between two runs — not deterministic")
    }

    // MARK: - Test 4: manifest round-trip via JSONEncoder/Decoder is lossless

    @Test("manifest round-trips through JSONEncoder/Decoder losslessly")
    func manifestRoundTrip() throws {
        let original = try TokenManifestLoader.bundled()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(original)

        let decoded = try JSONDecoder().decode(TokenManifest.self, from: data)

        #expect(decoded == original, "decoded manifest does not equal original")
    }

    // MARK: - Helper

    private func resolveSourcesRoot() throws -> URL {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates = [
            cwd.appendingPathComponent("Sources"),
            cwd,
        ]
        for candidate in candidates {
            let designSystem = candidate.appendingPathComponent("ColorAnimaAppWorkspaceDesignSystem")
            if FileManager.default.fileExists(atPath: designSystem.path) {
                return candidate
            }
        }
        // Walk up to find Sources/ColorAnimaAppWorkspaceDesignSystem
        var dir = cwd
        for _ in 0..<5 {
            let designSystem = dir.appendingPathComponent("Sources/ColorAnimaAppWorkspaceDesignSystem")
            if FileManager.default.fileExists(atPath: designSystem.path) {
                return dir.appendingPathComponent("Sources")
            }
            dir = dir.deletingLastPathComponent()
        }
        throw TestError.sourcesRootNotFound(cwd.path)
    }
}

enum TestError: Error, CustomStringConvertible {
    case sourcesRootNotFound(String)

    var description: String {
        switch self {
        case let .sourcesRootNotFound(cwd):
            return "Could not locate Sources/ColorAnimaAppWorkspaceDesignSystem from cwd: \(cwd)"
        }
    }
}
