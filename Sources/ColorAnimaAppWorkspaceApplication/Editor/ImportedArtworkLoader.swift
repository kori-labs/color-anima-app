import CoreGraphics
import Foundation
import ImageIO

public enum ImportedArtworkLoaderError: LocalizedError, Sendable {
    case failedToCreateImageSource
    case failedToDecodeImage

    public var errorDescription: String? {
        switch self {
        case .failedToCreateImageSource:
            "Could not read the image file."
        case .failedToDecodeImage:
            "Could not decode the image file."
        }
    }
}

public enum ImportedArtworkLoader {
    public static func load(from url: URL) throws -> ImportedArtwork {
        try autoreleasepool {
            let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
                throw ImportedArtworkLoaderError.failedToCreateImageSource
            }
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, sourceOptions) else {
                throw ImportedArtworkLoaderError.failedToDecodeImage
            }
            return ImportedArtwork(url: url, cgImage: cgImage)
        }
    }

    public enum ParallelLoadResult: @unchecked Sendable {
        case success(index: Int, url: URL, artwork: ImportedArtwork)
        case failure(index: Int, url: URL, error: any Error)
    }

    public static var defaultMaxConcurrent: Int {
        let cores = ProcessInfo.processInfo.activeProcessorCount
        return max(1, min(cores, 4))
    }

    public static func loadParallel(
        urls: [URL],
        maxConcurrent: Int? = nil
    ) async -> [ParallelLoadResult] {
        guard urls.isEmpty == false else { return [] }
        let cap = max(1, maxConcurrent ?? defaultMaxConcurrent)

        return await withTaskGroup(of: ParallelLoadResult.self) { group in
            var results: [ParallelLoadResult?] = Array(repeating: nil, count: urls.count)
            var nextIndex = 0
            var inFlight = 0

            while nextIndex < urls.count, inFlight < cap {
                addLoadTask(to: &group, index: nextIndex, url: urls[nextIndex])
                nextIndex += 1
                inFlight += 1
            }

            while let result = await group.next() {
                inFlight -= 1
                results[result.index] = result

                if nextIndex < urls.count {
                    addLoadTask(to: &group, index: nextIndex, url: urls[nextIndex])
                    nextIndex += 1
                    inFlight += 1
                }
            }

            return results.compactMap { $0 }
        }
    }

    private static func addLoadTask(
        to group: inout TaskGroup<ParallelLoadResult>,
        index: Int,
        url: URL
    ) {
        group.addTask {
            do {
                let artwork = try ImportedArtworkLoader.load(from: url)
                return .success(index: index, url: url, artwork: artwork)
            } catch {
                return .failure(index: index, url: url, error: error)
            }
        }
    }
}

private extension ImportedArtworkLoader.ParallelLoadResult {
    var index: Int {
        switch self {
        case let .success(index, _, _), let .failure(index, _, _):
            index
        }
    }
}
