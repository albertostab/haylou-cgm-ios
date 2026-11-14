import Foundation

@main struct CodecSelfTest {
    static func main() throws {
        // Frame F=1 a quattro giorni che ha mostrato 25° / 27° / 18° sull'RT2.
        let expected = "7e6d039900b2baf302081a1000189984dad706da0188010a200800100118192012281b3000381b401248f089d9d706502d58036204546573740a200801100118182011281a3000381a401148f0acded706502d58036204546573740a200802100118172010281930003819401048f0cfe3d706502d58036204546573740a20080310011816200f281830003818400f48f0f2e8d706502d5803620454657374e80201"
        let fixedNow = Date(timeIntervalSince1970: 1794540057)
        let actual = try WeatherCodec.build(temperatures:[25,24,23,22], maxima:[27,26,25,24], minima:[18,17,16,15], at:fixedNow)
        precondition(actual.count == 162, "dimensione errata")
        precondition(WeatherCodec.hex(actual) == expected, "non coincide col pacchetto sul dispositivo")
        precondition(WeatherCodec.validate(actual), "checksum non valido")
        let example = try WeatherCodec.build(temperature: 25, at: fixedNow)
        precondition(WeatherCodec.validate(example), "frame generico non valido")
        precondition(WeatherCodec.approximate(180)?.shownFahrenheit == 179 || WeatherCodec.approximate(180)?.shownFahrenheit == 181)
        precondition(WeatherCodec.approximate(261) == nil)
        precondition(WeatherCodec.approximate(39) == nil)
        for code in 0...6 {
            let packet = try WeatherCodec.build(temperature: 25, climate: code, at: fixedNow)
            precondition(WeatherCodec.validate(packet))
            precondition(packet.count == example.count)
        }
        print("PASS: frame di riferimento RT2, 162 byte, CRC e checksum, conversioni")
    }
}
