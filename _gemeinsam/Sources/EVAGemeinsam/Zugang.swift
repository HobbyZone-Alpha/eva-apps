import Foundation
import Security

/// Was der QR-Code vom Archiv trägt: eva-app://anmelden?basis=…&app=…&token=…
public struct Anmeldung: Equatable, Sendable {
    public let basis: URL
    public let app: String
    public let token: String

    /// Nur diese Hosts nimmt eine EVA-App an. Ein QR-Code mit fremder Adresse wird abgelehnt, damit das Token nie
    /// an einen anderen Server geht.
    public static let erlaubteHosts: Set<String> = ["www.egis-datenbankarchiv.de", "egis-datenbankarchiv.de"]

    public enum Fehler: LocalizedError, Equatable {
        case keinEvaCode, fremdeAdresse(String), falscheApp(String), unvollstaendig
        public var errorDescription: String? {
            switch self {
            case .keinEvaCode: return "Das ist kein Anmelde-Code einer EVA-App."
            case .fremdeAdresse(let h): return "Der Code zeigt auf \(h). Angenommen wird nur das EGIS-Datenbankarchiv."
            case .falscheApp(let a): return "Der Code gehört zur App \(a), nicht zu dieser."
            case .unvollstaendig: return "Im Code fehlt die Adresse oder das Token."
            }
        }
    }

    public init(basis: URL, app: String, token: String) {
        self.basis = basis; self.app = app; self.token = token
    }

    /// Liest den Inhalt des QR-Codes. `erwarteteApp` ist das Kürzel der App, etwa "app-weather".
    public static func lesen(_ text: String, erwarteteApp: String) throws -> Anmeldung {
        guard let teile = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              teile.scheme == "eva-app", teile.host == "anmelden" else { throw Fehler.keinEvaCode }
        let werte = Dictionary((teile.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
        guard let basisText = werte["basis"], let basis = URL(string: basisText), let token = werte["token"],
              !token.isEmpty, let app = werte["app"] else { throw Fehler.unvollstaendig }
        guard basis.scheme == "https", let host = basis.host, erlaubteHosts.contains(host) else {
            throw Fehler.fremdeAdresse(basis.host ?? basisText)
        }
        guard app == erwarteteApp else { throw Fehler.falscheApp(app) }
        return Anmeldung(basis: basis, app: app, token: token)
    }
}

/// Das Token liegt nur im Schlüsselbund dieses Geräts, nie in einer Datei, nie in iCloud.
public enum Schluesselbund {
    private static let dienst = "de.egis-datenbankarchiv.eva-apps"

    public static func speichern(_ anmeldung: Anmeldung) throws {
        loeschen(app: anmeldung.app)
        let wert = try JSONSerialization.data(withJSONObject: ["basis": anmeldung.basis.absoluteString,
                                                                "token": anmeldung.token])
        let abfrage: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecAttrAccount as String: anmeldung.app,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: wert,
        ]
        let status = SecItemAdd(abfrage as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "Schluesselbund", code: Int(status),
                          userInfo: [NSLocalizedDescriptionKey: "Token konnte nicht gespeichert werden (\(status))."])
        }
    }

    public static func laden(app: String) -> Anmeldung? {
        let abfrage: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecAttrAccount as String: app,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var ergebnis: CFTypeRef?
        guard SecItemCopyMatching(abfrage as CFDictionary, &ergebnis) == errSecSuccess,
              let daten = ergebnis as? Data,
              let obj = try? JSONSerialization.jsonObject(with: daten) as? [String: String],
              let basisText = obj["basis"], let basis = URL(string: basisText), let token = obj["token"] else { return nil }
        return Anmeldung(basis: basis, app: app, token: token)
    }

    public static func loeschen(app: String) {
        let abfrage: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                      kSecAttrService as String: dienst, kSecAttrAccount as String: app]
        SecItemDelete(abfrage as CFDictionary)
    }
}
