// main.swift — ColorAnimaDesignStudioTokenManifestExtractor
//
// Usage:
//   swift run ColorAnimaDesignStudioTokenManifestExtractor [<sources-root>] [--output <path>]
//
// <sources-root>  Path to the repo's Sources/ directory.
//                 Defaults to $PWD/../Sources relative to the executable,
//                 then falls back to $PWD/Sources, then $PWD.
// --output <path> Write tokens.json to this path instead of stdout.
//                 Common use: --output Sources/ColorAnimaDesignStudioTokenManifest/Resources/tokens.json
//
// Exit codes:
//   0 — success
//   1 — extraction error (message on stderr with filename:line)
//   2 — usage / I/O error

import Foundation
import ColorAnimaDesignStudioTokenManifest

var args = CommandLine.arguments.dropFirst()  // drop executable name

var sourcesRoot: URL? = nil
var outputPath: URL? = nil

var idx = args.startIndex
while idx < args.endIndex {
    let arg = args[idx]
    if arg == "--output" {
        idx = args.index(after: idx)
        guard idx < args.endIndex else {
            fputs("error: --output requires a path argument\n", stderr)
            exit(2)
        }
        outputPath = URL(fileURLWithPath: args[idx])
    } else if arg.hasPrefix("--") {
        fputs("error: unknown flag: \(arg)\n", stderr)
        exit(2)
    } else {
        sourcesRoot = URL(fileURLWithPath: arg)
    }
    idx = args.index(after: idx)
}

// Resolve sources root
if sourcesRoot == nil {
    // Try common locations relative to cwd
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let candidates = [
        cwd.appendingPathComponent("Sources"),
        cwd,
    ]
    for candidate in candidates {
        let designSystem = candidate.appendingPathComponent("ColorAnimaAppWorkspaceDesignSystem")
        if FileManager.default.fileExists(atPath: designSystem.path) {
            sourcesRoot = candidate
            break
        }
    }
}

guard let root = sourcesRoot else {
    fputs("error: could not locate Sources/ColorAnimaAppWorkspaceDesignSystem. Pass the Sources/ path as the first argument.\n", stderr)
    exit(2)
}

do {
    let data = try runExtraction(sourcesRoot: root)
    if let outPath = outputPath {
        // Ensure parent directory exists
        let parent = outPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try data.write(to: outPath)
        fputs("tokens.json written to \(outPath.path) (\(data.count) bytes)\n", stderr)
    } else {
        // Write to stdout
        FileHandle.standardOutput.write(data)
    }
    exit(0)
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}
