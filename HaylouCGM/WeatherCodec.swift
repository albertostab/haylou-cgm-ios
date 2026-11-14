import Foundation

/// Haylou RT2/LS10, comando meteo 26. Ricostruito dal frame a 4 giorni
/// confermato sull'orologio il 13/11/2026. Non effettua alcuna operazione BLE.
enum WeatherCodec {
    static let serviceUUID = "000001FF-3C17-D293-8E48-14FE2E4DA212"
    static let writeUUID = "000002FF-3C17-D293-8E48-14FE2E4DA212"
    static let indicateUUID = "000003FF-3C17-D293-8E48-14FE2E4DA212"
    static let notifyUUID = "000005FF-3C17-D293-8E48-14FE2E4DA212"

    struct Approximation {
        let celsius: Int
        let shownFahrenheit: Int
        let difference: Int
    }
    enum EncodingError: Error, LocalizedError {
        case range, malformed
        var errorDescription: String? {
            switch self {
            case .range: return "Glicemia non rappresentabile in modo sicuro sul display meteo"
            case .malformed: return "Pacchetto Haylou non valido"
            }
        }
    }

    /// La prova reale sull'RT2 ha mostrato 179°F inserendo 82°C: troncamento.
    /// La misura resta SEMPRE approssimata, non è una glicemia medica affidabile.
    static func approximate(_ mgdl: Int) -> Approximation? {
        guard (40...260).contains(mgdl) else { return nil }
        let candidates = (0...127).map { c -> Approximation in
            let f = Int(floor(Double(c) * 1.8 + 32.0 + 1e-8))
            return Approximation(celsius: c, shownFahrenheit: f, difference: abs(f - mgdl))
        }
        guard let best = candidates.min(by: { $0.difference < $1.difference }), best.difference <= 1 else { return nil }
        return best
    }

    private static func varint(_ number: Int64) -> [UInt8] {
        precondition(number >= 0)
        var n = UInt64(number)
        var bytes: [UInt8] = []
        while n >= 128 {
            bytes.append(UInt8(n & 0x7f) | 0x80)
            n >>= 7
        }
        bytes.append(UInt8(n))
        return bytes
    }
    private static func uint(_ field: Int, _ number: Int64) -> [UInt8] {
        varint(Int64(field * 8)) + varint(number)
    }
    private static func length(_ field: Int, _ bytes: [UInt8]) -> [UInt8] {
        varint(Int64(field * 8 + 2)) + varint(Int64(bytes.count)) + bytes
    }
    private static func string(_ field: Int, _ text: String) -> [UInt8] {
        length(field, Array(text.utf8))
    }
    static func crc16Xmodem(_ bytes: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0
        for b in bytes {
            crc ^= UInt16(b) << 8
            for _ in 0..<8 {
                crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1
            }
        }
        return crc
    }
    private static func frame(_ payload: [UInt8]) -> [UInt8] {
        precondition(payload.count <= 65535)
        let len = UInt16(payload.count)
        let crc = crc16Xmodem(payload)
        let header: [UInt8] = [0x7e, 0x6d, 0x03, UInt8(len & 0xff), UInt8(len >> 8), UInt8(crc & 0xff), UInt8(crc >> 8)]
        let sum = UInt16(header.reduce(0) { $0 + Int($1) })
        return header + [UInt8(sum & 0xff), UInt8(sum >> 8)] + payload
    }
    static func validate(_ bytes: [UInt8]) -> Bool {
        guard bytes.count >= 9, Array(bytes[0..<3]) == [0x7e,0x6d,0x03] else { return false }
        let length = Int(bytes[3]) + 256 * Int(bytes[4])
        guard length == bytes.count - 9 else { return false }
        let crc = UInt16(bytes[5]) | (UInt16(bytes[6]) << 8)
        let sum = UInt16(bytes[7]) | (UInt16(bytes[8]) << 8)
        return crc == crc16Xmodem(Array(bytes.dropFirst(9))) && sum == UInt16(bytes.prefix(7).reduce(0) { $0 + Int($1) })
    }
    static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// Date sempre Europe/Rome, per evitare lo slittamento di un giorno già visto sul watch.
    /// Dal test riuscito: cmd seconds=ora UTC, weather.seconds=mezzanotte locale,
    /// timezone=1 in inverno / 2 in estate; climate=1 (sole).
    static func build(temperature: Int, climate: Int = 1, at now: Date = Date()) throws -> [UInt8] {
        try build(temperatures: Array(repeating: temperature, count: 4),
                  maxima: Array(repeating: temperature, count: 4),
                  minima: Array(repeating: temperature, count: 4), at: now, climate: climate)
    }
    static func build(temperatures: [Int], maxima: [Int], minima: [Int], at now: Date, climate: Int = 1) throws -> [UInt8] {
        guard (0...6).contains(climate), temperatures.count == 4, maxima.count == 4, minima.count == 4,
              (temperatures + maxima + minima).allSatisfy({ (0...127).contains($0) }) else { throw EncodingError.range }
        var cal = Calendar(identifier: .gregorian)
        guard let timezone = TimeZone(identifier: "Europe/Rome") else { throw EncodingError.malformed }
        cal.timeZone = timezone
        var weatherRecords: [UInt8] = []
        for i in 0..<4 {
            guard let d = cal.date(byAdding: .day, value: i, to: now) else { throw EncodingError.malformed }
            let midnight = Int64(cal.startOfDay(for: d).timeIntervalSince1970)
            let record = uint(1, Int64(i))
                + uint(2, Int64(climate)) // Existing climate field; default sunny=1 preserves reference frame.
                + uint(3, Int64(temperatures[i]))
                + uint(4, Int64(18 - i))
                + uint(5, Int64(27 - i))
                + uint(6, 0)
                + uint(7, Int64(maxima[i]))
                + uint(8, Int64(minima[i]))
                + uint(9, midnight)
                + uint(10, 45)
                + uint(11, 3)
                + string(12, "Test")
            weatherRecords += length(1, record)
        }
        let tzHours = timezone.secondsFromGMT(for: now) / 3600
        let payload = uint(1, 26) + uint(2, 0) + uint(3, Int64(now.timeIntervalSince1970))
            + length(27, weatherRecords) + uint(45, Int64(tzHours))
        let packed = frame(payload)
        guard validate(packed) else { throw EncodingError.malformed }
        return packed
    }
}
