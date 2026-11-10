import SwiftUI
import UIKit
import EVAGemeinsam

/// Erster Start: Code vom Rechner scannen. Fällt die Kamera in LiveContainer aus, geht es mit Einfügen.
struct AnmeldeAnsicht: View {
    let fertig: (Anmeldung) -> Void
    @State private var scannen = false
    @State private var meldung: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("EVA WEATHER").font(.largeTitle.bold())
            Text("Am Rechner auf dem Server `python3 server/app_token.py app-weather` ausführen und den Code scannen.")
                .foregroundStyle(.secondary)
            Button {
                meldung = nil
                scannen = true
            } label: {
                Label("Code scannen", systemImage: "qrcode.viewfinder").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            Button {
                annehmen(UIPasteboard.general.string ?? "")
            } label: {
                Label("Code aus der Zwischenablage", systemImage: "doc.on.clipboard").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).controlSize(.large)
            if let meldung {
                Text(meldung).foregroundStyle(.red)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: 560)
        .sheet(isPresented: $scannen) {
            QRScanner(gefunden: { text in
                scannen = false
                annehmen(text)
            }, fehler: { text in
                scannen = false
                meldung = text
            })
            .ignoresSafeArea()
        }
    }

    private func annehmen(_ text: String) {
        do {
            let a = try Anmeldung.lesen(text, erwarteteApp: AppKennung.kuerzel)
            try Schluesselbund.speichern(a)
            fertig(a)
        } catch {
            meldung = error.localizedDescription
        }
    }
}
