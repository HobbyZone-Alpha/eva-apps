import SwiftUI
import EVAGemeinsam

/// EVA WEATHER (TIK-1597): Anmeldung per QR-Code, dann drei Tabs Wetter, Strecken, Radar.
/// Design: docs/design/Apps/Weather/DESIGN-20261110-eva-weather.md im Repository egis-datenbankarchiv.
@main
struct EVAWeatherApp: App {
    @State private var anmeldung: Anmeldung? = Schluesselbund.laden(app: AppKennung.kuerzel)

    var body: some Scene {
        WindowGroup {
            if let anmeldung {
                Hauptansicht(laden: WetterLaden(anmeldung: anmeldung)) {
                    Schluesselbund.loeschen(app: AppKennung.kuerzel)
                    Ablage.leeren()
                    self.anmeldung = nil
                }
                .id(anmeldung.token)
            } else {
                AnmeldeAnsicht { self.anmeldung = $0 }
            }
        }
    }
}

enum AppKennung {
    static let kuerzel = "app-weather"
}

private struct Hauptansicht: View {
    @StateObject var laden: WetterLaden
    let abmelden: () -> Void
    @State private var verbindungOffen = false

    init(laden: @autoclosure @escaping () -> WetterLaden, abmelden: @escaping () -> Void) {
        _laden = StateObject(wrappedValue: laden())
        self.abmelden = abmelden
    }

    var body: some View {
        TabView {
            WetterAnsicht(laden: laden) { verbindungOffen = true }
                .tabItem { Label("Wetter", systemImage: "cloud.sun") }
            StreckenAnsicht(laden: laden)
                .tabItem { Label("Strecken", systemImage: "bicycle") }
            RadarAnsicht(laden: laden)
                .tabItem { Label("Radar", systemImage: "dot.radiowaves.left.and.right") }
        }
        .sheet(isPresented: $verbindungOffen) {
            VerbindungAnsicht(anmeldung: laden.anmeldung, abmelden: abmelden)
        }
    }
}

private struct VerbindungAnsicht: View {
    let anmeldung: Anmeldung
    let abmelden: () -> Void
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Archiv", value: anmeldung.basis.host ?? "")
                    LabeledContent("App", value: anmeldung.app)
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                } footer: {
                    Text("Die App darf nur Wetter lesen und Abfahrten setzen. Widerrufen lässt sich das Token jederzeit am Server.")
                }
                Section {
                    Button("Abmelden", role: .destructive) {
                        schliessen()
                        abmelden()
                    }
                } footer: {
                    Text("Löscht das Token und alle abgelegten Antworten auf diesem Gerät.")
                }
            }
            .navigationTitle("Verbindung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } }
            }
        }
    }
}
