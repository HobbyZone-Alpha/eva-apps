import CoreLocation

/// Position nur während der Nutzung und nur auf Anfrage. Die Position verlässt das Gerät allein zum Archiv,
/// dort wird sie auf rund 5 km gerundet und nicht gespeichert (Design, Abschnitt 5.1).
@MainActor
final class Ortung: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var position: CLLocation?
    @Published private(set) var erlaubt: Bool?

    private let manager = CLLocationManager()
    private var warten: [CheckedContinuation<CLLocation?, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        erlaubt = Ortung.deute(manager.authorizationStatus)
    }

    /// Fragt einmal nach der Position. Ohne Erlaubnis oder nach 10 s ohne Antwort: nil.
    func holen() async -> CLLocation? {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if erlaubt == false {
            return nil
        }
        if let p = position, -p.timestamp.timeIntervalSinceNow < 300 { return p }
        manager.requestLocation()
        return await withCheckedContinuation { fortsetzung in
            warten.append(fortsetzung)
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                self?.abschliessen(nil)
            }
        }
    }

    private func abschliessen(_ p: CLLocation?) {
        let alle = warten
        warten = []
        alle.forEach { $0.resume(returning: p) }
    }

    private static func deute(_ s: CLAuthorizationStatus) -> Bool? {
        switch s {
        case .authorizedWhenInUse, .authorizedAlways: return true
        case .denied, .restricted: return false
        default: return nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        let s = m.authorizationStatus
        Task { @MainActor in
            self.erlaubt = Ortung.deute(s)
            if self.erlaubt == true, !self.warten.isEmpty { self.manager.requestLocation() }
            if self.erlaubt == false { self.abschliessen(nil) }
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations orte: [CLLocation]) {
        guard let p = orte.last else { return }
        Task { @MainActor in
            self.position = p
            self.abschliessen(p)
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.abschliessen(nil) }
    }
}
