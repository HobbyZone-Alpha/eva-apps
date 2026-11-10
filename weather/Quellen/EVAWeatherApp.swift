import SwiftUI
import EVAGemeinsam

/// EVA WEATHER, Platzhalter aus P2: beweist nur, dass der Bau-Läufer eine IPA liefert.
/// Die eigentlichen Ansichten kommen in P4 (docs/design/Apps/Weather/DESIGN-20261110-eva-weather.md).
@main
struct EVAWeatherApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Text("EVA WEATHER").font(.largeTitle.bold())
                Text("Platzhalter, Gemeinsam \(EVAGemeinsam.version)").foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}
