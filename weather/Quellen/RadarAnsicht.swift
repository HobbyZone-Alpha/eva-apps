import SwiftUI
import UIKit
import CoreLocation
import EVAGemeinsam

/// Tab Radar: der Ausschnitt um den Hauptort vom jüngsten Lauf, jetzt bis +120 min in Fünf-Minuten-Schritten.
/// Der Server schickt Klassen als Graustufen (0 trocken, 1 bis 250 log10 von 0,1 bis 100 mm/h, 255 ohne Daten),
/// die Farbe setzt die App. Eine Grundkarte gibt es bewusst nicht: sie käme von einem Fremd-Server.
struct RadarAnsicht: View {
    @ObservedObject var laden: WetterLaden
    @StateObject private var radar = RadarLaden()
    @State private var schritt = 0
    @State private var laeuft = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let r = radar.antwort, !radar.bilder.isEmpty {
                        RadarBild(antwort: r, bild: radar.bilder[min(schritt, radar.bilder.count - 1)],
                                  orte: laden.beobachteteOrte, position: laden.ortung.position?.coordinate)
                        steuerung(r)
                        Legende()
                        Fusszeile(quellen: [r.namensnennung ?? "Deutscher Wetterdienst"],
                                  stand: Date(timeIntervalSince1970: TimeInterval(r.laufAt)),
                                  fehler: radar.fehler ?? (r.veraltet == true ? "Der Radarlauf ist veraltet." : nil))
                    } else if radar.laedt {
                        ProgressView("Lade das Radar").frame(maxWidth: .infinity).padding(.top, 60)
                    } else {
                        LeerZustand(fehler: radar.fehler) { Task { await radar.laden(laden.anmeldung) } }
                    }
                }
                .padding()
            }
            .navigationTitle("Radar")
            .refreshable { await radar.laden(laden.anmeldung) }
        }
        .task { if radar.antwort == nil { await radar.laden(laden.anmeldung) } }
        .task(id: laeuft) {
            guard laeuft else { return }
            while laeuft, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 450_000_000)
                schritt = schritt + 1 >= radar.bilder.count ? 0 : schritt + 1
            }
        }
    }

    @ViewBuilder
    private func steuerung(_ r: RadarAntwort) -> some View {
        let minuten = r.schritte.indices.contains(schritt) ? r.schritte[schritt] : schritt * 5
        let zeit = Date(timeIntervalSince1970: TimeInterval(r.laufAt + minuten * 60))
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    laeuft.toggle()
                } label: {
                    Image(systemName: laeuft ? "pause.fill" : "play.fill").frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(laeuft ? "Anhalten" : "Abspielen")
                VStack(alignment: .leading) {
                    Text(Darstellung.uhr(zeit)).font(.title2.weight(.semibold)).monospacedDigit()
                    Text(minuten == 0 ? "Messung" : "Vorhersage +\(minuten) min")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Slider(value: Binding(get: { Double(schritt) }, set: { schritt = Int($0.rounded()); laeuft = false }),
                   in: 0...Double(max(1, radar.bilder.count - 1)), step: 1)
                .accessibilityLabel("Zeitpunkt")
                .accessibilityValue("\(Darstellung.uhr(zeit))")
        }
    }
}

@MainActor
final class RadarLaden: ObservableObject {
    @Published private(set) var antwort: RadarAntwort?
    @Published private(set) var bilder: [CGImage] = []
    @Published private(set) var fehler: String?
    @Published private(set) var laedt = false

    func laden(_ anmeldung: Anmeldung) async {
        laedt = true
        defer { laedt = false }
        let client = ArchivClient(anmeldung: anmeldung)
        do {
            async let j = client.get("api/wetter/radar")
            async let p = client.get("api/wetter/radar/bild")
            let (dj, dp) = try await (j, p)
            Ablage.speichern(dj, unter: "radar")
            Ablage.speichern(dp, unter: "radar-bild")
            zeigen(dj, dp)
            fehler = nil
        } catch {
            fehler = (error as? LocalizedError)?.errorDescription ?? "Radar nicht geladen."
            if let j = Ablage.laden("radar"), let p = Ablage.laden("radar-bild") { zeigen(j.daten, p.daten) }
        }
    }

    private func zeigen(_ dj: Data, _ dp: Data) {
        guard let r = try? JSONDecoder().decode(RadarAntwort.self, from: dj) else {
            fehler = ArchivClient.Fehler.unlesbar.errorDescription
            return
        }
        let b = RadarFarbe.zerlegen(png: dp, anzahl: r.schritte.count)
        if b.isEmpty { fehler = "Das Radarbild ist unlesbar." }
        antwort = r
        bilder = b
    }
}

/// Graustufen-Stapel zu farbigen Einzelbildern.
enum RadarFarbe {
    static func zerlegen(png: Data, anzahl: Int) -> [CGImage] {
        guard anzahl > 0, let quelle = UIImage(data: png)?.cgImage else { return [] }
        let breite = quelle.width, hoehe = quelle.height
        var grau = [UInt8](repeating: 0, count: breite * hoehe)
        guard let ctx = CGContext(data: &grau, width: breite, height: hoehe, bitsPerComponent: 8, bytesPerRow: breite,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return [] }
        ctx.draw(quelle, in: CGRect(x: 0, y: 0, width: breite, height: hoehe))
        let teilHoehe = hoehe / anzahl
        guard teilHoehe > 0 else { return [] }
        let tabelle = (0...255).map { farbe(UInt8($0)) }
        var ergebnis: [CGImage] = []
        for i in 0..<anzahl {
            var rgba = [UInt8](repeating: 0, count: breite * teilHoehe * 4)
            for y in 0..<teilHoehe {
                for x in 0..<breite {
                    let k = grau[(i * teilHoehe + y) * breite + x]
                    let f = tabelle[Int(k)]
                    let o = (y * breite + x) * 4
                    rgba[o] = f.0; rgba[o + 1] = f.1; rgba[o + 2] = f.2; rgba[o + 3] = f.3
                }
            }
            let daten = Data(rgba) as CFData
            guard let anbieter = CGDataProvider(data: daten),
                  let bild = CGImage(width: breite, height: teilHoehe, bitsPerComponent: 8, bitsPerPixel: 32,
                                     bytesPerRow: breite * 4, space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                     provider: anbieter, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
            else { continue }
            ergebnis.append(bild)
        }
        return ergebnis
    }

    /// Stützfarben über die drei Dekaden: 0,1 hellblau, 1 blau, 5 grün, 10 gelb, 30 rot, 100 violett.
    static let stuetzen: [(Double, (Double, Double, Double))] = [
        (0.1, (0.62, 0.80, 0.98)), (1, (0.20, 0.47, 0.95)), (5, (0.18, 0.72, 0.38)),
        (10, (0.98, 0.84, 0.20)), (30, (0.93, 0.27, 0.20)), (100, (0.66, 0.22, 0.80)),
    ]

    /// Premultiplied RGBA einer Klasse.
    static func farbe(_ k: UInt8) -> (UInt8, UInt8, UInt8, UInt8) {
        if k == 0 { return (0, 0, 0, 0) }
        if k == 255 { return (30, 30, 30, 26) }                                  // ohne Daten: zarter Schleier
        let mm = 0.1 * pow(10, Double(Int(k) - 1) / 249 * 3)
        var c = stuetzen.last!.1
        for (i, s) in stuetzen.enumerated() where i > 0 && mm <= s.0 {
            let a = stuetzen[i - 1]
            let t = (log10(mm) - log10(a.0)) / (log10(s.0) - log10(a.0))
            c = (a.1.0 + (s.1.0 - a.1.0) * t, a.1.1 + (s.1.1 - a.1.1) * t, a.1.2 + (s.1.2 - a.1.2) * t)
            break
        }
        let alpha = min(1, 0.55 + Double(k) / 250 * 0.45)
        return (UInt8(c.0 * alpha * 255), UInt8(c.1 * alpha * 255), UInt8(c.2 * alpha * 255), UInt8(alpha * 255))
    }
}

private struct RadarBild: View {
    let antwort: RadarAntwort
    let bild: CGImage
    let orte: [Spot]
    let position: CLLocationCoordinate2D?

    var body: some View {
        let g = antwort.grenzen
        // Seitenverhältnis in Kilometern, nicht in Grad: ein Grad Länge ist hier rund 0,63 Grad Breite.
        let breiteKm = (g.ost - g.west) * 111.3 * cos((g.nord + g.sued) / 2 * .pi / 180)
        let hoeheKm = (g.nord - g.sued) * 111.3
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color(.secondarySystemBackground))
                Image(decorative: bild, scale: 1).resizable().interpolation(.medium)
                ForEach(orte) { o in
                    if let k = o.koordinate, let p = punkt(k.lat, k.lon, w, h) {
                        OrtMarke(name: o.name, haupt: o.hauptort).position(p)
                    }
                }
                if let pos = position, let p = punkt(pos.latitude, pos.longitude, w, h) {
                    Circle().fill(Color.blue).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .position(p)
                        .accessibilityLabel("Dein Standort")
                }
                Massstab(kmJePunkt: breiteKm / w).padding(10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .aspectRatio(breiteKm / hoeheKm, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Radarbild um \(antwort.zentrum?.name ?? "den Hauptort")")
    }

    private func punkt(_ lat: Double, _ lon: Double, _ w: CGFloat, _ h: CGFloat) -> CGPoint? {
        let g = antwort.grenzen
        guard (g.sued...g.nord).contains(lat), (g.west...g.ost).contains(lon) else { return nil }
        return CGPoint(x: (lon - g.west) / (g.ost - g.west) * w, y: (g.nord - lat) / (g.nord - g.sued) * h)
    }
}

private struct OrtMarke: View {
    let name: String
    let haupt: Bool

    var body: some View {
        VStack(spacing: 2) {
            Circle().fill(haupt ? Color.primary : Color.secondary).frame(width: haupt ? 8 : 6, height: haupt ? 8 : 6)
            Text(name)
                .font(.caption2.weight(haupt ? .semibold : .regular))
                .padding(.horizontal, 4)
                .background(.thinMaterial, in: Capsule())
        }
        .accessibilityLabel(name)
    }
}

private struct Massstab: View {
    let kmJePunkt: Double

    var body: some View {
        let breite = 20 / kmJePunkt
        VStack(alignment: .leading, spacing: 2) {
            Rectangle().frame(width: breite, height: 3)
            Text("20 km").font(.caption2)
        }
        .padding(6)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
        .accessibilityHidden(true)
    }
}

private struct Legende: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LinearGradient(stops: RadarFarbe.stuetzen.enumerated().map { i, s in
                .init(color: Color(red: s.1.0, green: s.1.1, blue: s.1.2),
                      location: Double(i) / Double(RadarFarbe.stuetzen.count - 1))
            }, startPoint: .leading, endPoint: .trailing)
            .frame(height: 8)
            .clipShape(Capsule())
            HStack {
                Text("leicht")
                Spacer()
                Text("mäßig")
                Spacer()
                Text("stark")
                Spacer()
                Text("Unwetter")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Farbskala von leichtem Regen bis Unwetter")
    }
}
