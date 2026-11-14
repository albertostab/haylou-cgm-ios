import Foundation

/// Read-only classification. Field 36 / nested ring-status field 1 follows the
/// external APK-analysis report; no captured device vector has validated it yet.
enum WatchEvent: Equatable {
    case findPhoneStart, findPhoneStop, weatherAck, other, malformed
    var label: String {
        switch self {
        case .findPhoneStart: return "findPhoneStart (reported schema; confirm on device)"
        case .findPhoneStop: return "findPhoneStop (reported schema; confirm on device)"
        case .weatherAck: return "weatherAck command 26"
        case .other: return "other/unclassified"
        case .malformed: return "malformed"
        }
    }
}

enum WatchEventCodec {
    private enum ParseError: Error { case invalid }
    private struct Field {
        let number: UInt64
        let integer: UInt64?
        let bytes: [UInt8]?
    }
    private static func varint(_ bytes: [UInt8], _ index: inout Int) throws -> UInt64 {
        var value: UInt64 = 0
        for shift in stride(from: 0, through: 63, by: 7) {
            guard index < bytes.count else { throw ParseError.invalid }
            let byte = bytes[index]; index += 1
            if shift == 63 && byte > 1 { throw ParseError.invalid }
            value |= UInt64(byte & 0x7f) << shift
            if byte & 0x80 == 0 { return value }
        }
        throw ParseError.invalid
    }
    private static func fields(_ bytes: [UInt8]) throws -> [Field] {
        var result: [Field] = []
        var index = 0
        while index < bytes.count {
            let tag = try varint(bytes, &index)
            let number = tag >> 3
            guard number > 0 && number <= 536870911 else { throw ParseError.invalid }
            switch tag & 7 {
            case 0:
                result.append(Field(number: number, integer: try varint(bytes, &index), bytes: nil))
            case 1, 5:
                let size = tag & 7 == 1 ? 8 : 4
                guard bytes.count - index >= size else { throw ParseError.invalid }
                index += size
            case 2:
                let length = try varint(bytes, &index)
                guard length <= UInt64(bytes.count - index) else { throw ParseError.invalid }
                let end = index + Int(length)
                result.append(Field(number: number, integer: nil, bytes: Array(bytes[index..<end])))
                index = end
            default: throw ParseError.invalid
            }
        }
        return result
    }
    static func classify(frame: [UInt8]) -> WatchEvent {
        guard WeatherCodec.validate(frame) else { return .malformed }
        do {
            let message = try fields(Array(frame.dropFirst(9)))
            if let find = message.last(where: { $0.number == 36 && $0.bytes != nil })?.bytes {
                let nested = try fields(find)
                guard !nested.contains(where: { $0.number == 1 && $0.integer == nil }) else { return .malformed }
                // Protobuf scalar default: an omitted m_ring_status is zero/start.
                let status = nested.last(where: { $0.number == 1 && $0.integer != nil })?.integer ?? 0
                return status == 0 ? .findPhoneStart : .findPhoneStop
            }
            if message.last(where: { $0.number == 1 && $0.integer != nil })?.integer == 26 {
                return .weatherAck
            }
            return .other
        } catch { return .malformed }
    }
}

/// Each notify/indicate characteristic has its own bounded stream. Do not interpret
/// a BLE fragment as a complete protobuf message or trust a frame with invalid CRC.
struct WatchEventStream {
    private var buffer: [UInt8] = []
    private var lastPart: Date?
    mutating func receive(_ chunk: [UInt8], now: Date) -> [WatchEvent] {
        if let lastPart = lastPart, now.timeIntervalSince(lastPart) > 10 { buffer = [] }
        lastPart = now
        guard !chunk.isEmpty else { return [] }
        guard chunk.count <= 4096, buffer.count + chunk.count <= 4096 else {
            buffer = []; return [.malformed]
        }
        buffer += chunk
        var events: [WatchEvent] = []
        while !buffer.isEmpty {
            if buffer[0] != 0x7e {
                // Unframed transport acknowledgements are unclassified, never Find Phone.
                if let next = buffer.firstIndex(of: 0x7e) { buffer.removeFirst(next) }
                else { buffer = []; return events + [.other] }
            }
            guard buffer.count >= 3 else { break }
            guard Array(buffer.prefix(3)) == [0x7e, 0x6d, 0x03] else {
                buffer.removeFirst(); events.append(.other); continue
            }
            guard buffer.count >= 9 else { break }
            let length = Int(buffer[3]) + 256 * Int(buffer[4])
            guard length <= 2048 else { buffer = []; return events + [.malformed] }
            let count = length + 9
            guard buffer.count >= count else { break }
            events.append(WatchEventCodec.classify(frame: Array(buffer.prefix(count))))
            buffer.removeFirst(count)
        }
        return events
    }
}
