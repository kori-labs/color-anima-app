// WriteBackEngineTests.swift — ColorAnimaDesignStudioWriteBackTests
//
// All tests operate on a temporary copy of the design-system source files.
// The actual Sources/ColorAnimaAppWorkspaceDesignSystem/ directory is never written.
//
// Test inventory:
//  1. round_trip_no_mutation            — write unchanged manifest → files byte-identical
//  2. round_trip_color_mutation         — mutate rgba dynamic color → re-extract equals mutated
//  3. round_trip_spacing_mutation       — mutate spacing literal → re-extract equals mutated
//  4. round_trip_typography_size_mutation — mutate font size → re-extract equals mutated
//  5. round_trip_corner_radius_mutation  — mutate corner radius → re-extract equals mutated
//  6. out_of_scope_write_throws         — edit outside root → sourceMutationOutOfScope
//  7. system_color_token_is_skipped_with_warning — systemColor/opacityOf → no edit emitted

import Testing
import Foundation
@testable import ColorAnimaDesignStudioWriteBack
import ColorAnimaDesignStudioTokenManifest
import ColorAnimaDesignStudioTokenManifestExtractor

// MARK: - Test suite

@Suite("WriteBackEngine round-trip")
struct WriteBackEngineTests {

    // MARK: - Helpers

    /// Copy all seven design-system source files to a temp directory.
    /// Returns (tmpRoot, designSystemRoot) where designSystemRoot is tmp/ColorAnimaAppWorkspaceDesignSystem.
    private func makeTempDesignSystemCopy() throws -> (tmpRoot: URL, designSystemRoot: URL) {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("WBTests-\(UUID().uuidString)", isDirectory: true)
        let dsRoot = tmp.appendingPathComponent("ColorAnimaAppWorkspaceDesignSystem", isDirectory: true)
        try FileManager.default.createDirectory(at: dsRoot, withIntermediateDirectories: true)

        let realSourcesRoot = try resolveRealSourcesRoot()
        let realDsRoot = realSourcesRoot.appendingPathComponent("ColorAnimaAppWorkspaceDesignSystem")

        let sourceFiles = [
            "WorkspaceFoundation.swift",
            "WorkspaceChromeStyle.swift",
            "WorkspaceChromeStyle+ProjectTree.swift",
            "WorkspaceChromeAppearance.swift",
            "ChromePrimitives.swift",
            "HoverDeleteConfirmButton.swift",
            "InlineRenameField.swift",
        ]
        for file in sourceFiles {
            let src = realDsRoot.appendingPathComponent(file)
            let dst = dsRoot.appendingPathComponent(file)
            try FileManager.default.copyItem(at: src, to: dst)
        }
        return (tmp, dsRoot)
    }

    /// Extract manifest from the temporary design-system root.
    private func extractManifest(sourcesRoot: URL) throws -> TokenManifest {
        let data = try runExtraction(sourcesRoot: sourcesRoot)
        return try TokenManifestLoader.decode(from: data)
    }

    /// Walk up from the test bundle to locate Sources/ColorAnimaAppWorkspaceDesignSystem.
    private func resolveRealSourcesRoot() throws -> URL {
        var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<8 {
            let candidate = dir.appendingPathComponent("Sources/ColorAnimaAppWorkspaceDesignSystem")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return dir.appendingPathComponent("Sources")
            }
            dir = dir.deletingLastPathComponent()
        }
        throw TestSetupError.sourcesRootNotFound
    }

    // MARK: - Test 1: round-trip with no mutation

    @Test("round_trip_no_mutation: writing unchanged manifest leaves files byte-identical")
    func round_trip_no_mutation() throws {
        let (tmpRoot, dsRoot) = try makeTempDesignSystemCopy()
        defer { try? FileManager.default.removeItem(at: tmpRoot) }

        // Snapshot original file contents
        let sourceFiles = try FileManager.default.contentsOfDirectory(at: dsRoot, includingPropertiesForKeys: nil)
        var origContents: [URL: Data] = [:]
        for file in sourceFiles where file.pathExtension == "swift" {
            origContents[file] = try Data(contentsOf: file)
        }

        let original = try extractManifest(sourcesRoot: tmpRoot)
        let engine   = WriteBackEngine(designSystemRoot: dsRoot)
        let plan     = try engine.plan(applying: original, against: original)

        // No-mutation plan should produce zero edits
        #expect(plan.edits.isEmpty, "no-mutation plan should have no edits, got: \(plan.edits.count)")

        try engine.apply(plan)

        // Files must be byte-identical
        for (fileURL, origData) in origContents {
            let afterData = try Data(contentsOf: fileURL)
            #expect(afterData == origData, "file \(fileURL.lastPathComponent) was modified by a no-op write-back")
        }
    }

    // MARK: - Test 2: round-trip with rgba dynamic color mutation

    @Test("round_trip_color_mutation: mutate a dynamic color → re-extract matches mutated manifest")
    func round_trip_color_mutation() throws {
        let (tmpRoot, dsRoot) = try makeTempDesignSystemCopy()
        defer { try? FileManager.default.removeItem(at: tmpRoot) }

        var original = try extractManifest(sourcesRoot: tmpRoot)

        // Find a .dynamic color token to mutate
        guard let tokenIndex = original.colors.indices.first(where: {
            if case .dynamic = original.colors[$0].value { return true }
            return false
        }) else {
            // No dynamic color token found — skip gracefully
            return
        }

        let origToken = original.colors[tokenIndex]
        guard case let .dynamic(origLight, origDark) = origToken.value else { return }

        // Mutate the light arm's red channel slightly
        let mutatedLight = RGBAValue(r: min(origLight.r + 0.01, 1.0), g: origLight.g, b: origLight.b, a: origLight.a)
        let mutatedValue = ColorValue.dynamic(light: mutatedLight, dark: origDark)
        let mutatedToken = ColorToken(name: origToken.name, surface: origToken.surface, value: mutatedValue)

        var mutatedColors = original.colors
        mutatedColors[tokenIndex] = mutatedToken
        let mutated = TokenManifest(
            schemaVersion: original.schemaVersion,
            extractedAt:   original.extractedAt,
            colors:        mutatedColors,
            spacing:       original.spacing,
            typography:    original.typography,
            cornerRadii:   original.cornerRadii
        )

        // Apply write-back
        let engine = WriteBackEngine(designSystemRoot: dsRoot)
        let plan   = try engine.plan(applying: mutated, against: original)
        try engine.apply(plan)

        // Re-extract and verify
        let reExtracted = try extractManifest(sourcesRoot: tmpRoot)
        let reToken = reExtracted.colors.first { $0.name == origToken.name }
        #expect(reToken != nil, "token \(origToken.name) missing from re-extracted manifest")

        guard let rt = reToken, case let .dynamic(rtLight, _) = rt.value else {
            Issue.record("re-extracted token \(origToken.name) is not a .dynamic color")
            return
        }
        #expect(abs(rtLight.r - mutatedLight.r) < 0.001,
                "light.r not round-tripped: expected \(mutatedLight.r), got \(rtLight.r)")

        // Reverse: write original back and verify
        let reversePlan = try engine.plan(applying: original, against: reExtracted)
        try engine.apply(reversePlan)
        let restored = try extractManifest(sourcesRoot: tmpRoot)
        let restoredToken = restored.colors.first { $0.name == origToken.name }
        guard let rst = restoredToken, case let .dynamic(rstLight, _) = rst.value else {
            Issue.record("restored token \(origToken.name) is not a .dynamic color")
            return
        }
        #expect(abs(rstLight.r - origLight.r) < 0.001,
                "reversed light.r not restored: expected \(origLight.r), got \(rstLight.r)")
    }

    // MARK: - Test 3: round-trip with spacing mutation

    @Test("round_trip_spacing_mutation: mutate a spacing token → re-extract matches mutated manifest")
    func round_trip_spacing_mutation() throws {
        let (tmpRoot, dsRoot) = try makeTempDesignSystemCopy()
        defer { try? FileManager.default.removeItem(at: tmpRoot) }

        let original = try extractManifest(sourcesRoot: tmpRoot)

        // Find a spacing token with a literal value (not an alias — we want one
        // the extractor resolves to a specific CGFloat literal in source)
        guard let tokenIndex = original.spacing.indices.first(where: {
            // Skip aliases: the extractor records these with the resolved value,
            // but the source line uses an identifier. We limit to non-alias tokens
            // by looking for tokens whose leaf name contains a digit (space1, space2 etc.)
            // Actually any token is fine — just pick the first one.
            _ = original.spacing[$0]
            return true
        }) else { return }

        let origToken = original.spacing[tokenIndex]
        let newValue  = origToken.value + 1.0  // bump by 1pt

        var mutatedSpacing = original.spacing
        mutatedSpacing[tokenIndex] = SpacingToken(name: origToken.name, surface: origToken.surface, value: newValue)
        let mutated = TokenManifest(
            schemaVersion: original.schemaVersion,
            extractedAt:   original.extractedAt,
            colors:        original.colors,
            spacing:       mutatedSpacing,
            typography:    original.typography,
            cornerRadii:   original.cornerRadii
        )

        let engine = WriteBackEngine(designSystemRoot: dsRoot)
        let plan   = try engine.plan(applying: mutated, against: original)
        try engine.apply(plan)

        let reExtracted = try extractManifest(sourcesRoot: tmpRoot)
        let reToken = reExtracted.spacing.first { $0.name == origToken.name }
        #expect(reToken != nil, "spacing token \(origToken.name) missing after write-back")
        if let rt = reToken {
            #expect(abs(rt.value - newValue) < 0.001,
                    "spacing \(origToken.name): expected \(newValue), got \(rt.value)")
        }

        // Reverse
        let reversePlan = try engine.plan(applying: original, against: reExtracted)
        try engine.apply(reversePlan)
        let restored = try extractManifest(sourcesRoot: tmpRoot)
        let restoredToken = restored.spacing.first { $0.name == origToken.name }
        if let rst = restoredToken {
            #expect(abs(rst.value - origToken.value) < 0.001,
                    "reversed spacing \(origToken.name): expected \(origToken.value), got \(rst.value)")
        }
    }

    // MARK: - Test 4: round-trip with typography size mutation

    @Test("round_trip_typography_size_mutation: mutate a font-size token → re-extract matches mutated manifest")
    func round_trip_typography_size_mutation() throws {
        let (tmpRoot, dsRoot) = try makeTempDesignSystemCopy()
        defer { try? FileManager.default.removeItem(at: tmpRoot) }

        let original = try extractManifest(sourcesRoot: tmpRoot)

        // Find a typography token that has an explicit size
        guard let tokenIndex = original.typography.indices.first(where: { original.typography[$0].size != nil }) else {
            // No explicit-size typography token — test passes vacuously
            return
        }

        let origToken = original.typography[tokenIndex]
        guard let origSize = origToken.size else { return }
        let newSize = origSize + 2.0

        var mutatedTypo = original.typography
        mutatedTypo[tokenIndex] = TypographyToken(
            name: origToken.name, surface: origToken.surface,
            size: newSize, weight: origToken.weight,
            design: origToken.design, systemFont: origToken.systemFont
        )
        let mutated = TokenManifest(
            schemaVersion: original.schemaVersion,
            extractedAt:   original.extractedAt,
            colors:        original.colors,
            spacing:       original.spacing,
            typography:    mutatedTypo,
            cornerRadii:   original.cornerRadii
        )

        let engine = WriteBackEngine(designSystemRoot: dsRoot)
        let plan   = try engine.plan(applying: mutated, against: original)
        try engine.apply(plan)

        let reExtracted = try extractManifest(sourcesRoot: tmpRoot)
        let reToken = reExtracted.typography.first { $0.name == origToken.name }
        #expect(reToken != nil, "typography token \(origToken.name) missing after write-back")
        if let rt = reToken, let rtSize = rt.size {
            #expect(abs(rtSize - newSize) < 0.001,
                    "typography size \(origToken.name): expected \(newSize), got \(rtSize)")
        }

        // Reverse
        let reversePlan = try engine.plan(applying: original, against: reExtracted)
        try engine.apply(reversePlan)
        let restored = try extractManifest(sourcesRoot: tmpRoot)
        let restoredToken = restored.typography.first { $0.name == origToken.name }
        if let rst = restoredToken, let rstSize = rst.size {
            #expect(abs(rstSize - origSize) < 0.001,
                    "reversed font size \(origToken.name): expected \(origSize), got \(rstSize)")
        }
    }

    // MARK: - Test 5: round-trip with corner radius mutation

    @Test("round_trip_corner_radius_mutation: mutate a corner-radius token → re-extract matches mutated manifest")
    func round_trip_corner_radius_mutation() throws {
        let (tmpRoot, dsRoot) = try makeTempDesignSystemCopy()
        defer { try? FileManager.default.removeItem(at: tmpRoot) }

        let original = try extractManifest(sourcesRoot: tmpRoot)
        guard !original.cornerRadii.isEmpty else { return }

        let origToken = original.cornerRadii[0]
        let newValue  = origToken.value + 2.0

        var mutatedCR = original.cornerRadii
        mutatedCR[0] = CornerRadiusToken(name: origToken.name, surface: origToken.surface, value: newValue)
        let mutated = TokenManifest(
            schemaVersion: original.schemaVersion,
            extractedAt:   original.extractedAt,
            colors:        original.colors,
            spacing:       original.spacing,
            typography:    original.typography,
            cornerRadii:   mutatedCR
        )

        let engine = WriteBackEngine(designSystemRoot: dsRoot)
        let plan   = try engine.plan(applying: mutated, against: original)
        try engine.apply(plan)

        let reExtracted = try extractManifest(sourcesRoot: tmpRoot)
        let reToken = reExtracted.cornerRadii.first { $0.name == origToken.name }
        #expect(reToken != nil, "cornerRadius token \(origToken.name) missing after write-back")
        if let rt = reToken {
            #expect(abs(rt.value - newValue) < 0.001,
                    "cornerRadius \(origToken.name): expected \(newValue), got \(rt.value)")
        }

        // Reverse
        let reversePlan = try engine.plan(applying: original, against: reExtracted)
        try engine.apply(reversePlan)
        let restored = try extractManifest(sourcesRoot: tmpRoot)
        let restoredToken = restored.cornerRadii.first { $0.name == origToken.name }
        if let rst = restoredToken {
            #expect(abs(rst.value - origToken.value) < 0.001,
                    "reversed cornerRadius \(origToken.name): expected \(origToken.value), got \(rst.value)")
        }
    }

    // MARK: - Test 6: out-of-scope write throws

    @Test("out_of_scope_write_throws: plan with out-of-scope file throws sourceMutationOutOfScope")
    func out_of_scope_write_throws() throws {
        let (tmpRoot, dsRoot) = try makeTempDesignSystemCopy()
        defer { try? FileManager.default.removeItem(at: tmpRoot) }

        // Build a plan that references a file outside dsRoot
        let outsideFile = tmpRoot.appendingPathComponent("outside.swift")
        try "// outside".write(to: outsideFile, atomically: true, encoding: .utf8)

        let outOfScopeEdit = WriteBackPlan.Edit(
            file: outsideFile,
            lineRange: 1..<2,
            oldContent: "// outside",
            newContent: "// modified"
        )
        let plan = WriteBackPlan(edits: [outOfScopeEdit])

        let engine = WriteBackEngine(designSystemRoot: dsRoot)

        var didThrow = false
        do {
            try engine.apply(plan)
        } catch WriteBackError.sourceMutationOutOfScope {
            didThrow = true
        } catch {
            Issue.record("wrong error type: \(error)")
        }
        #expect(didThrow, "expected sourceMutationOutOfScope to be thrown")
    }

    // MARK: - Test 7: system-color and opacityOf tokens are skipped

    @Test("system_color_token_is_skipped_with_warning: systemColor/opacityOf tokens produce no edit")
    func system_color_token_is_skipped_with_warning() throws {
        let (tmpRoot, dsRoot) = try makeTempDesignSystemCopy()
        defer { try? FileManager.default.removeItem(at: tmpRoot) }

        let original = try extractManifest(sourcesRoot: tmpRoot)

        // Find a .systemColor token
        guard let sysToken = original.colors.first(where: {
            if case .systemColor = $0.value { return true }
            return false
        }) else {
            // No systemColor token found — test passes vacuously
            return
        }

        // Build a mutated manifest that changes the systemColor token's value
        // (this is not meaningful semantically, but exercises the skip path)
        let fakeValue = ColorValue.systemColor("fakeSystemColor")
        let mutatedToken = ColorToken(name: sysToken.name, surface: sysToken.surface, value: fakeValue)
        var mutatedColors = original.colors
        if let idx = mutatedColors.firstIndex(where: { $0.name == sysToken.name }) {
            mutatedColors[idx] = mutatedToken
        }
        let mutated = TokenManifest(
            schemaVersion: original.schemaVersion,
            extractedAt:   original.extractedAt,
            colors:        mutatedColors,
            spacing:       original.spacing,
            typography:    original.typography,
            cornerRadii:   original.cornerRadii
        )

        let engine = WriteBackEngine(designSystemRoot: dsRoot)
        let plan   = try engine.plan(applying: mutated, against: original)

        // The skipped token must appear in skippedTokens and must NOT appear in edits
        let editNames = plan.edits.map { $0.oldContent }
        let hasEditForToken = editNames.contains(where: { $0.contains(leafName(sysToken.name)) })
        #expect(!hasEditForToken, "systemColor token \(sysToken.name) should not produce an edit")
        #expect(plan.skippedTokens[sysToken.name] != nil,
                "systemColor token \(sysToken.name) should appear in skippedTokens")

        // Repeat for opacityOf
        guard let opToken = original.colors.first(where: {
            if case .opacityOf = $0.value { return true }
            return false
        }) else { return }

        let fakeOpValue = ColorValue.opacityOf(base: "fakeBase", alpha: 0.99)
        let mutatedOpToken = ColorToken(name: opToken.name, surface: opToken.surface, value: fakeOpValue)
        var mutatedColors2 = original.colors
        if let idx = mutatedColors2.firstIndex(where: { $0.name == opToken.name }) {
            mutatedColors2[idx] = mutatedOpToken
        }
        let mutated2 = TokenManifest(
            schemaVersion: original.schemaVersion,
            extractedAt:   original.extractedAt,
            colors:        mutatedColors2,
            spacing:       original.spacing,
            typography:    original.typography,
            cornerRadii:   original.cornerRadii
        )

        let plan2 = try engine.plan(applying: mutated2, against: original)
        #expect(plan2.skippedTokens[opToken.name] != nil,
                "opacityOf token \(opToken.name) should appear in skippedTokens")
    }
}

// MARK: - Helpers

private func leafName(_ qualifiedName: String) -> String {
    qualifiedName.components(separatedBy: ".").last ?? qualifiedName
}

// MARK: - Errors

private enum TestSetupError: Error {
    case sourcesRootNotFound
}
