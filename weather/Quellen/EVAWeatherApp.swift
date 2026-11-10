import SwiftUI
import EVAGemeinsam

/// EVA WEATHER, Stand P3: Anmeldung per QR-Code und eine Statusprobe gegen das Archiv.
/// Die Wetter-Ansichten kommen in P4 (docs/design/Apps/Weather/DESIGN-20261110-eva-weather.md).
@main
struct EVAWeatherApp: App {
    @State private var anmeldung: Anmeldung? = Schluesselbund.laden(app: AppKennung.kuerzel)

    var body: some Scene {
        WindowGroup {
            if let anmeldung {
                StatusAnsicht(anmeldung: anmeldung) {
                    Schluesselbund.loeschen(app: AppKennung.kuerzel)
                    Ablage.leeren()
                    self.anmeldung = nil
                }
            } else {
                AnmeldeAnsicht { self.anmeldung = $0 }
            }
        }
    }
}

enum AppKennung {
    static let kuerzel = "app-weather"
}
