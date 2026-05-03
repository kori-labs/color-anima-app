enum ProjectPlaybackTiming {
    private static let maxFramesPerSecond = 240

    static func resolvedFramesPerSecond(_ framesPerSecond: Int) -> Int {
        min(max(1, framesPerSecond), maxFramesPerSecond)
    }

    static func frameDurationNanoseconds(for framesPerSecond: Int) -> UInt64 {
        let resolvedFramesPerSecond = resolvedFramesPerSecond(framesPerSecond)
        let duration = UInt64(1_000_000_000 / resolvedFramesPerSecond)
        return max(1, duration)
    }
}
