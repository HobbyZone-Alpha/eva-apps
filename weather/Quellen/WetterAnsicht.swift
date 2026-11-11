import SwiftUI
import EVAGemeinsam

/// Tab Wetter: oben die Lage jetzt und der Nowcast, darunter Warnungen, 24 Stunden und 7 Tage.
/// Die Ortswahl sitzt im Titel; »Hier« ist ein Eintrag darin und speichert nichts.
struct WetterAnsicht: View {
    @ObservedObject var laden: WetterLaden
    let verbindung: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if let a = laden.anzeige {
                    Section { Kopf(anzeige: a) }
                    if let n = a.nowcast, n.verfuegbar {
                        Section("Die nächste Stunde") { NowcastBalken(nowcast: n, farbe: akzent) }
                    } else if let g = a.nowcastGrund {
                        Section("Die nächste Stunde") {
                            Text("Kein Radar-Nowcast: \(g).").foregroundStyle(.secondary)
                        }
                    }
                    if !a.warnungen.isEmpty || a.warnHinweis != nil {
                        Section("Warnungen") {
                            ForEach(a.warnungen) { WarnZeile(warnung: $0) }
                            if let h = a.warnHinweis { Text(h).font(.footnote).foregroundStyle(.secondary) }
                        }
                    }
                    if !a.stunden.isEmpty {
                        Section("24 Stunden") {
                            StundenLeiste(stunden: a.stunden, farbe: akzent)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        }
                    }
                    if !a.tage.isEmpty {
                        Section("7 Tage") {
                            ForEach(a.tage) { TagZeile(tag: $0, farbe: akzent) }
                        }
                    }
                    Section {
                        Fusszeile(quellen: a.quellen, stand: laden.stand, fehler: laden.fehler)
                    }
                } else if laden.laedt {
                    HStack { Spacer(); ProgressView("Lade das Wetter"); Spacer() }
                } else {
                    LeerZustand(fehler: laden.fehler) { Task { await laden.starten() } }
                }
            }
            .navigationTitle(laden.auswahlName)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Ortswahl(laden: laden) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: verbindung) { Image(systemName: "person.crop.circle") }
                        .accessibilityLabel("Verbindung und Abmelden")
                }
            }
            .refreshable { await laden.aktualisieren() }
            .tint(akzent)
        }
        .task { if laden.anzeige == nil { await laden.starten() } }
        .onChange(of: laden.auswahl) { _, _ in Task { await laden.aktualisieren() } }
    }

    private var akzent: Color { Darstellung.akzent(laden.anzeige?.lage) }
}

private struct Ortswahl: View {
    @ObservedObject var laden: WetterLaden

    var body: some View {
        Menu {
            Picker("Ort", selection: $laden.auswahl) {
                Label("Hier", systemImage: "location.fill").tag(Optional(Auswahl.hier))
                ForEach(laden.beobachteteOrte) { o in
                    Label(o.name, systemImage: o.hauptort ? "house.fill" : "mappin")
                        .tag(Optional(Auswahl.ort(o.id)))
                }
            }
        } label: {
            Label("Ort wählen", systemImage: "list.bullet")
        }
        .accessibilityLabel("Ort wählen, gewählt: \(laden.auswahlName)")
    }
}

private struct Kopf: View {
    let anzeige: Anzeige
    @ScaledMetric(relativeTo: .largeTitle) private var gross: CGFloat = 64

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(Darstellung.grad(anzeige.temperatur))
                    .font(.system(size: gross, weight: .light, design: .rounded))
                    .monospacedDigit()
                if let l = Darstellung.lageText(anzeige.lage) {
                    Text(l).font(.title3).foregroundStyle(Darstellung.akzent(anzeige.lage))
                }
            }
            if let satz = anzeige.nowcast?.satz, anzeige.nowcast?.verfuegbar == true {
                Text(satz).font(.title3.weight(.medium))
            }
            HStack(spacing: 16) {
                if let f = anzeige.feuchte {
                    Label(Darstellung.prozent(f), systemImage: "humidity").accessibilityLabel("Luftfeuchte \(Darstellung.prozent(f))")
                }
                if anzeige.wind != nil {
                    Label(Darstellung.kmh(anzeige.wind), systemImage: "wind").accessibilityLabel("Wind \(Darstellung.kmh(anzeige.wind))")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            if let h = anzeige.herkunft {
                Text(h).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Zwölf Balken je fünf Minuten. Die Höhe folgt der Regenrate logarithmisch (0,1 bis 10 mm/h), wie die Radarklassen.
struct NowcastBalken: View {
    let nowcast: Nowcast
    let farbe: Color
    @ScaledMetric private var hoehe: CGFloat = 72

    private var schritte: [NowcastSchritt] { Array(nowcast.schritte.prefix(12)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(schritte) { s in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(s.luecke == 1 ? Color.secondary.opacity(0.25) : farbe)
                            .frame(height: max(3, hoehe * anteil(s.mmH)))
                            .opacity((s.mmH ?? 0) > 0 ? 1 : 0.25)
                    }
                    .frame(maxWidth: .infinity, maxHeight: hoehe)
                }
            }
            .frame(height: hoehe)
            HStack {
                Text("Jetzt")
                Spacer()
                Text("+30 min")
                Spacer()
                Text("+60 min")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(beschreibung)
    }

    private func anteil(_ mmH: Double?) -> CGFloat {
        guard let m = mmH, m >= 0.1 else { return 0 }
        return CGFloat(min(1, log10(m / 0.1) / 2 * 0.85 + 0.15))
    }

    private var beschreibung: String {
        let nass = schritte.filter { ($0.mmH ?? 0) >= 0.1 }.count
        let spitze = schritte.compactMap(\.mmH).max() ?? 0
        if nass == 0 { return "Nowcast: in der nächsten Stunde trocken." }
        return "Nowcast: in \(nass) von 12 Fünf-Minuten-Schritten Regen, höchstens \(spitze.formatted(.number.precision(.fractionLength(1)))) Millimeter je Stunde."
    }
}

private struct WarnZeile: View {
    let warnung: Warnung
    @State private var offen = false

    var body: some View {
        DisclosureGroup(isExpanded: $offen) {
            if let t = warnung.text { Text(t).font(.callout) }
            if let q = warnung.quelleName { Text(q).font(.footnote).foregroundStyle(.secondary) }
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(warnung.ueberschrift).font(.headline)
                    Text(zeitraum).font(.subheadline).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(farbe)
            }
        }
    }

    private var farbe: Color {
        switch warnung.schwere ?? 0 {
        case 3...: return .purple
        case 2: return .red
        case 1: return .orange
        default: return .yellow
        }
    }

    private var zeitraum: String {
        func uhr(_ s: String?) -> String? {
            guard let s, let d = ISO8601DateFormatter.mitMinuten.date(from: s) else { return nil }
            return d.formatted(date: Calendar.current.isDateInToday(d) ? .omitted : .abbreviated, time: .shortened)
        }
        let von = uhr(warnung.onsetOrtszeit), bis = uhr(warnung.expiresOrtszeit)
        let kommend = warnung.kommend == true ? "Ab " : ""
        switch (von, bis) {
        case let (v?, b?): return "\(kommend)\(v) bis \(b)"
        case let (v?, nil): return "Ab \(v)"
        case let (nil, b?): return "Bis \(b)"
        default: return "Aktiv"
        }
    }
}

extension ISO8601DateFormatter {
    /// Die Ortszeiten des Archivs kommen als »2026-11-11T07:30+01:00«, ohne Sekunden.
    static let mitMinuten: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withTimeZone, .withDashSeparatorInDate]
        return f
    }()
}

private struct StundenLeiste: View {
    let stunden: [StundenZeile]
    let farbe: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(stunden) { s in
                    VStack(spacing: 6) {
                        Text(s.zeit.formatted(.dateTime.hour(.twoDigits(amPM: .omitted))))
                            .font(.caption).foregroundStyle(.secondary)
                        Image(systemName: Darstellung.symbol(regenMm: s.regenMm, regenWkt: s.regenWkt,
                                                             boe: s.boe, wolken: s.wolken, zeit: s.zeit))
                            .symbolRenderingMode(.multicolor)
                            .font(.title3)
                            .frame(height: 28)
                        Text(Darstellung.grad(s.temperatur)).font(.body.weight(.medium)).monospacedDigit()
                        Text(Darstellung.prozent(s.regenWkt))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle((s.regenWkt ?? 0) >= 30 ? farbe : .secondary)
                            .monospacedDigit()
                    }
                    .frame(minWidth: 52)
                    .padding(.horizontal, 4)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(s.zeit.formatted(date: .omitted, time: .shortened)), \(Darstellung.grad(s.temperatur)), Regen \(Darstellung.prozent(s.regenWkt))")
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

private struct TagZeile: View {
    let tag: Tag
    let farbe: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(tag.wochentag).frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: Darstellung.tagSymbol(tag))
                .symbolRenderingMode(.multicolor)
                .frame(width: 30)
            Text(Darstellung.prozent(tag.regenWkt))
                .font(.footnote.weight(.semibold))
                .foregroundStyle((tag.regenWkt ?? 0) >= 30 ? farbe : .secondary)
                .frame(width: 48, alignment: .trailing)
                .monospacedDigit()
            Text("\(Darstellung.grad(tag.tMin)) / \(Darstellung.grad(tag.tMax))")
                .monospacedDigit()
                .frame(minWidth: 72, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tag.wochentag): \(Darstellung.grad(tag.tMin)) bis \(Darstellung.grad(tag.tMax)), Regen \(Darstellung.prozent(tag.regenWkt))")
    }
}

struct Fusszeile: View {
    let quellen: [String]
    let stand: Date?
    let fehler: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let fehler {
                Label(fehler, systemImage: "wifi.exclamationmark").foregroundStyle(.orange)
            }
            if let stand {
                Text("Stand \(Darstellung.alter(stand))")
            }
            if !quellen.isEmpty {
                Text("Quellen: " + quellen.joined(separator: ", "))
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

struct LeerZustand: View {
    let fehler: String?
    let nochmal: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud.sun").font(.largeTitle).foregroundStyle(.secondary)
            Text(fehler ?? "Noch keine Daten.").multilineTextAlignment(.center)
            Button("Erneut laden", action: nochmal).buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
