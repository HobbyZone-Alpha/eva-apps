import SwiftUI
import EVAGemeinsam

/// Tab Strecken: je beobachteter Strecke die nächste Abfahrt, das Streckenwetter und der Wochenplan.
/// Der Wochenplan ist das Einzige, was die App schreibt (Entscheid A3), über POST /api/wetter/abfahrten/setzen.
struct StreckenAnsicht: View {
    @ObservedObject var laden: WetterLaden

    var body: some View {
        NavigationStack {
            List {
                if laden.strecken.isEmpty {
                    Text("Keine Strecke beobachtet. Strecken legt das Archiv an, im Reiter WETTER.")
                        .foregroundStyle(.secondary)
                }
                ForEach(laden.strecken) { s in
                    NavigationLink(value: s.id) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(s.name).font(.headline)
                            Text(StreckeDetail.naechste(s)).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Strecken")
            .navigationDestination(for: String.self) { id in
                if let s = laden.strecken.first(where: { $0.id == id }) {
                    StreckeDetail(laden: laden, strecke: s)
                }
            }
            .refreshable { await laden.orteLaden() }
        }
    }
}

struct StreckeDetail: View {
    @ObservedObject var laden: WetterLaden
    let strecke: Spot
    @State private var plan: [Abfahrt] = []
    @State private var satz: String?
    @State private var satzGrund: String?
    @State private var laedtSatz = false
    @State private var speichert = false
    @State private var meldung: String?
    @State private var bearbeiten: Abfahrt?
    @State private var neuAngelegt: UUID?

    static let tage = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]
    static let fahrzeuge: [(String?, String)] = [(nil, "Tempo der Strecke"), ("ebike", "E-Bike"), ("scooter", "E-Scooter")]

    static func naechste(_ s: Spot) -> String {
        guard let n = s.naechsteAbfahrt, let ab = n.abText else { return "Keine Abfahrt geplant" }
        let richtung = n.richtung == "rueck" ? "Rückweg" : "Hinweg"
        if n.laeuft == true { return "\(richtung) läuft, Fenster \(ab) bis \(n.bisText ?? ab)" }
        guard let m = n.minutenBis else { return "\(richtung) um \(ab)" }
        if m < 60 { return "\(richtung) in \(m) min, um \(ab)" }
        if m < 24 * 60 { return "\(richtung) heute oder morgen um \(ab)" }
        return "\(richtung) in \(m / (24 * 60)) Tagen um \(ab)"
    }

    private var geaendert: Bool { plan != (strecke.abfahrten ?? []) }

    var body: some View {
        List {
            Section("Nächste Abfahrt") {
                Text(Self.naechste(strecke))
                if laedtSatz {
                    HStack { ProgressView(); Text("Rechne das Streckenwetter, das kann dauern.") }
                        .foregroundStyle(.secondary)
                } else if let satz {
                    Text(satz).font(.body.weight(.medium))
                } else if let satzGrund {
                    Text(satzGrund).font(.footnote).foregroundStyle(.secondary)
                    Button("Streckenwetter holen") { Task { await satzLaden() } }
                } else {
                    Button("Streckenwetter holen") { Task { await satzLaden() } }
                }
            }
            Section {
                ForEach(plan) { a in
                    Button { bearbeiten = a } label: { AbfahrtZeile(abfahrt: a) }
                        .foregroundStyle(.primary)
                        .swipeActions {
                            Button("Löschen", role: .destructive) { plan.removeAll { $0.id == a.id } }
                        }
                }
                Button {
                    let neu = Abfahrt(wochentag: 0, ab: "07:00", bis: "08:00", richtung: "hin", fahrzeug: nil, aktiv: true)
                    plan.append(neu)
                    neuAngelegt = neu.id
                    bearbeiten = neu
                } label: { Label("Abfahrt hinzufügen", systemImage: "plus") }
            } header: {
                Text("Wochenplan")
            } footer: {
                Text("Einmalige Abfahrten aus dem Telegram-Bot bleiben beim Speichern stehen.")
            }
            if let meldung {
                Section { Text(meldung).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle(strecke.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if speichert { ProgressView() } else {
                    Button("Sichern") { Task { await sichern() } }.disabled(!geaendert)
                }
            }
        }
        .sheet(item: $bearbeiten) { a in
            AbfahrtBearbeiten(abfahrt: a) { neu in
                if let i = plan.firstIndex(where: { $0.id == a.id }) { plan[i] = neu }
            } abbrechen: {
                // Eine eben hinzugefügte, nie bestätigte Abfahrt fällt beim Abbrechen wieder weg.
                if !(strecke.abfahrten ?? []).contains(where: { $0.id == a.id }), neuAngelegt == a.id {
                    plan.removeAll { $0.id == a.id }
                }
                neuAngelegt = nil
            }
        }
        .onAppear { plan = strecke.abfahrten ?? [] }
    }

    private func satzLaden() async {
        laedtSatz = true
        defer { laedtSatz = false }
        do {
            // Die Strecken-Route braucht derzeit Minuten (TIK-1880); 90 s Geduld, dann ehrlich aufgeben.
            let d = try await ArchivClient(anmeldung: laden.anmeldung, zeitlimit: 90)
                .get("api/wetter/strecke", ["id": strecke.id])
            satz = (try? JSONDecoder().decode(StreckenAntwort.self, from: d))?.satz
            satzGrund = satz == nil ? "Das Archiv hat keinen Satz geliefert." : nil
        } catch {
            satzGrund = "Kein Streckenwetter: das Archiv rechnet zu lange (TIK-1880). Der Telegram-Bot meldet die Abfahrt trotzdem."
        }
    }

    private func sichern() async {
        speichert = true
        defer { speichert = false }
        do {
            _ = try await ArchivClient(anmeldung: laden.anmeldung).post("api/wetter/abfahrten/setzen", [
                "id": strecke.id,
                "row_version": strecke.rowVersion ?? 0,
                "abfahrten": plan.map(\.alsKoerper),
            ])
            meldung = "Gesichert."
            await laden.orteLaden()
        } catch ArchivClient.Fehler.server(409, _) {
            meldung = "Jemand hat den Plan inzwischen geändert. Bitte zurückgehen, neu laden und noch einmal."
        } catch {
            meldung = (error as? LocalizedError)?.errorDescription ?? "Sichern fehlgeschlagen."
        }
    }
}

private struct AbfahrtZeile: View {
    let abfahrt: Abfahrt

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(StreckeDetail.tage[min(max(abfahrt.wochentag, 0), 6)])
                Text(abfahrt.richtung == "rueck" ? "Rückweg" : "Hinweg")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Text(abfahrt.bis.map { "\(abfahrt.ab) bis \($0)" } ?? abfahrt.ab).monospacedDigit()
        }
        .opacity(abfahrt.aktiv ? 1 : 0.45)
        .accessibilityElement(children: .combine)
        .accessibilityValue(abfahrt.aktiv ? "" : "pausiert")
    }
}

private struct AbfahrtBearbeiten: View {
    @Environment(\.dismiss) private var schliessen
    @State var abfahrt: Abfahrt
    let fertig: (Abfahrt) -> Void
    let abbrechen: () -> Void
    @State private var mitFenster: Bool

    init(abfahrt: Abfahrt, fertig: @escaping (Abfahrt) -> Void, abbrechen: @escaping () -> Void) {
        _abfahrt = State(initialValue: abfahrt)
        _mitFenster = State(initialValue: abfahrt.bis != nil)
        self.fertig = fertig
        self.abbrechen = abbrechen
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Tag", selection: $abfahrt.wochentag) {
                    ForEach(0..<7, id: \.self) { Text(StreckeDetail.tage[$0]).tag($0) }
                }
                Picker("Richtung", selection: $abfahrt.richtung) {
                    Text("Hinweg").tag("hin")
                    Text("Rückweg").tag("rueck")
                }
                .pickerStyle(.segmented)
                DatePicker("Ab", selection: zeit(\.ab), displayedComponents: .hourAndMinute)
                Toggle("Zeitfenster", isOn: $mitFenster)
                if mitFenster {
                    DatePicker("Bis", selection: zeit(\.bis), displayedComponents: .hourAndMinute)
                }
                Picker("Fahrzeug", selection: $abfahrt.fahrzeug) {
                    ForEach(StreckeDetail.fahrzeuge, id: \.1) { Text($0.1).tag($0.0) }
                }
                Toggle("Aktiv", isOn: $abfahrt.aktiv)
                if let f = fehler { Text(f).foregroundStyle(.red) }
            }
            .navigationTitle("Abfahrt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { abbrechen(); schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        var a = abfahrt
                        a.bis = mitFenster ? (a.bis ?? a.ab) : nil
                        fertig(a)
                        schliessen()
                    }
                    .disabled(fehler != nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Dieselbe Prüfung wie der Server: bis muss nach ab liegen.
    private var fehler: String? {
        guard mitFenster else { return nil }
        if (abfahrt.bis ?? abfahrt.ab) <= abfahrt.ab { return "Das Ende muss nach dem Beginn liegen." }
        return nil
    }

    /// HH:MM als Datum für den DatePicker und zurück.
    private func zeit(_ feld: WritableKeyPath<Abfahrt, String>) -> Binding<Date> {
        Binding(get: { Self.datum(abfahrt[keyPath: feld]) },
                set: { abfahrt[keyPath: feld] = Self.text($0) })
    }

    private func zeit(_ feld: WritableKeyPath<Abfahrt, String?>) -> Binding<Date> {
        Binding(get: { Self.datum(abfahrt[keyPath: feld] ?? abfahrt.ab) },
                set: { abfahrt[keyPath: feld] = Self.text($0) })
    }

    private static func datum(_ hhmm: String) -> Date {
        let t = hhmm.split(separator: ":").compactMap { Int($0) }
        return Calendar.current.date(bySettingHour: t.first ?? 7, minute: t.count > 1 ? t[1] : 0, second: 0, of: Date()) ?? Date()
    }

    private static func text(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}
