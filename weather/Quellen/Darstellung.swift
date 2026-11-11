import SwiftUI

/// Farbe und Symbole aus der Wetterlage. Die App bleibt iOS-nativ: Systemfarben, SF Symbols, Dynamic Type.
/// Der Akzent ist die einzige Stelle, an der das Wetter die Oberfläche färbt (Shape-Entscheid 2026-11-11).
enum Darstellung {
    static func akzent(_ lage: String?) -> Color {
        switch lage {
        case "nass": return .blue
        case "windig": return .teal
        case "klar": return .orange
        case "bedeckt": return .gray
        case "wechselhaft": return .indigo
        default: return .accentColor
        }
    }

    static func lageText(_ lage: String?) -> String? {
        switch lage {
        case "nass": return "Nass"
        case "windig": return "Windig"
        case "klar": return "Klar"
        case "bedeckt": return "Bedeckt"
        case "wechselhaft": return "Wechselhaft"
        default: return nil
        }
    }

    /// Symbol einer Stunde aus Regen, Böen und Bewölkung. Tag zwischen 7 und 18 Uhr, grob, nur fürs Bild.
    static func symbol(regenMm: Double?, regenWkt: Double?, boe: Double?, wolken: Double?, zeit: Date) -> String {
        let mm = regenMm ?? 0, wkt = regenWkt ?? 0
        if mm >= 2 { return "cloud.heavyrain.fill" }
        if mm >= 0.2 || wkt >= 60 { return "cloud.rain.fill" }
        if (boe ?? 0) >= 60 { return "wind" }
        let stunde = Calendar.current.component(.hour, from: zeit)
        let tag = (7...18).contains(stunde)
        switch wolken ?? 50 {
        case 80...: return "cloud.fill"
        case 30..<80: return tag ? "cloud.sun.fill" : "cloud.moon.fill"
        default: return tag ? "sun.max.fill" : "moon.stars.fill"
        }
    }

    static func tagSymbol(_ t: Tag) -> String {
        if (t.regenSumme ?? 0) >= 5 { return "cloud.heavyrain.fill" }
        if (t.regenWkt ?? 0) >= 60 { return "cloud.rain.fill" }
        if (t.boe ?? 0) >= 60 { return "wind" }
        if (t.regenWkt ?? 0) >= 30 { return "cloud.sun.rain.fill" }
        return "cloud.sun.fill"
    }

    static func grad(_ w: Double?) -> String {
        guard let w else { return "·" }
        return "\(Int(w.rounded()))°"
    }

    static func prozent(_ w: Double?) -> String {
        guard let w else { return "" }
        return "\(Int(w.rounded())) %"
    }

    static func kmh(_ w: Double?) -> String {
        guard let w else { return "·" }
        return "\(Int(w.rounded())) km/h"
    }

    static func uhr(_ d: Date) -> String {
        d.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    /// »vor 4 min«, »vor 2 h«, »gestern 18:20«: das Alter einer abgelegten Antwort.
    static func alter(_ d: Date) -> String {
        let s = -d.timeIntervalSinceNow
        if s < 90 { return "gerade eben" }
        if s < 3600 { return "vor \(Int(s / 60)) min" }
        if s < 6 * 3600 { return "vor \(Int(s / 3600)) h" }
        return d.formatted(date: .abbreviated, time: .shortened)
    }
}
