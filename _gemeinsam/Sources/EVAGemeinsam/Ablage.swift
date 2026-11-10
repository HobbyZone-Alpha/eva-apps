import Foundation

/// Letzte Antwort je Schlüssel als Datei im App-Container, mit Abrufzeit. Für das Lesen ohne Netz (Entscheid A2).
public enum Ablage {
    private static var ordner: URL {
        let o = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("eva-ablage")
        try? FileManager.default.createDirectory(at: o, withIntermediateDirectories: true)
        return o
    }

    private static func datei(_ schluessel: String) -> URL {
        let sauber = schluessel.map { $0.isLetter || $0.isNumber ? $0 : "_" }
        return ordner.appendingPathComponent(String(sauber) + ".json")
    }

    public static func speichern(_ daten: Data, unter schluessel: String) {
        try? daten.write(to: datei(schluessel), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// Daten und Abrufzeit, oder nil, wenn nie abgelegt.
    public static func laden(_ schluessel: String) -> (daten: Data, zeit: Date)? {
        let d = datei(schluessel)
        guard let daten = try? Data(contentsOf: d),
              let zeit = (try? FileManager.default.attributesOfItem(atPath: d.path))?[.modificationDate] as? Date
        else { return nil }
        return (daten, zeit)
    }

    public static func leeren() {
        try? FileManager.default.removeItem(at: ordner)
    }
}
