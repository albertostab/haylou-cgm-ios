import Foundation

// Synthetic fixtures, not physical captures or independent proof of the APK report.
@main struct WatchEventCodecTest {
    static func frame(_ payload: [UInt8]) -> [UInt8] {
        let crc = WeatherCodec.crc16Xmodem(payload)
        let header: [UInt8] = [0x7e,0x6d,0x03,UInt8(payload.count & 255),UInt8(payload.count >> 8),UInt8(crc & 255),UInt8(crc >> 8)]
        let sum = header.reduce(0) { $0 + Int($1) }
        return header + [UInt8(sum & 255),UInt8(sum >> 8)] + payload
    }
    static func main() throws {
        let now = Date(timeIntervalSince1970: 1800000000)
        let start = frame([0xa2,0x02,0x02,0x08,0x00])
        let stop = frame([0xa2,0x02,0x02,0x08,0x01])
        precondition(WatchEventCodec.classify(frame: start) == .findPhoneStart)
        precondition(WatchEventCodec.classify(frame: frame([0xa2,0x02,0x00])) == .findPhoneStart)
        precondition(WatchEventCodec.classify(frame: stop) == .findPhoneStop)
        precondition(WatchEventCodec.classify(frame: frame([0xa2,0x02,0x02,0x0a,0x00])) == .malformed)
        precondition(WatchEventCodec.classify(frame: frame([0xa2,0x02,0x01,0x08])) == .malformed)
        precondition(WatchEventCodec.classify(frame: frame([0x08])) == .malformed)
        precondition(WatchEventCodec.classify(frame: frame([0x00])) == .malformed)
        precondition(WatchEventCodec.classify(frame: frame([0x08] + Array(repeating: UInt8(255), count: 10))) == .malformed)
        precondition(WatchEventCodec.classify(frame: frame([0x08,0x09])) == .other)
        var bad = start; bad[5] ^= 1
        precondition(WatchEventCodec.classify(frame: bad) == .malformed)
        for split in 1..<start.count {
            var stream = WatchEventStream()
            precondition(stream.receive(Array(start.prefix(split)), now: now).isEmpty)
            precondition(stream.receive(Array(start.dropFirst(split)), now: now) == [.findPhoneStart])
        }
        var joined = WatchEventStream()
        precondition(joined.receive(start + stop, now: now) == [.findPhoneStart,.findPhoneStop])
        let weather = try WeatherCodec.build(temperature: 25, at: now)
        var fragmentedWeather = WatchEventStream()
        var events: [WatchEvent] = []
        for offset in stride(from: 0, to: weather.count, by: 20) {
            events += fragmentedWeather.receive(Array(weather[offset..<min(offset+20, weather.count)]), now: now)
        }
        precondition(events == [.weatherAck])
        var oversized = WatchEventStream()
        precondition(oversized.receive(Array(repeating: 0, count: 4097), now: now) == [.malformed])
        var expired = WatchEventStream()
        precondition(expired.receive(Array(start.prefix(10)), now: now).isEmpty)
        precondition(!expired.receive(Array(start.dropFirst(10)), now: now.addingTimeInterval(11)).contains(.findPhoneStart))
        var arbitrary = WatchEventStream()
        for i in 0..<1000 {
            let bytes = (0..<(i % 65)).map { UInt8(($0 * 17 + i) & 255) }
            _ = arbitrary.receive(bytes, now: now)
        }
        print("PASS: reported Find Phone schema, weather classification, fragmentation, CRC, bounds and malformed data")
    }
}
