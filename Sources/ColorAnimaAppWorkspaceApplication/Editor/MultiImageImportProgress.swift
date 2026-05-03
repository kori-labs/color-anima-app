import Foundation
import Observation

@MainActor
@Observable
public final class MultiImageImportProgress {
    public private(set) var total: Int = 0
    public private(set) var decoded: Int = 0
    public private(set) var failed: Int = 0
    public private(set) var committed: Int = 0
    public private(set) var firstDecodedURL: URL?

    public init() {}

    public func beginRun(total: Int) {
        guard total > 0 else {
            assertionFailure("beginRun(total:) requires a positive total, got \(total)")
            return
        }
        self.total = total
        self.decoded = 0
        self.failed = 0
        self.committed = 0
        self.firstDecodedURL = nil
    }

    public func recordDecoded(url: URL) {
        decoded += 1
        if firstDecodedURL == nil {
            firstDecodedURL = url
        }
    }

    public func recordFailed() {
        failed += 1
    }

    public func recordCommitted(count: Int) {
        guard count >= 0 else {
            assertionFailure("recordCommitted(count:) requires a non-negative count, got \(count)")
            return
        }
        committed = min(total, committed + count)
    }

    public var isIdle: Bool { total == 0 }
}
