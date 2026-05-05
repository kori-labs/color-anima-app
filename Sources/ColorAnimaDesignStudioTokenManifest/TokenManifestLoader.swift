import Foundation

/// Loads a ``TokenManifest`` from various sources.
public enum TokenManifestLoader {

    // MARK: - Bundled resource

    /// Loads the canonical ``tokens.json`` bundled inside the module.
    ///
    /// The file is embedded at build time via `.process("Resources")` in Package.swift
    /// and is always present when the module is linked.
    public static func bundled() throws -> TokenManifest {
        guard let url = Bundle.module.url(forResource: "tokens", withExtension: "json") else {
            throw LoaderError.bundleResourceNotFound("tokens.json")
        }
        let data = try Data(contentsOf: url)
        return try decode(from: data)
    }

    // MARK: - File URL

    /// Loads a manifest from an arbitrary file URL.
    public static func load(from url: URL) throws -> TokenManifest {
        let data = try Data(contentsOf: url)
        return try decode(from: data)
    }

    // MARK: - Raw data

    /// Decodes a manifest from raw JSON data.
    public static func decode(from data: Data) throws -> TokenManifest {
        let decoder = JSONDecoder()
        return try decoder.decode(TokenManifest.self, from: data)
    }

    // MARK: - Errors

    public enum LoaderError: Error, CustomStringConvertible {
        case bundleResourceNotFound(String)

        public var description: String {
            switch self {
            case let .bundleResourceNotFound(name):
                return "TokenManifestLoader: bundled resource '\(name)' not found in module bundle"
            }
        }
    }
}
