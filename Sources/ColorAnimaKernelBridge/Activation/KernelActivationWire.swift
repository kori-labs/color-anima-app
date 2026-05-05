import Foundation

#if canImport(ColorAnimaKernel)
import ColorAnimaKernel

enum KernelActivationWire {
    struct PropagationResult: Equatable, Sendable {
        let frameResults: [PropagationFrameResult]
        let totalCorrespondenceCount: Int
        let completed: Bool
    }

    struct PropagationFrameResult: Equatable, Sendable {
        let frameID: UUID
        let correspondenceCount: Int
    }

    struct ExtractionResult: Equatable, Sendable {
        let regionCount: Int
    }

    private enum Entry: UInt8 {
        case propagation = 1
        case extraction = 3
    }

    private enum Mode: UInt8 {
        case full = 1
        case bounded = 2
        case extract = 3
    }

    private enum ValueType: UInt8 {
        case u32 = 1
        case u64 = 2
        case f64 = 3
        case bytes = 4
        case group = 5
    }

    private struct Record {
        let tag: UInt16
        let valueType: ValueType
        let value: Data
    }

    private enum Tag {
        static let schemaVersion: UInt16 = 1
        static let canvasWidth: UInt16 = 2
        static let canvasHeight: UInt16 = 3
        static let frame: UInt16 = 16
        static let referenceFrameID: UInt16 = 17
        static let preferredReferenceFrameID: UInt16 = 18
        static let frameWindowStart: UInt16 = 19
        static let frameWindowEnd: UInt16 = 20

        static let frameID: UInt16 = 101
        static let frameOrderIndex: UInt16 = 102
        static let frameRegion: UInt16 = 103

        static let extractAlphaPlane: UInt16 = 401
        static let extractAlphaThreshold: UInt16 = 402
        static let extractMinimumRegionArea: UInt16 = 403

        static let resultStatus: UInt16 = 1001
        static let resultFlags: UInt16 = 1002
        static let resultFrame: UInt16 = 1003
        static let resultFrameID: UInt16 = 1101
        static let resultCorrespondence: UInt16 = 1103
    }

    private static let schemaVersion: UInt32 = 1
    private static let wireMagic: UInt32 = 0x4341_4B57
    private static let wireVersion: UInt16 = 1
    private static let wireHeaderByteCount = 12
    private static let resultFlagCancelled: UInt32 = 1

    static func runFullPropagation(
        frames: [TrackingFrameInput],
        keyFrameIDs: Set<UUID>,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> PropagationResult? {
        guard let canvas = canvas(width: canvasWidth, height: canvasHeight),
              let referenceID = selectReferenceID(
                frames: frames,
                keyFrameIDs: keyFrameIDs
              ),
              let request = propagationRequest(
                frames: frames.map {
                    ActivationFrameInput(
                        frameID: $0.frameID,
                        orderIndex: $0.orderIndex,
                        isKeyFrame: $0.isKeyFrame
                    )
                },
                referenceID: referenceID,
                canvas: canvas,
                mode: .full,
                frameWindow: nil
              ),
              let response = callPropagation(
                request: request,
                canvas: canvas
              )
        else {
            return nil
        }
        return decodePropagationResult(response, mode: .full)
    }

    static func runBoundedPropagation(
        frames: [RegionRewriteFrameInput],
        applyRange: ClosedRange<Int>,
        pinnedFrameIDs: Set<UUID>,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> PropagationResult? {
        guard let canvas = canvas(width: canvasWidth, height: canvasHeight),
              let start = UInt32(exactly: applyRange.lowerBound),
              let end = UInt32(exactly: applyRange.upperBound),
              let referenceID = selectReferenceID(
                frames: frames,
                frameWindow: applyRange,
                preferredFrameIDs: pinnedFrameIDs
              ),
              let request = propagationRequest(
                frames: frames.map {
                    ActivationFrameInput(
                        frameID: $0.frameID,
                        orderIndex: $0.orderIndex,
                        isKeyFrame: $0.isKeyFrame
                    )
                },
                referenceID: referenceID,
                canvas: canvas,
                mode: .bounded,
                frameWindow: (start: start, end: end)
              ),
              let response = callPropagation(
                request: request,
                canvas: canvas
              )
        else {
            return nil
        }
        return decodePropagationResult(response, mode: .bounded)
    }

    static func runExtraction(
        canvasWidth: Int,
        canvasHeight: Int
    ) -> ExtractionResult? {
        guard let canvas = canvas(width: canvasWidth, height: canvasHeight),
              let pixelCount = Int(exactly: UInt64(canvas.width) * UInt64(canvas.height))
        else {
            return nil
        }

        let alphaPlane = Data(repeating: UInt8.max, count: pixelCount)
        guard let request = extractionRequest(alphaPlane: alphaPlane, canvas: canvas),
              let response = callExtraction(request: request, canvas: canvas),
              let regionCount = decodeExtractionRegionCount(response)
        else {
            return nil
        }
        return ExtractionResult(regionCount: regionCount)
    }

    private struct Canvas {
        let width: UInt32
        let height: UInt32
    }

    private struct ActivationFrameInput {
        let frameID: UUID
        let orderIndex: Int
        let isKeyFrame: Bool
    }

    private static func canvas(width: Int, height: Int) -> Canvas? {
        guard let convertedWidth = UInt32(exactly: width),
              let convertedHeight = UInt32(exactly: height),
              convertedWidth > 0,
              convertedHeight > 0
        else {
            return nil
        }
        return Canvas(width: convertedWidth, height: convertedHeight)
    }

    private static func selectReferenceID(
        frames: [TrackingFrameInput],
        keyFrameIDs: Set<UUID>
    ) -> UUID? {
        guard frames.isEmpty == false else { return nil }
        if let matched = frames.first(where: { keyFrameIDs.contains($0.frameID) }) {
            return matched.frameID
        }
        if let keyFrame = frames.first(where: \.isKeyFrame) {
            return keyFrame.frameID
        }
        return frames.first?.frameID
    }

    private static func selectReferenceID(
        frames: [RegionRewriteFrameInput],
        frameWindow: ClosedRange<Int>,
        preferredFrameIDs: Set<UUID>
    ) -> UUID? {
        let windowFrames = frames.filter { frameWindow.contains($0.orderIndex) }
        guard windowFrames.isEmpty == false else { return nil }
        if let matched = windowFrames.first(where: { preferredFrameIDs.contains($0.frameID) }) {
            return matched.frameID
        }
        if let keyFrame = windowFrames.first(where: \.isKeyFrame) {
            return keyFrame.frameID
        }
        return windowFrames.first?.frameID
    }

    private static func propagationRequest(
        frames: [ActivationFrameInput],
        referenceID: UUID,
        canvas: Canvas,
        mode: Mode,
        frameWindow: (start: UInt32, end: UInt32)?
    ) -> Data? {
        guard frames.isEmpty == false else { return nil }

        var records = [
            record(tag: Tag.schemaVersion, u32: schemaVersion),
            record(tag: Tag.canvasWidth, u32: canvas.width),
            record(tag: Tag.canvasHeight, u32: canvas.height),
        ]
        for frame in frames {
            guard let frameRecord = frameRecord(frame) else { return nil }
            records.append(frameRecord)
        }
        records.append(record(tag: Tag.referenceFrameID, bytes: uuidData(referenceID)))
        records.append(record(tag: Tag.preferredReferenceFrameID, bytes: uuidData(referenceID)))
        if let frameWindow {
            records.append(record(tag: Tag.frameWindowStart, u32: frameWindow.start))
            records.append(record(tag: Tag.frameWindowEnd, u32: frameWindow.end))
        }
        guard let body = encodeRecords(records) else { return nil }
        return encodeFrame(entry: .propagation, mode: mode, body: body)
    }

    private static func extractionRequest(alphaPlane: Data, canvas: Canvas) -> Data? {
        let records = [
            record(tag: Tag.schemaVersion, u32: schemaVersion),
            record(tag: Tag.canvasWidth, u32: canvas.width),
            record(tag: Tag.canvasHeight, u32: canvas.height),
            record(tag: Tag.extractAlphaPlane, bytes: alphaPlane),
            record(tag: Tag.extractAlphaThreshold, u32: 20),
            record(tag: Tag.extractMinimumRegionArea, u32: 12),
        ]
        guard let body = encodeRecords(records) else { return nil }
        return encodeFrame(entry: .extraction, mode: .extract, body: body)
    }

    private static func frameRecord(_ frame: ActivationFrameInput) -> Record? {
        guard let orderIndex = UInt32(exactly: frame.orderIndex) else {
            return nil
        }
        guard let group = encodeRecords([
            record(tag: Tag.frameID, bytes: uuidData(frame.frameID)),
            record(tag: Tag.frameOrderIndex, u32: orderIndex),
        ]) else {
            return nil
        }
        return Record(tag: Tag.frame, valueType: .group, value: group)
    }

    private static func callPropagation(request: Data, canvas: Canvas) -> Data? {
        callEngine(entry: .propagation, request: request, canvas: canvas)
    }

    private static func callExtraction(request: Data, canvas: Canvas) -> Data? {
        callEngine(entry: .extraction, request: request, canvas: canvas)
    }

    private static func callEngine(entry: Entry, request: Data, canvas: Canvas) -> Data? {
        var createStatus = CA_PIPELINE_ERR_INTERNAL
        guard let context = ca_pipeline_create(&createStatus),
              createStatus == CA_PIPELINE_OK
        else {
            return nil
        }
        defer { ca_pipeline_destroy(context) }

        return request.withUnsafeBytes { requestBytes in
            guard let requestPointer = requestBytes.bindMemory(to: UInt8.self).baseAddress else {
                return nil
            }

            var scratch = Data(count: 1)
            var requiredLength = 0
            let probeStatus = scratch.withUnsafeMutableBytes { outputBytes in
                let outputPointer = outputBytes.bindMemory(to: UInt8.self).baseAddress
                return callEngineFunction(
                    entry: entry,
                    context: context,
                    requestPointer: requestPointer,
                    requestLength: request.count,
                    canvas: canvas,
                    outputPointer: outputPointer,
                    outputCapacity: 0,
                    outputLength: &requiredLength
                )
            }
            guard probeStatus == CA_PIPELINE_ERR_OVERFLOW, requiredLength > 0 else {
                return nil
            }

            var output = Data(count: requiredLength)
            let outputCapacity = output.count
            var writtenLength = 0
            let finalStatus = output.withUnsafeMutableBytes { outputBytes in
                callEngineFunction(
                    entry: entry,
                    context: context,
                    requestPointer: requestPointer,
                    requestLength: request.count,
                    canvas: canvas,
                    outputPointer: outputBytes.bindMemory(to: UInt8.self).baseAddress,
                    outputCapacity: outputCapacity,
                    outputLength: &writtenLength
                )
            }
            guard finalStatus == CA_PIPELINE_OK,
                  writtenLength > 0,
                  writtenLength <= output.count
            else {
                return nil
            }
            return writtenLength == output.count ? output : Data(output.prefix(writtenLength))
        }
    }

    private static func callEngineFunction(
        entry: Entry,
        context: OpaquePointer?,
        requestPointer: UnsafePointer<UInt8>,
        requestLength: Int,
        canvas: Canvas,
        outputPointer: UnsafeMutablePointer<UInt8>?,
        outputCapacity: Int,
        outputLength: UnsafeMutablePointer<Int>
    ) -> CAPipelineStatus {
        switch entry {
        case .propagation:
            return ca_engine_run_a(
                context,
                requestPointer,
                requestLength,
                canvas.width,
                canvas.height,
                0,
                outputPointer,
                outputCapacity,
                outputLength
            )
        case .extraction:
            return ca_engine_run_c(
                context,
                requestPointer,
                requestLength,
                canvas.width,
                canvas.height,
                0,
                outputPointer,
                outputCapacity,
                outputLength
            )
        }
    }

    private static func decodePropagationResult(_ data: Data, mode: Mode) -> PropagationResult? {
        guard let body = decodeFrame(data, expectedEntry: .propagation, expectedMode: mode),
              let records = decodeRecords(body),
              u32Value(records.first(where: { $0.tag == Tag.resultStatus })) == 0
        else {
            return nil
        }

        let flags = u32Value(records.first(where: { $0.tag == Tag.resultFlags })) ?? 0
        let frameResults = records
            .filter { $0.tag == Tag.resultFrame && $0.valueType == .group }
            .compactMap(decodePropagationFrameResult)
        guard frameResults.isEmpty == false else { return nil }

        let totalCorrespondenceCount = frameResults.reduce(0) {
            $0 + $1.correspondenceCount
        }
        return PropagationResult(
            frameResults: frameResults,
            totalCorrespondenceCount: totalCorrespondenceCount,
            completed: flags & resultFlagCancelled == 0
        )
    }

    private static func decodePropagationFrameResult(
        _ record: Record
    ) -> PropagationFrameResult? {
        guard let records = decodeRecords(record.value),
              let frameIDRecord = records.first(where: { $0.tag == Tag.resultFrameID }),
              let frameID = uuid(frameIDRecord.value)
        else {
            return nil
        }
        let correspondenceCount = records.filter {
            $0.tag == Tag.resultCorrespondence && $0.valueType == .group
        }.count
        return PropagationFrameResult(
            frameID: frameID,
            correspondenceCount: correspondenceCount
        )
    }

    private static func decodeExtractionRegionCount(_ data: Data) -> Int? {
        guard let body = decodeFrame(data, expectedEntry: .extraction, expectedMode: .extract),
              let records = decodeRecords(body),
              u32Value(records.first(where: { $0.tag == Tag.resultStatus })) == 0
        else {
            return nil
        }
        return records.filter {
            $0.tag == Tag.frameRegion && $0.valueType == .group
        }.count
    }

    private static func encodeFrame(entry: Entry, mode: Mode, body: Data) -> Data? {
        guard let bodyCount = UInt32(exactly: body.count),
              isSupported(entry: entry, mode: mode)
        else {
            return nil
        }
        var data = Data()
        data.reserveCapacity(wireHeaderByteCount + body.count)
        data.appendUInt32(wireMagic)
        data.appendUInt16(wireVersion)
        data.append(entry.rawValue)
        data.append(mode.rawValue)
        data.appendUInt32(bodyCount)
        data.append(body)
        return data
    }

    private static func decodeFrame(
        _ data: Data,
        expectedEntry: Entry,
        expectedMode: Mode
    ) -> Data? {
        let bytes = [UInt8](data)
        guard bytes.count >= wireHeaderByteCount,
              readUInt32(bytes, offset: 0) == wireMagic,
              readUInt16(bytes, offset: 4) == wireVersion,
              Entry(rawValue: bytes[6]) == expectedEntry,
              Mode(rawValue: bytes[7]) == expectedMode
        else {
            return nil
        }
        let bodyLength = Int(readUInt32(bytes, offset: 8))
        guard bytes.count - wireHeaderByteCount == bodyLength else {
            return nil
        }
        return Data(bytes[wireHeaderByteCount ..< bytes.count])
    }

    private static func isSupported(entry: Entry, mode: Mode) -> Bool {
        switch (entry, mode) {
        case (.propagation, .full),
             (.propagation, .bounded),
             (.extraction, .extract):
            return true
        default:
            return false
        }
    }

    private static func encodeRecords(_ records: [Record]) -> Data? {
        var data = Data()
        for record in records {
            guard record.tag != 0,
                  let valueCount = UInt32(exactly: record.value.count)
            else {
                return nil
            }
            data.appendUInt16(record.tag)
            data.append(record.valueType.rawValue)
            data.append(0)
            data.appendUInt32(valueCount)
            data.append(record.value)
        }
        return data
    }

    private static func decodeRecords(_ data: Data) -> [Record]? {
        let bytes = [UInt8](data)
        var records: [Record] = []
        var offset = 0
        while offset < bytes.count {
            guard bytes.count - offset >= 8 else { return nil }
            let tag = readUInt16(bytes, offset: offset)
            guard tag != 0,
                  let valueType = ValueType(rawValue: bytes[offset + 2]),
                  bytes[offset + 3] == 0
            else {
                return nil
            }
            let length = Int(readUInt32(bytes, offset: offset + 4))
            let valueOffset = offset + 8
            guard length <= bytes.count - valueOffset else { return nil }
            let value = Data(bytes[valueOffset ..< valueOffset + length])
            records.append(Record(tag: tag, valueType: valueType, value: value))
            offset = valueOffset + length
        }
        return records
    }

    private static func record(tag: UInt16, u32 value: UInt32) -> Record {
        var data = Data()
        data.appendUInt32(value)
        return Record(tag: tag, valueType: .u32, value: data)
    }

    private static func record(tag: UInt16, bytes value: Data) -> Record {
        Record(tag: tag, valueType: .bytes, value: value)
    }

    private static func uuidData(_ uuid: UUID) -> Data {
        var raw = uuid.uuid
        return withUnsafeBytes(of: &raw) { Data($0) }
    }

    private static func uuid(_ data: Data) -> UUID? {
        let bytes = [UInt8](data)
        guard bytes.count == 16 else { return nil }
        return UUID(uuid: (
            bytes[0],
            bytes[1],
            bytes[2],
            bytes[3],
            bytes[4],
            bytes[5],
            bytes[6],
            bytes[7],
            bytes[8],
            bytes[9],
            bytes[10],
            bytes[11],
            bytes[12],
            bytes[13],
            bytes[14],
            bytes[15]
        ))
    }

    private static func u32Value(_ record: Record?) -> UInt32? {
        guard let record,
              record.valueType == .u32,
              record.value.count == 4
        else {
            return nil
        }
        return readUInt32([UInt8](record.value), offset: 0)
    }

    private static func readUInt16(_ bytes: [UInt8], offset: Int) -> UInt16 {
        (UInt16(bytes[offset]) << 8) |
            UInt16(bytes[offset + 1])
    }

    private static func readUInt32(_ bytes: [UInt8], offset: Int) -> UInt32 {
        (UInt32(bytes[offset]) << 24) |
            (UInt32(bytes[offset + 1]) << 16) |
            (UInt32(bytes[offset + 2]) << 8) |
            UInt32(bytes[offset + 3])
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8(value & 0xFF))
    }

    mutating func appendUInt32(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8(value & 0xFF))
    }
}
#endif
