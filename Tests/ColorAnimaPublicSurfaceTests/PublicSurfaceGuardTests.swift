// PublicSurfaceGuardTests.swift
//
// Design: Option A — hash-based denylist (RED-TEAM-AUDIT Channel I closure).
//
// The original implementation stored forbidden vocabulary as plaintext strings
// (even via string-concatenation tricks), which published the denylist itself
// to the public source tree — the textbook "denylist self-disclosure" antipattern.
//
// This redesign replaces the plaintext list with pre-computed SHA-256 hashes of
// the forbidden tokens. The test tokenises every identifier-like substring in
// each scanned file and rejects any token whose SHA-256 (original casing OR
// lowercased) matches an entry in the hash set. The public source tree contains
// hashes only; the original vocabulary list is maintained in maintainer-private
// notes (core repository, not this public mirror).
//
// Maintainer note: to update the denylist (add / remove terms), recompute
// SHA-256 of the new term in both original casing and all-lowercase, add both
// hex strings to `forbiddenTokenHashes`, and remove any obsolete pairs.
// The count of hash pairs intentionally reflects the count of protected terms.

import XCTest
import CryptoKit
import Foundation

final class PublicSurfaceGuardTests: XCTestCase {

    // MARK: - Hash-based denylist
    //
    // Each entry is SHA-256(utf-8 bytes of a forbidden identifier token).
    // Pre-computed token hashes. Order is not significant; entries are an
    // unordered set.
    private let forbiddenTokenHashes: Set<String> = [
        "5958dbf74b5c736f19e543e1ac7b413dab7a288ae9ae6a66bed1bb88d19290c0",
        "c5d80bd1ae78e01012296adf2cc409a333a66fe1987ca32b6e5cc31a903555e3",
        "9b1b9d9a4a851170e89d6a4ace822032fd1bd081adb9559bfdf4e4e0faa0b38c",
        "ecf7aedf15ee511d27e0f4389868fe7b5011bc8a65c9f9427d49f17d1ae0d40f",
        "b92f63c931080c86fe72694aae5433e24a138e3407da39675eea5ac04bd5839c",
        "fcc2bb246960a7445ffd3dcfc4b04dcceef7db8455fda2d864e0391b6648420c",
        "31c4c57cce967435d0606eb669d0066708e40888594ceb1af8df7e27f49950c4",
        "e9691149f24c95acd253437a8b4b50bd4c024fb6d077f2db02a3833e5818e2bb",
        "27683feb0a626ad50e74e790e74379442fbee462ca66c2ea85798574d1247a4e",
        "8657d13aa757571d32c07eceaed7d1c86c13266e7dd7741db308e7faf2160b62",
        "723ff00cd01b8d612221317e606d012da53d3e8c770e6c76a959ae345e1f6448",
        "72cf436ee951d783fedb3fd240d9a5efe1795e19fd10a2735842f499c3ffa2df",
        "f0e2556a7383e91ce9d1c37e69ae8ec5b2eb360e52294c5c5bbe7beedf687650",
        "a690638732aaa46bc7e6648a287b0c27b51285531cb8fba797ba68d6363d493c",
        "d83ac979765841dd36f7c13ee22086fe38e94fe01151b53dc4de7a37c7c366f2",
        "b919830f728b33eafb5686950c758b9aae2c1f4bab670b7a0575ed05b81a350f",
        "529067aab6d516ce8f88d39eb90856d4e7d8e0f92be836878b1179d9ee3770d7",
        "07d38389c1e323fc7ed0b882d96c6c2f009c578c51822522e22b217c271f9fb0",
        "52c8d408e9da970319c79c0dfb2d04037f47f7f930fb297aa7db8d82e5289ee3",
        "085be2362686a0d136ebb85a2bc91182128c339a3b1d842e7d91d1f8dd1e18da",
        "d57c82ed7d20e41ec61111a6d08c728e467d000cf14cf485c12fb39ffb690833",
        "0a0cdcdc87bd8b05f2c979a7c3f74b0c0046ac4b2dfb77c2bbf670f435c635bc",
        "d745a77e05571fb42462814308c3d11282608029ac7fcd23696985725827868c",
        "7983f8bf7a48c7e4f285649dc11a1c82127ff0b79c40f207096cb4a07e30b626",
        "b5bf9b2af72ac1fffb613b80049464da50099939c3ad69a9d0b0b52a5fe4a97d",
        "049fbfa21acdaf2d132e157e4c805cb475022faf5fb812444b9494ccb4c896d4",
        "950a78ff448bbd2f5c52e6f7e92c77e4a508ff027b10956f4584952aa746246e",
        "feb294a90826d730956f8a5bea427ee363173740fc14e0d21f9aa72e57c5bfd4",
        "d2527051abeff1a884eca0addb659a7b6c9b8d74e1759e8af7c7844c27cd862a",
        "b109b3e390b04a3734dcb27fda4aa309483fccb130303fff056553b5fe72ec98",
        "58801e6907f0ab9dfdb8c867f98ccf2e35463c1b1acd55f556ed290fd4ce6603",
        "4356463e3e0aa70be4ee3f5edda8dd2c77cada6a1a963cedeb54a32a2485a5ba",
        "cbf4df3f183f8e6aaa6a4b9f7f2cc0764dfba1942f710b219e7c522cc45254ed",
        "dd88d7a39c85718596ec7adadc19766b0af354e41f9c8646ccb00c360575c76d",
        "a0cd85c23871b4798b27f2ee52d18d2759d6c950a75c118d5daa26e0c3707b65",
        "8a6498e1df57fc3b71d794d8bed150a8c35fd57de6bff4b5c7e1f8ea42066656",
        "e5f3780d896dc2154485f779b0265bccd39e0079a4b99794251c36815a395887",
        "e40848ee4893073a65941c350cf9a7262ed988a6faed3126c0caf7574d66ab69",
        "ec99baaaa15b81ed59861f0666caca1cb7b8bdf07abf87a9893636bc9900cc7a",
        "92ae1bb7565bb8198bc0ba834a10f313b42902dd47bc9d236be44d992e8ede78",
        "29846d322ce8d5fe6c39afbd839b86dd8a0c2a5c05492f136bf105b87770219a",
        "2b4beb6878b42e5b073c74552b1a5501999ffdefe1da1c460227427bea86b092",
        "4cb5f1e458ddf6162a230aa5dc7eba17b72f3f998676b5fb043f6b240b1c3173",
        "a26ea51cb6950777b2295324b711dc735ce88816af2cc1b277b11ca4a1e74f5c",
        "4af5fc3ffbc31c6985269150ec9fa3794f35231f8355b65affe857ac04fe4567",
        "7588f09c94e6c86a351ff8e3267248c72f1429d1a0c37d6ab1f45b6c410cd34e",
        "716471ea07728d054b4e548b349cb5ebaddc946f948960551189774d439a70a5",
        "cee0896a594077d595b81f8bead24209f4bde3ff60d11e1a94e28c982388073a",
        "6f3768f0743be877738b5b671d2c127d60e4cc858a8d80529309a736c7884b31",
        "2685fd137eab0d638aefaa50d99a70c41f10b1719829f775f542ac84f329904a",
        "39b8b1d1ac152a536b40fbc9a64a90058e6e496924380632f048ff8f6b5ef167",
        "16acc6efd50688c2e9a9f71bc1fc6809495c7a002ed305e4dcc13e64dc5b2b77",
        "907bd55edad5608ca30e199fa506a8f612433963938f95a8d562d34bd9aeb1f7",
        "aaa2df9ff25b7e3d3e916c61175e69f40eab44432647cb0eba3fa78df94d9d02",
    ]

    // MARK: - Forbidden manifest path hashes
    //
    // Pre-computed manifest path hashes.
    private let forbiddenManifestPathHashes: Set<String> = [
        "79fae57e413147530575b70a597d2ebb76f6850d363c9036ae287f74bf31bc37",
        "f642d12bb61c795d742fefb2f5e8ce78564f1041b51aebbea0731130af2777be",
        "bf6a06956c552359c9508bcfa8c36ee99ca3add1518a85febf1b960b954dc4e4",
        "7199758bdc0438982472f76006b032a60be74efdf935ef5f19bd815ad66c2077",
        "9ae61f03a0e61cab196cf808a0429c4568c667032e961831c1cac743ac071b7b",
    ]

    // MARK: - Tests

    func testPublicSurfacesDoNotExposePrivateKernelTerms() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sourceRoots = [
            root.appending(path: "Package.swift"),
            root.appending(path: "Sources"),
            root.appending(path: "Tests"),
            root.appending(path: "docs/migration"),
        ]

        let files = try sourceRoots.flatMap { try textFiles(under: $0) }
        XCTAssertFalse(files.isEmpty, "Expected at least one text file to scan")

        var violations: [String] = []
        for file in files {
            let contents = try String(contentsOf: file, encoding: .utf8)
            let hitTokens = forbiddenTokensFound(in: contents)
            for token in hitTokens {
                violations.append("\(file.path): token hash match (token length \(token.count))")
            }
        }

        XCTAssertTrue(violations.isEmpty, "Forbidden vocabulary detected:\n" + violations.joined(separator: "\n"))
    }

    func testPackageManifestDoesNotReferenceSourceFallbackTargets() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let manifest = try String(
            contentsOf: root.appending(path: "Package.swift"),
            encoding: .utf8
        )

        // Extract all path: "..." values from the manifest and check their hashes.
        // Regex captures the path string value inside path: "..."
        let pathPattern = #/path:\s*"([^"]+)"/#
        var violations: [String] = []
        for match in manifest.matches(of: pathPattern) {
            let pathValue = String(match.output.1)
            let digest = SHA256.hash(data: Data(pathValue.utf8))
            let hex = digest.map { String(format: "%02x", $0) }.joined()
            if forbiddenManifestPathHashes.contains(hex) {
                violations.append("Forbidden source target path reference detected in Package.swift (hash: \(hex))")
            }
        }

        XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))
    }

    // MARK: - Helpers

    /// Returns all identifier-like tokens in `text` that match a forbidden hash.
    private func forbiddenTokensFound(in text: String) -> [Substring] {
        // Tokenise by permissive identifier pattern: letter followed by letters, digits, underscores.
        let pattern = /[A-Za-z][A-Za-z0-9_]+/
        var hits: [Substring] = []
        for match in text.matches(of: pattern) {
            let token = match.output
            // Check original casing.
            let origDigest = SHA256.hash(data: Data(token.utf8))
            let origHex = origDigest.map { String(format: "%02x", $0) }.joined()
            if forbiddenTokenHashes.contains(origHex) {
                hits.append(token)
                continue
            }
            // Check lowercase variant.
            let lower = token.lowercased()
            let lowerDigest = SHA256.hash(data: Data(lower.utf8))
            let lowerHex = lowerDigest.map { String(format: "%02x", $0) }.joined()
            if forbiddenTokenHashes.contains(lowerHex) {
                hits.append(token)
            }
        }
        return hits
    }

    private func textFiles(under url: URL) throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return []
        }
        guard isDirectory.boolValue else {
            return isTextFile(url) ? [url] : []
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return try enumerator.compactMap { item in
            guard let file = item as? URL, isTextFile(file) else {
                return nil
            }
            let values = try file.resourceValues(forKeys: [.isRegularFileKey])
            return values.isRegularFile == true ? file : nil
        }
    }

    private func isTextFile(_ url: URL) -> Bool {
        switch url.pathExtension {
        case "md", "swift", "tsv", "yml", "yaml":
            return true
        default:
            return false
        }
    }
}
