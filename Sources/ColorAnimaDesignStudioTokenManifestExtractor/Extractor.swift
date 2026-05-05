// ColorAnimaDesignStudioTokenManifestExtractor/Extractor.swift
//
// Supported declaration patterns (regex-based line scanner):
//
// SPACING:
//   static let <name>: CGFloat = <literal>
//   static let <name>: CGFloat = <aliasName>   (alias resolved)
//
// CORNER RADIUS (name contains "CornerRadius", "Radius", or "Height"):
//   static let <name>: CGFloat = <literal>
//
// COLOR:
//   Single-line: static var <name>: Color { <value> }
//   Multi-line:  static var <name>: Color { \n   <dynamicColor call> \n }
//
// TYPOGRAPHY:
//   static let <name>: Font = <value>
//
// Intentionally skipped:
//   - private declarations
//   - func / init declarations
//   - NSColor properties
//   - Material properties

import Foundation
import ColorAnimaDesignStudioTokenManifest

// MARK: - Public API

/// Run extraction against the given source root. Returns the JSON data.
/// Exposed as public so tests can call it directly.
public func runExtraction(sourcesRoot: URL) throws -> Data {
    let designSystemRoot = sourcesRoot.appendingPathComponent(
        "ColorAnimaAppWorkspaceDesignSystem", isDirectory: true
    )

    let sourceFiles: [(file: String, surface: String)] = [
        ("WorkspaceFoundation.swift",            "WorkspaceFoundation"),
        ("WorkspaceChromeStyle.swift",           "WorkspaceChromeStyle"),
        ("WorkspaceChromeStyle+ProjectTree.swift","WorkspaceChromeStyle"),
        ("WorkspaceChromeAppearance.swift",      "WorkspaceChromeAppearance"),
        ("ChromePrimitives.swift",               "ChromePrimitives"),
        ("HoverDeleteConfirmButton.swift",       "HoverDeleteConfirmButton"),
        ("InlineRenameField.swift",              "InlineRenameField"),
    ]

    var allColors: [ColorToken] = []
    var allSpacing: [SpacingToken] = []
    var allTypography: [TypographyToken] = []
    var allCornerRadii: [CornerRadiusToken] = []

    for (fileName, surface) in sourceFiles {
        let url = designSystemRoot.appendingPathComponent(fileName)
        let source = try String(contentsOf: url, encoding: .utf8)
        let result = try extractTokens(from: source, fileName: fileName, surface: surface)
        allColors.append(contentsOf: result.colors)
        allSpacing.append(contentsOf: result.spacing)
        allTypography.append(contentsOf: result.typography)
        allCornerRadii.append(contentsOf: result.cornerRadii)
    }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    let manifest = TokenManifest(
        schemaVersion: 1,
        extractedAt: formatter.string(from: Date()),
        colors: allColors,
        spacing: allSpacing,
        typography: allTypography,
        cornerRadii: allCornerRadii
    )

    return try encodeManifest(manifest)
}

// MARK: - JSON encoding (deterministic)

func encodeManifest(_ manifest: TokenManifest) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(manifest)
    // Ensure single trailing newline
    while data.last == UInt8(ascii: "\n") { data.removeLast() }
    data.append(UInt8(ascii: "\n"))
    return data
}

// MARK: - Per-file extraction

struct ExtractionResult {
    var colors: [ColorToken] = []
    var spacing: [SpacingToken] = []
    var typography: [TypographyToken] = []
    var cornerRadii: [CornerRadiusToken] = []
}

func extractTokens(from source: String, fileName: String, surface: String) throws -> ExtractionResult {
    var result = ExtractionResult()

    // Step 1: collapse multi-line Color block bodies so each declaration is on one logical line
    let collapsed = collapseMultilineBlocks(source)
    let lines = collapsed.components(separatedBy: "\n")

    // Step 2: build per-line namespace map using brace depth
    // Each element records the brace depth at the START of that line,
    // and the namespace stack active at that point.
    var namespaceAtLine: [String] = Array(repeating: "", count: lines.count)
    buildNamespaceMap(lines: lines, surface: surface, out: &namespaceAtLine)

    // Step 3: scan each line for token declarations
    for (i, rawLine) in lines.enumerated() {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        let prefix = namespaceAtLine[i]

        // Skip obvious non-declarations
        if line.isEmpty || line.hasPrefix("//") || line.hasPrefix("import ") { continue }
        if line.hasPrefix("private ") { continue }
        if line.hasPrefix("@") { continue }
        if isMethodOrTypeDeclaration(line) { continue }

        // ---- CGFloat spacing / corner-radius ----
        if let (name, value) = matchCGFloatLiteral(line) {
            let qualified = join(prefix, name)
            if isCornerOrHeight(name) {
                result.cornerRadii.append(CornerRadiusToken(name: qualified, surface: surface, value: value))
            } else {
                result.spacing.append(SpacingToken(name: qualified, surface: surface, value: value))
            }
            continue
        }
        if let (name, value) = matchCGFloatAlias(line) {
            let qualified = join(prefix, name)
            result.spacing.append(SpacingToken(name: qualified, surface: surface, value: value))
            continue
        }

        // ---- Typography ----
        if let typo = matchTypography(line, prefix: prefix, surface: surface) {
            result.typography.append(typo)
            continue
        }

        // ---- Color ----
        if let color = matchColor(line, prefix: prefix, surface: surface) {
            result.colors.append(color)
            continue
        }
    }

    return result
}

// MARK: - Multi-line block collapsing

/// Collapse multi-line property blocks onto a single line.
/// Only collapses properties whose opening `{` is at the end of the header line
/// and the body ends with a matching `}`.
func collapseMultilineBlocks(_ source: String) -> String {
    let lines = source.components(separatedBy: "\n")
    var out: [String] = []
    out.reserveCapacity(lines.count)
    var i = 0

    while i < lines.count {
        let line = lines[i]
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // A declaration header that opens a block but whose body is on the next line(s)
        // Criteria: ends with `{`, contains `static var` or `static let`,
        // and the rest of the line after `{` is empty (no inline value)
        if isMultilineBlockHeader(trimmed) {
            var collected = line
            // Count net brace depth contribution of this first line
            var depth = netBraces(line)
            var j = i + 1
            while j < lines.count && depth > 0 {
                let next = lines[j]
                let content = next.trimmingCharacters(in: .whitespaces)
                if !content.isEmpty {
                    collected += " " + content
                }
                depth += netBraces(next)
                j += 1
            }
            out.append(collected)
            i = j
        } else {
            out.append(line)
            i += 1
        }
    }

    return out.joined(separator: "\n")
}

func netBraces(_ line: String) -> Int {
    line.filter { $0 == "{" }.count - line.filter { $0 == "}" }.count
}

func isMultilineBlockHeader(_ trimmed: String) -> Bool {
    guard trimmed.hasSuffix("{") else { return false }
    guard trimmed.contains("static var") || trimmed.contains("static let") else { return false }
    // The `{` should be the LAST character — meaning the body starts on the next line
    // Also must not be a type declaration (enum/struct/class/extension)
    if trimmed.hasPrefix("enum ") || trimmed.hasPrefix("struct ") ||
       trimmed.hasPrefix("class ") || trimmed.hasPrefix("extension ") ||
       trimmed.hasPrefix("package enum ") || trimmed.hasPrefix("package struct ") {
        return false
    }
    // If there's content after `{` (besides whitespace), it's single-line already
    // Since trimmed ends with `{`, there's nothing after it — safe to collapse
    return true
}

// MARK: - Namespace map builder

func detectScopeDeclaration(_ trimmed: String) -> String? {
    // Only enum and extension declarations create meaningful namespace scopes
    // (struct/class bodies also do, but in these files they are not token namespaces)
    let patterns = [
        #"^(?:package\s+)?enum\s+(\w+)"#,
        #"^extension\s+(\w+)"#,
    ]
    for p in patterns {
        if let name = firstCapture(p, in: trimmed) { return name }
    }
    return nil
}

struct NamespaceEntry {
    let name: String
    let openDepth: Int
}

func stackToPrefix(_ stack: [NamespaceEntry], surface: String) -> String {
    let names = stack.map { $0.name }
    if names.isEmpty { return surface }
    if names.first == surface {
        return names.joined(separator: ".")
    }
    return ([surface] + names).joined(separator: ".")
}

func buildNamespaceMap(lines: [String], surface: String, out: inout [String]) {
    var stack: [NamespaceEntry] = []
    var depth = 0

    for (i, rawLine) in lines.enumerated() {
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

        // Record current namespace before processing this line's braces
        out[i] = stackToPrefix(stack, surface: surface)

        // Detect a new scope opening on this line
        if let scopeName = detectScopeDeclaration(trimmed) {
            stack.append(NamespaceEntry(name: scopeName, openDepth: depth))
        }

        let opens = rawLine.filter { $0 == "{" }.count
        let closes = rawLine.filter { $0 == "}" }.count
        depth += opens - closes

        // Pop scopes that have been closed (their openDepth >= current depth)
        stack = stack.filter { $0.openDepth < depth }
    }
}

func join(_ prefix: String, _ name: String) -> String {
    prefix.isEmpty ? name : "\(prefix).\(name)"
}

// MARK: - Token declaration matchers

func isMethodOrTypeDeclaration(_ line: String) -> Bool {
    if line.contains("func ") { return true }
    if line.hasPrefix("init(") || line.contains(" init(") { return true }
    if line.hasPrefix("struct ") || line.hasPrefix("class ") || line.hasPrefix("protocol ") { return true }
    if line.hasPrefix("package struct ") || line.hasPrefix("package class ") { return true }
    return false
}

// MARK: - CGFloat matchers

func matchCGFloatLiteral(_ line: String) -> (String, Double)? {
    let pattern = #"^(?:package\s+)?static\s+let\s+(\w+)\s*:\s*CGFloat\s*=\s*([\d.]+)"#
    guard let name = firstCapture(pattern, in: line),
          let valStr = nthCapture(2, pattern: pattern, in: line),
          let value = Double(valStr) else { return nil }
    return (name, value)
}

func matchCGFloatAlias(_ line: String) -> (String, Double)? {
    let pattern = #"^(?:package\s+)?static\s+let\s+(\w+)\s*:\s*CGFloat\s*=\s*([a-zA-Z]\w*)"#
    guard let name = firstCapture(pattern, in: line),
          let ref = nthCapture(2, pattern: pattern, in: line),
          let value = resolveSpacingAlias(ref) else { return nil }
    return (name, value)
}

func resolveSpacingAlias(_ name: String) -> Double? {
    switch name {
    case "space1":   return 4
    case "space2":   return 8
    case "space2_5": return 10
    case "space3":   return 12
    case "space3_5": return 14
    case "space4":   return 16
    case "space5":   return 20
    case "space6":   return 24
    case "space7":   return 28
    default:         return nil
    }
}

func isCornerOrHeight(_ name: String) -> Bool {
    let lower = name.lowercased()
    return lower.contains("cornerradius") || lower.contains("radius") || lower.contains("height")
}

// MARK: - Typography matcher

func matchTypography(_ line: String, prefix: String, surface: String) -> TypographyToken? {
    guard line.contains(": Font") || line.contains("Font =") else { return nil }
    let pattern = #"^(?:package\s+)?static\s+let\s+(\w+)\s*:\s*Font\s*=\s*(.+)"#
    guard let name = firstCapture(pattern, in: line),
          let rhs = nthCapture(2, pattern: pattern, in: line) else { return nil }
    let qualified = join(prefix, name)
    return parseTypographyRHS(rhs.trimmingCharacters(in: .whitespaces), name: qualified, surface: surface)
}

func parseTypographyRHS(_ rhs: String, name: String, surface: String) -> TypographyToken? {
    let named: Set<String> = ["body","callout","caption","subheadline","headline",
                               "title","footnote","largeTitle","title2","title3"]
    // .X.weight(.Y)
    if let base = firstCapture(#"^\.(\w+)\.weight\(\.(\w+)\)"#, in: rhs),
       let wt   = nthCapture(2, pattern: #"^\.(\w+)\.weight\(\.(\w+)\)"#, in: rhs) {
        return TypographyToken(name: name, surface: surface, size: nil, weight: wt, design: "default", systemFont: base)
    }
    // .X.monospacedDigit()
    if let base = firstCapture(#"^\.(\w+)\.monospacedDigit\(\)"#, in: rhs) {
        return TypographyToken(name: name, surface: surface, size: nil, weight: "regular", design: "monospaced", systemFont: base)
    }
    // .body / .callout etc.
    if rhs.hasPrefix(".") {
        let cand = String(rhs.dropFirst()).components(separatedBy: CharacterSet.alphanumerics.inverted).first ?? ""
        if named.contains(cand) {
            return TypographyToken(name: name, surface: surface, size: nil, weight: "regular", design: "default", systemFont: cand)
        }
    }
    // Font.system(size: N, weight: .X)
    if let sStr = firstCapture(#"size:\s*([\d.]+)"#, in: rhs), let sz = Double(sStr) {
        let wt = firstCapture(#"weight:\s*\.(\w+)"#, in: rhs) ?? "regular"
        let ds = firstCapture(#"design:\s*\.(\w+)"#, in: rhs) ?? "default"
        return TypographyToken(name: name, surface: surface, size: sz, weight: wt, design: ds, systemFont: nil)
    }
    return nil
}

// MARK: - Color matcher

func matchColor(_ line: String, prefix: String, surface: String) -> ColorToken? {
    // Must be a static var/let — NSColor and Material props are excluded
    guard line.contains("static var") || line.contains("static let") else { return nil }
    guard line.contains(": Color") || line.contains("var ") && line.contains("Color") else { return nil }
    // Exclude NSColor return type
    if line.contains(": NSColor") { return nil }
    // Exclude Material
    if line.contains(": Material") { return nil }

    let namePat = #"^(?:package\s+)?static\s+(?:var|let)\s+(\w+)"#
    guard let name = firstCapture(namePat, in: line) else { return nil }
    let qualified = join(prefix, name)

    guard let cv = parseColorValue(from: line) else { return nil }
    return ColorToken(name: qualified, surface: surface, value: cv)
}

func parseColorValue(from line: String) -> ColorValue? {
    // secondary color with opacity(N)
    if let a = parseOpacityOf(line, base: "Color\\.secondary", baseName: "secondary") { return a }
    // Color(nsColor: .separatorColor).opacity(N)
    if line.contains(".separatorColor") {
        if let aStr = firstCapture(#"separatorColor\)\.opacity\(([\d.]+)\)"#, in: line),
           let a = Double(aStr) { return .opacityOf(base: "separatorColor", alpha: a) }
        if line.contains("separatorColor") && !line.contains(".opacity") {
            return .systemColor("separatorColor")
        }
    }
    // accentColor.opacity(N) / Color.accentColor.opacity(N)
    if let aStr = firstCapture(#"accentColor\.opacity\(([\d.]+)\)"#, in: line),
       let a = Double(aStr) { return .opacityOf(base: "accentColor", alpha: a) }
    // systemRed.opacity(N)
    if line.contains(".systemRed") {
        if let aStr = firstCapture(#"systemRed\b.*?\.opacity\(([\d.]+)\)"#, in: line),
           let a = Double(aStr) { return .opacityOf(base: "systemRed", alpha: a) }
        return .systemColor("systemRed")
    }
    // secondaryLabelColor / tertiaryLabelColor
    if line.contains(".secondaryLabelColor") { return .systemColor("secondaryLabelColor") }
    if line.contains(".tertiaryLabelColor")  { return .systemColor("tertiaryLabelColor") }
    // textBackgroundColor (InlineRenameField)
    if line.contains(".textBackgroundColor") {
        // Color(nsColor: .textBackgroundColor).opacity(N)
        if let aStr = firstCapture(#"textBackgroundColor\)\.opacity\(([\d.]+)\)"#, in: line),
           let a = Double(aStr) { return .opacityOf(base: "textBackgroundColor", alpha: a) }
        if line.contains("textBackgroundColor") { return .systemColor("textBackgroundColor") }
    }
    // Color.accentColor (bare)
    if line.contains("Color.accentColor") && !line.contains(".opacity") { return .systemColor("accentColor") }
    // .primary
    if bodyValue(line, ".primary")   { return .systemColor("primary") }
    // .clear
    if bodyValue(line, ".clear")     { return .systemColor("clear") }
    // .secondary (bare, no .opacity)
    if bodyValue(line, ".secondary") && !line.contains(".opacity") { return .systemColor("secondary") }

    // Cross-references to other token surfaces
    if let ref = extractCrossRef(line) { return .systemColor(ref) }

    // dynamicColor / dynamicNSColor calls (single-line or collapsed multi-line)
    if line.contains("dynamicColor(") || line.contains("dynamicNSColor(") {
        if let (l, d) = parseDynamicArgs(line) { return .dynamic(light: l, dark: d) }
        // Could not parse — return nil (incomplete match, not an error)
        return nil
    }

    // Color(nsColor: dividerNSColor)
    if line.contains("dividerNSColor") { return .systemColor("Shell.dividerNSColor") }

    return nil
}

func parseOpacityOf(_ line: String, base: String, baseName: String) -> ColorValue? {
    let pattern = "\(base)\\.opacity\\(([\\d.]+)\\)"
    guard let aStr = firstCapture(pattern, in: line), let a = Double(aStr) else { return nil }
    return .opacityOf(base: baseName, alpha: a)
}

func bodyValue(_ line: String, _ keyword: String) -> Bool {
    // Matches `{ <keyword>` or `{ <keyword> }` in the body part
    if let r = line.range(of: "{") {
        let after = line[r.upperBound...].trimmingCharacters(in: .whitespaces)
        if after == keyword || after.hasPrefix(keyword + " ") || after.hasPrefix(keyword + "}") { return true }
    }
    if line.hasSuffix("= \(keyword)") || line.contains("= \(keyword) ") { return true }
    return false
}

func extractCrossRef(_ line: String) -> String? {
    // WorkspaceFoundation.X.y or WorkspaceFoundation.X
    if let ref = firstCapture(#"\{\s*(WorkspaceFoundation\.\w+(?:\.\w+)?)\s*(?:\}|$)"#, in: line) {
        // Avoid matching dynamicColor calls
        if !ref.contains("(") { return ref }
    }
    // WorkspaceChromeStyle.X.y
    if let ref = firstCapture(#"\{\s*(WorkspaceChromeStyle\.\w+(?:\.\w+)?)\s*(?:\}|$)"#, in: line) {
        if !ref.contains("(") { return ref }
    }
    // Sidebar.X
    if let ref = firstCapture(#"\{\s*(Sidebar\.\w+)\s*(?:\}|$)"#, in: line) {
        if !ref.contains("(") { return ref }
    }
    // WorkspaceChromeAppearance.X (rare)
    if let ref = firstCapture(#"\{\s*(WorkspaceChromeAppearance\.\w+)\s*(?:\}|$)"#, in: line) {
        if !ref.contains("(") { return ref }
    }
    return nil
}

// MARK: - Dynamic color arg parsing

func parseDynamicArgs(_ block: String) -> (RGBAValue, RGBAValue)? {
    let exprs = collectNSColorExprs(block)
    guard exprs.count >= 2,
          let light = parseNSColorExpr(exprs[0]),
          let dark  = parseNSColorExpr(exprs[1]) else { return nil }
    return (light, dark)
}

func collectNSColorExprs(_ block: String) -> [String] {
    // Combined regex that matches both NSColor(...) and NSColor.black/white.withAlphaComponent(N)
    let combined = #"NSColor(?:\(([^)]+)\)|\.(?:black|white)\.withAlphaComponent\([\d.]+\))"#
    var results: [String] = []
    var search = block.startIndex..<block.endIndex
    while search.lowerBound < block.endIndex,
          let r = block.range(of: combined, options: .regularExpression, range: search) {
        results.append(String(block[r]))
        search = r.upperBound..<block.endIndex
        if results.count == 2 { break }
    }
    return results
}

func parseNSColorExpr(_ s: String) -> RGBAValue? {
    // calibratedWhite: W, alpha: A
    if let wStr = firstCapture(#"calibratedWhite:\s*([\d.]+)"#, in: s),
       let aStr = firstCapture(#"alpha:\s*([\d.]+)"#, in: s),
       let w = Double(wStr), let a = Double(aStr) {
        return RGBAValue(r: w, g: w, b: w, a: a)
    }
    // calibratedRed: R, green: G, blue: B, alpha: A
    if let rStr = firstCapture(#"calibratedRed:\s*([\d.]+)"#, in: s),
       let gStr = firstCapture(#"green:\s*([\d.]+)"#, in: s),
       let bStr = firstCapture(#"blue:\s*([\d.]+)"#, in: s),
       let aStr = firstCapture(#"alpha:\s*([\d.]+)"#, in: s),
       let r = Double(rStr), let g = Double(gStr), let b = Double(bStr), let a = Double(aStr) {
        return RGBAValue(r: r, g: g, b: b, a: a)
    }
    // NSColor.black.withAlphaComponent(N)
    if s.contains("black") {
        if let aStr = firstCapture(#"withAlphaComponent\(([\d.]+)\)"#, in: s), let a = Double(aStr) {
            return RGBAValue(r: 0, g: 0, b: 0, a: a)
        }
    }
    // NSColor.white.withAlphaComponent(N)
    if s.contains("white") {
        if let aStr = firstCapture(#"withAlphaComponent\(([\d.]+)\)"#, in: s), let a = Double(aStr) {
            return RGBAValue(r: 1, g: 1, b: 1, a: a)
        }
    }
    return nil
}

// MARK: - Errors

enum ExtractionError: Error, CustomStringConvertible {
    case unrecognizedPattern(file: String, line: Int, text: String)
    var description: String {
        switch self {
        case let .unrecognizedPattern(file, line, text):
            return "\(file):\(line): unrecognized token pattern: \(text)"
        }
    }
}

// MARK: - Regex helpers

func firstCapture(_ pattern: String, in string: String) -> String? {
    nthCapture(1, pattern: pattern, in: string)
}

func nthCapture(_ n: Int, pattern: String, in string: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
    let ns = string as NSString
    guard let match = regex.firstMatch(in: string, options: [], range: NSRange(location: 0, length: ns.length)),
          match.numberOfRanges > n else { return nil }
    let r = match.range(at: n)
    guard r.location != NSNotFound else { return nil }
    return ns.substring(with: r)
}
