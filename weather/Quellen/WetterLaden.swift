import Foundation
import CoreLocation
import EVAGemeinsam

/// Was der Tab Wetter zeigt, gleich ob ein beobachteter Ort oder »Hier« gewählt ist.
struct Anzeige {
    var titel: String
    var herkunft: String?
    var temperatur: Double?
    var feuchte: Double?
    var wind: Double?
    var nowcast: Nowcast?
    var nowcastGrund: String?
    var warnungen: [Warnung]
    var warnHinweis: String?
    var stunden: [StundenZeile]
    var tage: [Tag]
    var lage: String?
    var quellen: [String]
}

struct StundenZeile: Identifiable {
    let zeit: Date
    let temperatur: Double?
    let regenWkt: Double?
    let regenMm: Double?
    let boe: Double?
    let wolken: Double?
    var id: Date { zeit }
}

enum Auswahl: Hashable {
    case hier
    case ort(String)
}

@MainActor
final class WetterLaden: ObservableObject {
    @Published private(set) var orte: [Spot] = []
    @Published var auswahl: Auswahl?
    @Published private(set) var anzeige: Anzeige?
    @Published private(set) var stand: Date?
    @Published private(set) var fehler: String?
    @Published private(set) var laedt = false

    /// Bis zu diesem Abstand gilt ein beobachteter Ort als »hier«, wie NAH_KM auf dem Server.
    static let nahKm = 10.0

    let anmeldung: Anmeldung
    let ortung = Ortung()
    private var client: ArchivClient { ArchivClient(anmeldung: anmeldung) }

    init(anmeldung: Anmeldung) {
        self.anmeldung = anmeldung
        if let alt = Ablage.laden("orte"), let o = try? JSONDecoder().decode(OrteAntwort.self, from: alt.daten) {
            orte = o.spots
        }
    }

    var beobachteteOrte: [Spot] { orte.filter { $0.istOrt } }
    var strecken: [Spot] { orte.filter { !$0.istOrt } }

    var auswahlName: String {
        switch auswahl {
        case .hier: return "Hier"
        case .ort(let id): return orte.first { $0.id == id }?.name ?? "Ort"
        case nil: return "Wetter"
        }
    }

    /// Erster Start und Herunterziehen ohne Wahl: nächster Ort bis 10 km, sonst »Hier«, ohne Ortung der Hauptort.
    func starten() async {
        await orteLaden()
        if auswahl == nil {
            // Das Setzen löst über onChange in der Ansicht das Laden aus; hier nicht ein zweites Mal.
            auswahl = await startWahl()
        } else {
            await aktualisieren()
        }
    }

    private func startWahl() async -> Auswahl {
        if let p = await ortung.holen() {
            let naechster = beobachteteOrte.compactMap { s -> (Spot, Double)? in
                guard let k = s.koordinate else { return nil }
                return (s, p.distance(from: CLLocation(latitude: k.lat, longitude: k.lon)) / 1000)
            }.min { $0.1 < $1.1 }
            if let n = naechster, n.1 <= Self.nahKm { return .ort(n.0.id) }
            return .hier
        }
        if let haupt = beobachteteOrte.first(where: { $0.hauptort }) ?? beobachteteOrte.first {
            return .ort(haupt.id)
        }
        return .hier
    }

    func orteLaden() async {
        do {
            let d = try await client.get("api/wetter/orte")
            let o = try JSONDecoder().decode(OrteAntwort.self, from: d)
            Ablage.speichern(d, unter: "orte")
            orte = o.spots
        } catch {
            fehler = (error as? LocalizedError)?.errorDescription ?? "Orte nicht lesbar."
        }
    }

    func aktualisieren() async {
        guard let auswahl else { return }
        laedt = true
        defer { laedt = false }
        switch auswahl {
        case .ort(let id): await ortLaden(id)
        case .hier: await hierLaden()
        }
    }

    // MARK: Beobachteter Ort

    private func ortLaden(_ id: String) async {
        let schluesselV = "vorhersage-\(id)", schluesselW = "warnungen-\(id)"
        do {
            async let v = client.get("api/wetter/vorhersage", ["id": id, "stunden": "24"])
            async let w = client.get("api/wetter/warnungen", ["id": id])
            let (dv, dw) = try await (v, w)
            Ablage.speichern(dv, unter: schluesselV)
            Ablage.speichern(dw, unter: schluesselW)
            zeigeOrt(dv, dw, zeit: Date())
            fehler = nil
        } catch {
            fehler = (error as? LocalizedError)?.errorDescription ?? "Laden fehlgeschlagen."
            if let av = Ablage.laden(schluesselV) {
                zeigeOrt(av.daten, Ablage.laden(schluesselW)?.daten, zeit: av.zeit)
            }
        }
    }

    private func zeigeOrt(_ dv: Data, _ dw: Data?, zeit: Date) {
        guard let v = try? JSONDecoder().decode(Vorhersage.self, from: dv) else {
            fehler = ArchivClient.Fehler.unlesbar.errorDescription
            return
        }
        let w = dw.flatMap { try? JSONDecoder().decode(WarnungenAntwort.self, from: $0) }
        var quellen = (v.quellen ?? []).map(\.name)
        if v.nowcast?.verfuegbar == true { quellen.append("DWD Radar-Nowcast") }
        anzeige = Anzeige(
            titel: v.ort?.name ?? auswahlName,
            herkunft: (v.aktuell?.regen?.name).map { "Regenmesser \($0)" },
            temperatur: v.aktuell?.werte["t_c"]?.wert ?? v.stunden.first?.temperatur,
            feuchte: v.aktuell?.werte["rh_proz"]?.wert,
            wind: v.aktuell?.werte["ff_kmh"]?.wert,
            nowcast: v.nowcast,
            nowcastGrund: v.nowcast?.verfuegbar == false ? v.nowcast?.grund : nil,
            warnungen: w?.warnungen ?? [],
            warnHinweis: w == nil ? "Warnungen nicht geladen." : nil,
            stunden: v.stunden.map { StundenZeile(zeit: $0.zeit, temperatur: $0.temperatur, regenWkt: $0.regenWkt,
                                                   regenMm: $0.regenMm, boe: $0.boe, wolken: $0.wolken) },
            tage: v.tage,
            lage: v.stunden.first?.lage,
            quellen: quellen)
        stand = zeit
    }

    // MARK: Hier (Standort, nichts wird gespeichert)

    private func hierLaden() async {
        guard let p = await ortung.holen() else {
            fehler = ortung.erlaubt == false
                ? "Ortung ist für EVA WEATHER aus. Einstellungen, EVA WEATHER, Standort: Beim Verwenden der App."
                : "Keine Position bekommen."
            if let alt = Ablage.laden("standort") { zeigeHier(alt.daten, zeit: alt.zeit) }
            return
        }
        do {
            let d = try await client.post("api/wetter/standort",
                                          ["lat": p.coordinate.latitude, "lon": p.coordinate.longitude])
            Ablage.speichern(d, unter: "standort")
            zeigeHier(d, zeit: Date())
            fehler = nil
        } catch {
            fehler = (error as? LocalizedError)?.errorDescription ?? "Laden fehlgeschlagen."
            if let alt = Ablage.laden("standort") { zeigeHier(alt.daten, zeit: alt.zeit) }
        }
    }

    private func zeigeHier(_ d: Data, zeit: Date) {
        guard let s = try? JSONDecoder().decode(StandortAntwort.self, from: d) else {
            fehler = ArchivClient.Fehler.unlesbar.errorDescription
            return
        }
        var herkunft: String?
        if let n = s.naechsterOrt {
            let km = n.km.formatted(.number.precision(.fractionLength(1)))
            herkunft = s.jetzt != nil ? "Messwerte und Radar von \(n.name), \(km) km entfernt"
                                      : "Nächster beobachteter Ort: \(n.name), \(km) km"
        }
        let stunden = (s.vorhersage?.stunden ?? []).filter { $0.zeit > Date().addingTimeInterval(-3600) }
        var quellen = ["Open-Meteo (DWD ICON, ECMWF IFS)"]
        if s.nowcast?.verfuegbar == true { quellen.append("DWD Radar-Nowcast") }
        anzeige = Anzeige(
            titel: "Hier",
            herkunft: herkunft,
            temperatur: s.jetzt?.werte["t_c"]?.wert ?? stunden.first?.temperatur,
            feuchte: s.jetzt?.werte["rh_proz"]?.wert,
            wind: s.jetzt?.werte["ff_kmh"]?.wert,
            nowcast: s.nowcast,
            nowcastGrund: s.nowcast?.verfuegbar == false ? s.nowcast?.grund : nil,
            warnungen: s.warnungen?.liste ?? [],
            warnHinweis: s.warnungen?.hinweis,
            stunden: stunden.map { StundenZeile(zeit: $0.zeit, temperatur: $0.temperatur, regenWkt: $0.regenWkt,
                                                regenMm: $0.regenMm, boe: $0.boe, wolken: $0.wolken) },
            tage: [],
            lage: Self.lageGeschaetzt(stunden.first),
            quellen: quellen)
        if s.vorhersage == nil, let g = s.vorhersageGrund { fehler = g }
        stand = zeit
    }

    /// Für »Hier« liefert der Server keine Lage; die App leitet sie grob aus der ersten Stunde ab, nur für die Farbe.
    private static func lageGeschaetzt(_ s: FreieStunde?) -> String? {
        guard let s else { return nil }
        if (s.regenWkt ?? 0) >= 50 || (s.regenMm ?? 0) >= 0.2 { return "nass" }
        if (s.boe ?? 0) >= 50 { return "windig" }
        return nil
    }
}
