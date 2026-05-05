// WriteBackEngine.swift — ColorAnimaDesignStudioWriteBack
//
// Supported token kinds for mutation:
//   - ColorToken with .dynamic(light:dark:)  — replaces NSColor literal components
//   - SpacingToken                            — replaces CGFloat literal
//   - TypographyToken (size != nil)           — replaces size literal in Font.system(size:...)
//   - CornerRadiusToken                       — replaces CGFloat literal
//
// Intentionally read-only (skipped with warning, no edit emitted):
//   - ColorToken with .systemColor(...)  — system semantic color, not a literal
//   - ColorToken with .opacityOf(...)    — opacity variant of a named color
//
// Atomic write: write to <file>.writeback.tmp then rename via FileManager.replaceItem.

import Foundation
import ColorAnimaDesignStudioTokenManifest

// MARK: - Errors

public enum WriteBackError: Error, Sendable {
    /// The token name appears in the mutated manifest but could not be located
    /// in its declared source file.
    case tokenMissingFromSource(name: String)
    /// Writing to the destination file failed.
    case writeFailed(URL, underlying: Error)
    /// The token shape (e.g. a dynamic color with unparseable arms) is not
    /// supported by the writer.
    case unsupportedTokenShape(name: String)
    /// A planned edit targets a file outside the configured design-system root.
    case sourceMutationOutOfScope(URL)
}

// MARK: - WriteBackPlan

/// A description of all source-file edits needed to apply a mutated manifest.
public struct WriteBackPlan: Sendable, Equatable {
    /// One line-range replacement inside a single source file.
    public struct Edit: Sendable, Equatable {
        /// Absolute URL of the file to edit.
        public let file: URL
        /// 1-based, inclusive line range that will be replaced.
        public let lineRange: Range<Int>
        /// The original content of those lines (joined by "\n").
        public let oldContent: String
        /// The replacement content (joined by "\n").
        public let newContent: String
    }

    /// All edits, grouped by file and ordered top-to-bottom within each file.
    public let edits: [Edit]

    /// Skipped tokens (name → reason) for informational use by the caller.
    public let skippedTokens: [String: String]

    public init(edits: [Edit], skippedTokens: [String: String] = [:]) {
        self.edits = edits
        self.skippedTokens = skippedTokens
    }
}

// MARK: - WriteBackOperation (public convenience wrapper)

public enum WriteBackOperation {
    /// Apply all mutated tokens to the design-system source files.
    /// Returns the list of files that were actually changed (unchanged files are omitted).
    @discardableResult
    public static func apply(mutated: TokenManifest, designSystemRoot: URL) throws -> [URL] {
        let engine = WriteBackEngine(designSystemRoot: designSystemRoot)
        let original = try engine.extractCurrentManifest()
        let plan = try engine.plan(applying: mutated, against: original)
        try engine.apply(plan)
        // Return unique file URLs from the applied edits
        let changed = Array(Set(plan.edits.map { $0.file }))
        return changed
    }
}

// MARK: - WriteBackEngine

/// Computes and applies source-level edits to design-system Swift files based on
/// token-value changes between two ``TokenManifest`` instances.
public struct WriteBackEngine: Sendable {

    /// Absolute path to the `Sources/ColorAnimaAppWorkspaceDesignSystem/` directory.
    public let designSystemRoot: URL

    // File name → surface name mapping (mirrors the extractor's list).
    private static let sourceFiles: [(file: String, surface: String)] = [
        ("WorkspaceFoundation.swift",             "WorkspaceFoundation"),
        ("WorkspaceChromeStyle.swift",            "WorkspaceChromeStyle"),
        ("WorkspaceChromeStyle+ProjectTree.swift", "WorkspaceChromeStyle"),
        ("WorkspaceChromeAppearance.swift",        "WorkspaceChromeAppearance"),
        ("ChromePrimitives.swift",                 "ChromePrimitives"),
        ("HoverDeleteConfirmButton.swift",         "HoverDeleteConfirmButton"),
        ("InlineRenameField.swift",                "InlineRenameField"),
    ]

    public init(designSystemRoot: URL) {
        self.designSystemRoot = designSystemRoot
    }

    // MARK: - plan

    /// Compute the edits needed to apply `mutated` over `original`.
    ///
    /// Only tokens whose value has actually changed produce edits.
    /// Unchanged tokens are silently skipped.
    public func plan(applying mutated: TokenManifest, against original: TokenManifest) throws -> WriteBackPlan {
        // Build lookup maps from the original manifest for fast diff
        let origColors       = Dictionary(original.colors.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        let origSpacing      = Dictionary(original.spacing.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        let origTypography   = Dictionary(original.typography.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        let origCornerRadii  = Dictionary(original.cornerRadii.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })

        // Load source file contents once per file (keyed by file URL)
        var fileLines: [URL: [String]] = [:]
        var skipped: [String: String] = [:]

        func linesFor(url: URL) throws -> [String] {
            if let cached = fileLines[url] { return cached }
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: "\n")
            fileLines[url] = lines
            return lines
        }

        // Collect pending edits per file URL; we defer sorting until the end.
        var pendingEdits: [WriteBackPlan.Edit] = []

        // --- Color tokens ---
        for token in mutated.colors {
            guard let orig = origColors[token.name] else { continue }
            guard token.value != orig.value else { continue }

            switch token.value {
            case let .dynamic(newLight, newDark):
                guard case let .dynamic(oldLight, oldDark) = orig.value else {
                    skipped[token.name] = "value kind changed (not supported)"
                    continue
                }
                let fileURL = try resolveFile(for: token, assertingIn: designSystemRoot)
                let lines   = try linesFor(url: fileURL)
                if let edit = try makeDynamicColorEdit(
                    token: token,
                    oldLight: oldLight, oldDark: oldDark,
                    newLight: newLight, newDark: newDark,
                    lines: lines,
                    file: fileURL
                ) {
                    pendingEdits.append(edit)
                }
            case .systemColor:
                skipped[token.name] = "systemColor tokens are read-only at write-time"
            case .opacityOf:
                skipped[token.name] = "opacityOf tokens are read-only at write-time"
            case .rgba:
                // rgba single-color form: not common in these sources but handle it
                skipped[token.name] = "rgba single-form not supported in current source patterns"
            }
        }

        // --- Spacing tokens ---
        for token in mutated.spacing {
            guard let orig = origSpacing[token.name] else { continue }
            guard token.value != orig.value else { continue }
            let fileURL = try resolveFile(for: token, assertingIn: designSystemRoot)
            let lines   = try linesFor(url: fileURL)
            if let edit = try makeCGFloatEdit(tokenName: token.name, oldValue: orig.value, newValue: token.value, lines: lines, file: fileURL) {
                pendingEdits.append(edit)
            }
        }

        // --- Typography tokens ---
        for token in mutated.typography {
            guard let orig = origTypography[token.name] else { continue }
            guard token != orig else { continue }
            guard let newSize = token.size else {
                skipped[token.name] = "named system font token (no size literal) — read-only"
                continue
            }
            let fileURL = try resolveFile(for: token, assertingIn: designSystemRoot)
            let lines   = try linesFor(url: fileURL)
            if let edit = try makeTypographyEdit(token: token, orig: orig, newSize: newSize, lines: lines, file: fileURL) {
                pendingEdits.append(edit)
            }
        }

        // --- Corner-radius tokens ---
        for token in mutated.cornerRadii {
            guard let orig = origCornerRadii[token.name] else { continue }
            guard token.value != orig.value else { continue }
            let fileURL = try resolveFile(for: token, assertingIn: designSystemRoot)
            let lines   = try linesFor(url: fileURL)
            if let edit = try makeCGFloatEdit(tokenName: token.name, oldValue: orig.value, newValue: token.value, lines: lines, file: fileURL) {
                pendingEdits.append(edit)
            }
        }

        // Sort edits: by file path then by lineRange start (top-to-bottom within file)
        let sorted = pendingEdits.sorted {
            let pathA = $0.file.path
            let pathB = $1.file.path
            if pathA != pathB { return pathA < pathB }
            return $0.lineRange.lowerBound < $1.lineRange.lowerBound
        }

        return WriteBackPlan(edits: sorted, skippedTokens: skipped)
    }

    // MARK: - apply

    /// Write all edits in the plan to disk atomically (temp-file-then-rename per file).
    public func apply(_ plan: WriteBackPlan) throws {
        // Group edits by file
        var byFile: [URL: [WriteBackPlan.Edit]] = [:]
        for edit in plan.edits {
            byFile[edit.file, default: []].append(edit)
        }

        for (fileURL, edits) in byFile {
            // Scope guard: every file must be inside designSystemRoot
            try assertInScope(fileURL)

            let originalContent = try String(contentsOf: fileURL, encoding: .utf8)
            var lines = originalContent.components(separatedBy: "\n")

            // Apply edits in reverse order (bottom-to-top) so line indices stay stable
            let sortedEdits = edits.sorted { $0.lineRange.lowerBound > $1.lineRange.lowerBound }
            for edit in sortedEdits {
                // lineRange is 1-based inclusive; convert to 0-based half-open
                let start = edit.lineRange.lowerBound - 1
                let end   = edit.lineRange.upperBound - 1  // inclusive, so count = end-start+1
                guard start >= 0, end < lines.count, start <= end else {
                    throw WriteBackError.tokenMissingFromSource(name: edit.oldContent)
                }
                let newLines = edit.newContent.components(separatedBy: "\n")
                lines.replaceSubrange(start...end, with: newLines)
            }

            let newContent = lines.joined(separator: "\n")
            let tmpURL = fileURL.deletingLastPathComponent()
                .appendingPathComponent(fileURL.lastPathComponent + ".writeback.tmp")
            do {
                try newContent.write(to: tmpURL, atomically: false, encoding: .utf8)
                _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tmpURL)
            } catch {
                // Clean up temp file if it exists
                try? FileManager.default.removeItem(at: tmpURL)
                throw WriteBackError.writeFailed(fileURL, underlying: error)
            }
        }
    }

    // MARK: - dryRun

    /// Returns the proposed full file content for each file that would be modified,
    /// without writing anything to disk.
    public func dryRun(_ plan: WriteBackPlan) -> [URL: String] {
        var byFile: [URL: [WriteBackPlan.Edit]] = [:]
        for edit in plan.edits {
            byFile[edit.file, default: []].append(edit)
        }

        var result: [URL: String] = [:]
        for (fileURL, edits) in byFile {
            guard let originalContent = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            var lines = originalContent.components(separatedBy: "\n")
            let sortedEdits = edits.sorted { $0.lineRange.lowerBound > $1.lineRange.lowerBound }
            for edit in sortedEdits {
                let start = edit.lineRange.lowerBound - 1
                let end   = edit.lineRange.upperBound - 1
                guard start >= 0, end < lines.count, start <= end else { continue }
                let newLines = edit.newContent.components(separatedBy: "\n")
                lines.replaceSubrange(start...end, with: newLines)
            }
            result[fileURL] = lines.joined(separator: "\n")
        }
        return result
    }

    // MARK: - extractCurrentManifest (for WriteBackOperation)

    /// Re-extract the manifest from the current design-system sources.
    func extractCurrentManifest() throws -> TokenManifest {
        // designSystemRoot IS ColorAnimaAppWorkspaceDesignSystem/
        // The extractor expects Sources/ parent to contain ColorAnimaAppWorkspaceDesignSystem/
        let sourcesRoot = designSystemRoot.deletingLastPathComponent()
        let data = try runExtraction(sourcesRoot: sourcesRoot)
        return try TokenManifestLoader.decode(from: data)
    }

    // MARK: - Scope guard

    private func assertInScope(_ url: URL) throws {
        let rootPath  = designSystemRoot.standardizedFileURL.path
        let filePath  = url.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath) else {
            throw WriteBackError.sourceMutationOutOfScope(url)
        }
    }

    // MARK: - File resolution helpers

    private func resolveFile<T: TokenProtocol>(for token: T, assertingIn root: URL) throws -> URL {
        // surface → file mapping
        let url = fileURL(for: token.surface)
        // For tokens whose surface maps to multiple files (WorkspaceChromeStyle),
        // we need to find which file actually has the token declaration.
        if token.surface == "WorkspaceChromeStyle" {
            let candidates = Self.sourceFiles
                .filter { $0.surface == "WorkspaceChromeStyle" }
                .map { root.appendingPathComponent($0.file) }
            for candidate in candidates {
                if let content = try? String(contentsOf: candidate, encoding: .utf8),
                   content.contains(leafName(token.name)) {
                    try assertInScope(candidate)
                    return candidate
                }
            }
        }
        let resolved = root.appendingPathComponent(url)
        try assertInScope(resolved)
        return resolved
    }

    private func fileURL(for surface: String) -> String {
        switch surface {
        case "WorkspaceFoundation":       return "WorkspaceFoundation.swift"
        case "WorkspaceChromeStyle":      return "WorkspaceChromeStyle.swift"
        case "WorkspaceChromeAppearance": return "WorkspaceChromeAppearance.swift"
        case "ChromePrimitives":          return "ChromePrimitives.swift"
        case "HoverDeleteConfirmButton":  return "HoverDeleteConfirmButton.swift"
        case "InlineRenameField":         return "InlineRenameField.swift"
        default:                          return "\(surface).swift"
        }
    }

    /// Last component of a dotted token name, e.g. "WorkspaceFoundation.Metrics.space1" → "space1"
    private func leafName(_ qualifiedName: String) -> String {
        qualifiedName.components(separatedBy: ".").last ?? qualifiedName
    }

    // MARK: - Edit builders

    /// Build an edit for a CGFloat literal (spacing or corner radius).
    private func makeCGFloatEdit(
        tokenName: String,
        oldValue: Double,
        newValue: Double,
        lines: [String],
        file: URL
    ) throws -> WriteBackPlan.Edit? {
        let leaf = leafName(tokenName)
        // Pattern: `static let <leaf>: CGFloat = <literal>`
        let pattern = "\\blet\\s+\(NSRegularExpression.escapedPattern(for: leaf))\\s*:\\s*CGFloat\\s*=\\s*[\\d.]+"

        guard let (lineIndex, oldLine) = findLine(matching: pattern, in: lines) else {
            throw WriteBackError.tokenMissingFromSource(name: tokenName)
        }

        let newValue_str = formatDouble(newValue)
        // Replace the numeric literal at the end of the assignment
        let newLine = replaceLastNumberLiteral(in: oldLine, with: newValue_str)
        guard newLine != oldLine else { return nil }

        let lineNumber = lineIndex + 1  // 1-based
        return WriteBackPlan.Edit(
            file: file,
            lineRange: lineNumber..<(lineNumber + 1),
            oldContent: oldLine,
            newContent: newLine
        )
    }

    /// Build an edit for a `.dynamic(light:dark:)` color token.
    /// The declaration spans multiple lines (multi-line block). We locate the entire block
    /// and replace the two NSColor literal arms.
    private func makeDynamicColorEdit(
        token: ColorToken,
        oldLight: RGBAValue, oldDark: RGBAValue,
        newLight: RGBAValue, newDark: RGBAValue,
        lines: [String],
        file: URL
    ) throws -> WriteBackPlan.Edit? {
        let leaf = leafName(token.name)

        // Find the header line of the dynamic color property
        let headerPattern = "\\bvar\\s+\(NSRegularExpression.escapedPattern(for: leaf))\\s*:\\s*Color\\b"
        guard let (headerIndex, _) = findLine(matching: headerPattern, in: lines) else {
            throw WriteBackError.tokenMissingFromSource(name: token.name)
        }

        // Collect the full block (from header through matching closing brace)
        let (blockLines, blockRange) = collectBlock(startingAt: headerIndex, in: lines)
        let blockText = blockLines.joined(separator: "\n")

        // Identify and replace the NSColor expressions for light and dark arms.
        // We do two replacements: first occurrence = light, second = dark.
        guard let newBlockText = replaceDynamicColorArms(
            in: blockText,
            oldLight: oldLight, oldDark: oldDark,
            newLight: newLight, newDark: newDark
        ) else {
            return nil
        }

        guard newBlockText != blockText else { return nil }

        let startLine = blockRange.lowerBound + 1  // 1-based
        let endLine   = blockRange.upperBound       // inclusive 1-based
        return WriteBackPlan.Edit(
            file: file,
            lineRange: startLine..<(endLine + 1),
            oldContent: blockText,
            newContent: newBlockText
        )
    }

    /// Build an edit for a typography token (size literal only for now).
    private func makeTypographyEdit(
        token: TypographyToken,
        orig: TypographyToken,
        newSize: Double,
        lines: [String],
        file: URL
    ) throws -> WriteBackPlan.Edit? {
        let leaf = leafName(token.name)
        // Pattern: `static let <leaf>: Font = ...`
        let pattern = "\\blet\\s+\(NSRegularExpression.escapedPattern(for: leaf))\\s*:\\s*Font\\s*="

        guard let (lineIndex, oldLine) = findLine(matching: pattern, in: lines) else {
            throw WriteBackError.tokenMissingFromSource(name: token.name)
        }

        var newLine = oldLine

        // Replace size: N
        if let origSize = orig.size, origSize != newSize {
            let sizePattern = "(size:\\s*)\(regexLiteralDouble(origSize))"
            let newSizeStr  = formatDouble(newSize)
            newLine = replaceFirst(pattern: sizePattern, in: newLine, with: "$1\(newSizeStr)")
        }

        // Replace weight: .X if changed
        if token.weight != orig.weight {
            let wPattern = "(weight:\\s*\\.)\(NSRegularExpression.escapedPattern(for: orig.weight))"
            newLine = replaceFirst(pattern: wPattern, in: newLine, with: "$1\(token.weight)")
        }

        // Replace design: .X if changed
        if token.design != orig.design {
            let dPattern = "(design:\\s*\\.)\(NSRegularExpression.escapedPattern(for: orig.design))"
            newLine = replaceFirst(pattern: dPattern, in: newLine, with: "$1\(token.design)")
        }

        guard newLine != oldLine else { return nil }

        let lineNumber = lineIndex + 1
        return WriteBackPlan.Edit(
            file: file,
            lineRange: lineNumber..<(lineNumber + 1),
            oldContent: oldLine,
            newContent: newLine
        )
    }

    // MARK: - Block collection

    /// Collect a multi-line `{ ... }` block starting at `startIndex`.
    /// Returns (lines, 0-based range) where range.upperBound is inclusive.
    private func collectBlock(startingAt startIndex: Int, in lines: [String]) -> ([String], Range<Int>) {
        var depth = 0
        var i = startIndex
        while i < lines.count {
            let line = lines[i]
            depth += line.filter { $0 == "{" }.count
            depth -= line.filter { $0 == "}" }.count
            if depth == 0 && i > startIndex {
                return (Array(lines[startIndex...i]), startIndex..<i)
            }
            i += 1
        }
        // Fallback: single line
        return ([lines[startIndex]], startIndex..<startIndex)
    }

    // MARK: - NSColor arm replacement for dynamic colors

    private func replaceDynamicColorArms(
        in blockText: String,
        oldLight: RGBAValue, oldDark: RGBAValue,
        newLight: RGBAValue, newDark: RGBAValue
    ) -> String? {
        // Collect all NSColor expression ranges in the block.
        // We process light (first occurrence) and dark (second occurrence).
        let nsColorPattern = "NSColor(?:\\([^)]+\\)|\\.(?:black|white)\\.withAlphaComponent\\([\\d.]+\\))"
        guard let regex = try? NSRegularExpression(pattern: nsColorPattern) else { return nil }
        let ns = blockText as NSString
        let matches = regex.matches(in: blockText, range: NSRange(location: 0, length: ns.length))
        guard matches.count >= 2 else { return nil }

        // Replace in reverse order to preserve offsets
        var result = blockText
        let lightRange = Range(matches[0].range, in: blockText)
        let darkRange  = Range(matches[1].range, in: blockText)

        guard let lr = lightRange, let dr = darkRange else { return nil }

        // Only replace if the value actually changed
        var changed = false
        if newDark != oldDark {
            let oldDarkStr = String(result[dr])
            let newDarkStr = buildNSColorExpr(for: newDark, matching: oldDarkStr)
            result.replaceSubrange(dr, with: newDarkStr)
            changed = true
        }
        // Re-compute light range in possibly-modified string
        if newLight != oldLight {
            // Since we modified at darkRange (which is after lightRange), lr is still valid
            let oldLightStr = String(result[lr])
            let newLightStr = buildNSColorExpr(for: newLight, matching: oldLightStr)
            result.replaceSubrange(lr, with: newLightStr)
            changed = true
        }

        return changed ? result : nil
    }

    /// Construct the replacement NSColor expression, preserving the same form as the original.
    private func buildNSColorExpr(for rgba: RGBAValue, matching original: String) -> String {
        if original.hasPrefix("NSColor.black") {
            return "NSColor.black.withAlphaComponent(\(formatDouble(rgba.a)))"
        }
        if original.hasPrefix("NSColor.white") {
            return "NSColor.white.withAlphaComponent(\(formatDouble(rgba.a)))"
        }
        // calibratedWhite form: r==g==b
        if original.contains("calibratedWhite") {
            return "NSColor(calibratedWhite: \(formatDouble(rgba.r)), alpha: \(formatDouble(rgba.a)))"
        }
        // calibratedRed form
        return "NSColor(calibratedRed: \(formatDouble(rgba.r)), green: \(formatDouble(rgba.g)), blue: \(formatDouble(rgba.b)), alpha: \(formatDouble(rgba.a)))"
    }

    // MARK: - Line search helpers

    /// Find the first line matching the given regex pattern.
    /// Returns (0-based index, line string) or nil.
    private func findLine(matching pattern: String, in lines: [String]) -> (Int, String)? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        for (i, line) in lines.enumerated() {
            let ns = line as NSString
            if regex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) != nil {
                return (i, line)
            }
        }
        return nil
    }

    /// Replace the last numeric literal on the line with a new value string.
    private func replaceLastNumberLiteral(in line: String, with replacement: String) -> String {
        let pattern = "[\\d.]+(?=[^\\d.]*$)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return line }
        let ns = line as NSString
        guard let match = regex.lastMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return line }
        return ns.replacingCharacters(in: match.range, with: replacement)
    }

    // MARK: - Number formatting

    /// Format a Double as a Swift literal, using integer form when the value is whole.
    func formatDouble(_ v: Double) -> String {
        if v.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(v))
        }
        // Trim trailing zeros but keep at least one decimal digit
        var s = String(format: "%g", v)
        // If no decimal point present, it's already compact
        if !s.contains(".") { s += "" }
        return s
    }

    /// Build a regex pattern that matches the literal form of a Double.
    private func regexLiteralDouble(_ v: Double) -> String {
        // Match either "12" or "12.0" or "12.5" etc.
        let formatted = formatDouble(v)
        return NSRegularExpression.escapedPattern(for: formatted)
    }

    private func replaceFirst(pattern: String, in string: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return string }
        let ns    = string as NSString
        let range = NSRange(location: 0, length: ns.length)
        return regex.stringByReplacingMatches(in: string, range: range, withTemplate: replacement)
    }
}

// MARK: - TokenProtocol (internal)

private protocol TokenProtocol {
    var name: String { get }
    var surface: String { get }
}

extension ColorToken:       TokenProtocol {}
extension SpacingToken:     TokenProtocol {}
extension TypographyToken:  TokenProtocol {}
extension CornerRadiusToken: TokenProtocol {}

// MARK: - NSRegularExpression lastMatch helper

extension NSRegularExpression {
    func lastMatch(in string: String, range: NSRange) -> NSTextCheckingResult? {
        let all = matches(in: string, range: range)
        return all.last
    }
}

// MARK: - runExtraction shim

// We import the extractor core library so WriteBackEngine can call runExtraction.
import ColorAnimaDesignStudioExtractorCore

// MARK: - WriteBackOperation extraction helper

extension WriteBackOperation {
    /// Re-extract the current token manifest from source files at `sourcesRoot`.
    /// `sourcesRoot` must be the directory that contains
    /// `ColorAnimaAppWorkspaceDesignSystem/` as a direct child.
    public static func extractManifest(sourcesRoot: URL) throws -> TokenManifest {
        let data = try runExtraction(sourcesRoot: sourcesRoot)
        return try JSONDecoder().decode(TokenManifest.self, from: data)
    }
}
