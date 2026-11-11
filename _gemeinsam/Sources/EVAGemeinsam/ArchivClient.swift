import Foundation

/// Spricht nur mit dem Archiv aus der Anmeldung. Jede Antwort kommt als rohe Daten plus Abrufzeit zurück, damit
/// die App sie ablegen und offline mit ihrem Alter zeigen kann.
public struct ArchivClient: Sendable {
    public enum Fehler: LocalizedError, Equatable {
        case keinNetz, abgemeldet, nichtFreigegeben, server(Int, String), unlesbar
        public var errorDescription: String? {
            switch self {
            case .keinNetz: return "Kein Netz oder das Archiv ist nicht erreichbar."
            case .abgemeldet: return "Das Token gilt nicht mehr. Bitte neu anmelden."
            case .nichtFreigegeben: return "Diese Funktion ist für die App nicht freigegeben."
            case .server(let c, let t): return "Das Archiv antwortet mit \(c): \(t)"
            case .unlesbar: return "Die Antwort des Archivs ist unlesbar."
            }
        }
    }

    public let anmeldung: Anmeldung
    private let sitzung: URLSession

    /// zeitlimit: Sekunden je Anfrage. 30 reichen für alles außer der Strecken-Route.
    public init(anmeldung: Anmeldung, zeitlimit: TimeInterval = 30) {
        self.anmeldung = anmeldung
        let konf = URLSessionConfiguration.ephemeral
        konf.timeoutIntervalForRequest = zeitlimit
        konf.timeoutIntervalForResource = zeitlimit * 2
        konf.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.sitzung = URLSession(configuration: konf)
    }

    public func get(_ pfad: String, _ parameter: [String: String] = [:]) async throws -> Data {
        var teile = URLComponents(url: anmeldung.basis.appendingPathComponent(pfad), resolvingAgainstBaseURL: false)!
        if !parameter.isEmpty {
            teile.queryItems = parameter.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return try await senden(URLRequest(url: teile.url!))
    }

    public func post(_ pfad: String, _ koerper: [String: Any]) async throws -> Data {
        var anfrage = URLRequest(url: anmeldung.basis.appendingPathComponent(pfad))
        anfrage.httpMethod = "POST"
        anfrage.setValue("application/json", forHTTPHeaderField: "Content-Type")
        anfrage.httpBody = try JSONSerialization.data(withJSONObject: koerper)
        return try await senden(anfrage)
    }

    private func senden(_ anfrage: URLRequest) async throws -> Data {
        var a = anfrage
        a.setValue("Bearer \(anmeldung.token)", forHTTPHeaderField: "Authorization")
        a.setValue("application/json", forHTTPHeaderField: "Accept")
        let daten: Data, antwort: URLResponse
        do {
            (daten, antwort) = try await sitzung.data(for: a)
        } catch {
            // Ein Abbruch beim ersten Abruf nach dem Start kam am 2026-11-11 zweimal vor (nginx 499 nach 15 s);
            // ein zweiter Versuch nach einer Sekunde klärt das, ohne den Nutzer zu fragen.
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            do {
                (daten, antwort) = try await sitzung.data(for: a)
            } catch {
                throw Fehler.keinNetz
            }
        }
        guard let http = antwort as? HTTPURLResponse else { throw Fehler.unlesbar }
        switch http.statusCode {
        case 200: return daten
        case 401: throw Fehler.abgemeldet
        case 403: throw Fehler.nichtFreigegeben
        default:
            let obj = (try? JSONSerialization.jsonObject(with: daten)) as? [String: Any]
            throw Fehler.server(http.statusCode, (obj?["error"] as? String) ?? "ohne Grund")
        }
    }
}
