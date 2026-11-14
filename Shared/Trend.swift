import Foundation
// Weather codes beyond sunny=1 are provisional until checked on the user's RT2.
enum Trend {
    static func symbol(_ direction: String) -> String {
        switch direction {
        case "DoubleUp": return "↑↑"
        case "SingleUp": return "↑"
        case "FortyFiveUp": return "↗"
        case "Flat": return "→"
        case "FortyFiveDown": return "↘"
        case "SingleDown": return "↓"
        case "DoubleDown": return "↓↓"
        default: return "?"
        }
    }
    static func climate(_ direction: String) -> Int {
        switch direction {
        case "Flat": return 1
        case "FortyFiveUp": return 2
        case "SingleUp", "DoubleUp": return 3
        case "FortyFiveDown": return 4
        case "SingleDown": return 5
        case "DoubleDown": return 6
        default: return 0
        }
    }
    static let legend = "Legenda RT2 sperimentale: sole → stabile; sole/nuvole ↗; nuvole ↑/↑↑; pioggia leggera ↘; pioggia ↓; temporale ↓↓. Codici 0 e 2–6 da verificare sul tuo firmware; ? indica tendenza assente. Le icone non sono allarmi."
}
