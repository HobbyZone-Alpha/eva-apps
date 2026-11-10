import SwiftUI
import EVAGemeinsam

/// Probe aus P3: holt /api/wetter/status, legt die Antwort ab und zeigt sie ohne Netz mit ihrem Alter.
struct StatusAnsicht: View {
    let anmeldung: Anmeldung
    let abmelden: () -> Void
    @State private var text = "Noch nichts geladen."
    @State private var stand: Date?
    @State private var fehler: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Verbindung") {
                    LabeledContent("Archiv", value: anmeldung.basis.host ?? "")
                    if let stand {
                        LabeledContent("Stand", value: stand.formatted(date: .omitted, time: .shortened))
                    }
                    if let fehler {
                        Text(fehler).foregroundStyle(.red)
                    }
                }
                Section("Antwort von /api/wetter/status") {
                    Text(text).font(.footnote.monospaced())
                }
                Section {
                    Button("Abmelden", role: .destructive, action: abmelden)
                }
            }
            .navigationTitle("EVA WEATHER")
            .refreshable { await laden() }
            .task { await laden() }
        }
    }

    private func laden() async {
        let schluessel = "wetter-status"
        do {
            let daten = try await ArchivClient(anmeldung: anmeldung).get("api/wetter/status")
            Ablage.speichern(daten, unter: schluessel)
            zeigen(daten, Date())
            fehler = nil
        } catch {
            fehler = error.localizedDescription
            if let alt = Ablage.laden(schluessel) {
                zeigen(alt.daten, alt.zeit)
            }
        }
    }

    private func zeigen(_ daten: Data, _ zeit: Date) {
        stand = zeit
        if let obj = try? JSONSerialization.jsonObject(with: daten),
           let schoen = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) {
            text = String(decoding: schoen.prefix(4000), as: UTF8.self)
        } else {
            text = String(decoding: daten.prefix(4000), as: UTF8.self)
        }
    }
}
