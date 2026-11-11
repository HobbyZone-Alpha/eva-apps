import Foundation

// Abbild der Antworten von /api/wetter/*. Jedes Feld, das der Server weglassen oder auf null setzen kann, ist optional:
// eine fehlende Zahl zeigt die App als Lücke, sie rät nichts dazu.

struct OrteAntwort: Decodable {
    let spots: [Spot]
}

struct Spot: Decodable, Identifiable, Hashable {
    let id: String
    let art: String
    let name: String
    let hauptort: Bool
    let punkt: String?
    let rowVersion: Int?
    let abfahrten: [Abfahrt]?
    let naechsteAbfahrt: NaechsteAbfahrt?
    let tempoKmh: Double?

    enum CodingKeys: String, CodingKey {
        case id, art, name, hauptort, punkt, abfahrten
        case rowVersion = "row_version"
        case naechsteAbfahrt = "naechste_abfahrt"
        case tempoKmh = "tempo_kmh"
    }

    var istOrt: Bool { art == "ort" }

    /// lat, lon aus dem Feld punkt ("51.21208,7.04151").
    var koordinate: (lat: Double, lon: Double)? {
        guard let teile = punkt?.split(separator: ","), teile.count == 2,
              let lat = Double(teile[0]), let lon = Double(teile[1]) else { return nil }
        return (lat, lon)
    }

    static func == (a: Spot, b: Spot) -> Bool { a.id == b.id && a.rowVersion == b.rowVersion }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct Abfahrt: Codable, Hashable, Identifiable {
    var wochentag: Int
    var ab: String
    var bis: String?
    var richtung: String
    var fahrzeug: String?
    var aktiv: Bool
    let id = UUID()

    enum CodingKeys: String, CodingKey { case wochentag, ab, bis, richtung, fahrzeug, aktiv }

    init(wochentag: Int, ab: String, bis: String?, richtung: String, fahrzeug: String?, aktiv: Bool) {
        self.wochentag = wochentag; self.ab = ab; self.bis = bis
        self.richtung = richtung; self.fahrzeug = fahrzeug; self.aktiv = aktiv
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        wochentag = try c.decode(Int.self, forKey: .wochentag)
        ab = try c.decode(String.self, forKey: .ab)
        bis = try c.decodeIfPresent(String.self, forKey: .bis)
        richtung = (try c.decodeIfPresent(String.self, forKey: .richtung)) ?? "hin"
        fahrzeug = try c.decodeIfPresent(String.self, forKey: .fahrzeug)
        // Der Server liefert aktiv als 0 oder 1, nimmt beim Setzen aber nur false als »aus« (wetter_schreiben.py).
        if let b = try? c.decode(Bool.self, forKey: .aktiv) { aktiv = b }
        else { aktiv = ((try? c.decode(Int.self, forKey: .aktiv)) ?? 1) != 0 }
    }

    /// Für POST /api/wetter/abfahrten/setzen: genau die sechs Felder, aktiv als echtes true oder false.
    var alsKoerper: [String: Any] {
        var k: [String: Any] = ["wochentag": wochentag, "ab": ab, "richtung": richtung, "aktiv": aktiv]
        k["bis"] = bis ?? NSNull()
        k["fahrzeug"] = fahrzeug ?? NSNull()
        return k
    }

    static func == (a: Abfahrt, b: Abfahrt) -> Bool {
        a.wochentag == b.wochentag && a.ab == b.ab && a.bis == b.bis && a.richtung == b.richtung
            && a.fahrzeug == b.fahrzeug && a.aktiv == b.aktiv
    }
    func hash(into h: inout Hasher) { h.combine(wochentag); h.combine(ab); h.combine(richtung) }
}

struct NaechsteAbfahrt: Decodable, Hashable {
    let abText: String?
    let bisText: String?
    let richtung: String?
    let fahrzeug: String?
    let minutenBis: Int?
    let laeuft: Bool?

    enum CodingKeys: String, CodingKey {
        case richtung, fahrzeug, laeuft
        case abText = "ab_text"
        case bisText = "bis_text"
        case minutenBis = "minuten_bis"
    }
}

// MARK: Vorhersage eines beobachteten Ortes

struct Vorhersage: Decodable {
    let ort: OrtKopf?
    let nowcast: Nowcast?
    let aktuell: Aktuell?
    let stunden: [Stunde]
    let tage: [Tag]
    let quellen: [Quelle]?
}

struct OrtKopf: Decodable { let name: String }

struct Quelle: Decodable { let name: String; let namensnennung: String? }

struct Statistik: Decodable {
    let median: Double?
    let min: Double?
    let max: Double?
}

struct Stunde: Decodable, Identifiable {
    let gueltigAt: Int
    let ensemble: [String: Statistik]
    let ww: Int?
    let lage: String?
    var id: Int { gueltigAt }
    var zeit: Date { Date(timeIntervalSince1970: TimeInterval(gueltigAt)) }

    enum CodingKeys: String, CodingKey {
        case ensemble, ww, lage
        case gueltigAt = "gueltig_at"
    }

    var temperatur: Double? { ensemble["t_c"]?.median }
    var regenWkt: Double? { ensemble["regen_wkt"]?.median ?? ensemble["rr_wkt"]?.median }
    var regenMm: Double? { ensemble["rr_mm"]?.median }
    var boe: Double? { ensemble["fx_kmh"]?.median }
    var wolken: Double? { ensemble["n_proz"]?.median }
}

struct Tag: Decodable, Identifiable {
    let datum: String
    let ensemble: [String: Statistik]
    let ww: Int?
    var id: String { datum }

    var tMin: Double? { ensemble["t_min"]?.median }
    var tMax: Double? { ensemble["t_max"]?.median }
    var regenWkt: Double? { ensemble["regen_wkt_max"]?.median }
    var regenSumme: Double? { ensemble["rr_summe"]?.median }
    var boe: Double? { ensemble["boe_max"]?.median }

    var wochentag: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: datum) else { return datum }
        if Calendar.current.isDateInToday(d) { return "Heute" }
        if Calendar.current.isDateInTomorrow(d) { return "Morgen" }
        f.dateFormat = "EEEE"
        return f.string(from: d)
    }
}

struct Aktuell: Decodable {
    let werte: [String: Messwert]
    let regen: Regenmessung?
    let gemessenAt: Int?
    let vomOrt: String?

    enum CodingKeys: String, CodingKey {
        case werte, regen
        case gemessenAt = "gemessen_at"
        case vomOrt = "vom_ort"
    }
}

struct Messwert: Decodable { let wert: Double? }

struct Regenmessung: Decodable {
    let mm30min: Double?
    let name: String?
    enum CodingKeys: String, CodingKey { case name; case mm30min = "mm_30min" }
}

struct Nowcast: Decodable {
    let verfuegbar: Bool
    let satz: String?
    let grund: String?
    let schritte: [NowcastSchritt]
    let alterS: Int?
    let namensnennung: String?
    let vomOrt: String?

    enum CodingKeys: String, CodingKey {
        case verfuegbar, satz, grund, schritte, namensnennung
        case alterS = "alter_s"
        case vomOrt = "vom_ort"
    }
}

struct NowcastSchritt: Decodable, Identifiable {
    let bis: Int
    let mmH: Double?
    let anteil: Int?
    let luecke: Int?
    var id: Int { bis }
    enum CodingKeys: String, CodingKey { case bis, anteil, luecke; case mmH = "mm_h" }
}

// MARK: Warnungen

struct WarnungenAntwort: Decodable {
    let warnungen: [Warnung]
    let namensnennung: String?
}

struct Warnung: Decodable, Identifiable {
    let id: String
    let schwere: Int?
    let titel: String?
    let ereignis: String?
    let text: String?
    let kommend: Bool?
    let onsetOrtszeit: String?
    let expiresOrtszeit: String?
    let quelleName: String?

    enum CodingKeys: String, CodingKey {
        case id, schwere, kommend
        case titel = "headline"
        case ereignis = "event"
        case text = "description"
        case onsetOrtszeit = "onset_ortszeit"
        case expiresOrtszeit = "expires_ortszeit"
        case quelleName = "quelle_name"
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        // Die id kommt je nach Quelle als Zahl oder Text.
        if let s = try? c.decode(String.self, forKey: .id) { id = s }
        else if let n = try? c.decode(Int.self, forKey: .id) { id = String(n) }
        else { id = UUID().uuidString }
        schwere = try? c.decode(Int.self, forKey: .schwere)
        titel = try? c.decode(String.self, forKey: .titel)
        ereignis = try? c.decode(String.self, forKey: .ereignis)
        text = try? c.decode(String.self, forKey: .text)
        kommend = try? c.decode(Bool.self, forKey: .kommend)
        onsetOrtszeit = try? c.decode(String.self, forKey: .onsetOrtszeit)
        expiresOrtszeit = try? c.decode(String.self, forKey: .expiresOrtszeit)
        quelleName = try? c.decode(String.self, forKey: .quelleName)
    }

    var ueberschrift: String { titel ?? ereignis ?? "Warnung" }
}

// MARK: Wetter am Standort (POST /api/wetter/standort)

struct StandortAntwort: Decodable {
    let naechsterOrt: NaechsterOrt?
    let jetzt: Aktuell?
    let jetztGrund: String?
    let nowcast: Nowcast?
    let vorhersage: FreieVorhersage?
    let vorhersageGrund: String?
    let warnungen: StandortWarnungen?

    enum CodingKeys: String, CodingKey {
        case jetzt, nowcast, vorhersage, warnungen
        case naechsterOrt = "naechster_ort"
        case jetztGrund = "jetzt_grund"
        case vorhersageGrund = "vorhersage_grund"
    }
}

struct NaechsterOrt: Decodable { let id: String; let name: String; let km: Double }

struct FreieVorhersage: Decodable {
    let stunden: [FreieStunde]
    let namensnennung: String?
}

/// Je Stunde die Stimmen von Open-Meteo einzeln; die App zeigt den Mittelwert der vorhandenen.
struct FreieStunde: Decodable, Identifiable {
    let gueltigAt: Int
    let stimmen: [String: [String: Double?]]
    var id: Int { gueltigAt }
    var zeit: Date { Date(timeIntervalSince1970: TimeInterval(gueltigAt)) }

    private struct Schluessel: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: Schluessel.self)
        gueltigAt = try c.decode(Int.self, forKey: Schluessel(stringValue: "gueltig_at")!)
        var s: [String: [String: Double?]] = [:]
        for k in c.allKeys where k.stringValue != "gueltig_at" && k.stringValue != "ortszeit" {
            if let werte = try? c.decode([String: Double?].self, forKey: k) { s[k.stringValue] = werte }
        }
        stimmen = s
    }

    private func mittel(_ feld: String) -> Double? {
        let w = stimmen.values.compactMap { $0[feld] ?? nil }
        return w.isEmpty ? nil : w.reduce(0, +) / Double(w.count)
    }

    var temperatur: Double? { mittel("t_c") }
    var regenWkt: Double? { mittel("rr_wkt") }
    var regenMm: Double? { mittel("rr_mm") }
    var boe: Double? { mittel("fx_kmh") }
    var wolken: Double? { mittel("n_proz") }
}

struct StandortWarnungen: Decodable {
    let vomOrt: String?
    let liste: [Warnung]
    let hinweis: String?
    enum CodingKeys: String, CodingKey { case liste, hinweis; case vomOrt = "vom_ort" }
}

// MARK: Strecke

struct StreckenAntwort: Decodable {
    let satz: String?
}

// MARK: Radar

struct RadarAntwort: Decodable {
    let laufAt: Int
    let schritte: [Int]
    let grenzen: RadarGrenzen
    let zentrum: RadarZentrum?
    let alterS: Int?
    let veraltet: Bool?
    let namensnennung: String?

    enum CodingKeys: String, CodingKey {
        case schritte, grenzen, zentrum, veraltet, namensnennung
        case laufAt = "lauf_at"
        case alterS = "alter_s"
    }
}

struct RadarGrenzen: Decodable { let sued: Double; let west: Double; let nord: Double; let ost: Double; let pixel: Int }
struct RadarZentrum: Decodable { let lat: Double; let lon: Double; let name: String? }
