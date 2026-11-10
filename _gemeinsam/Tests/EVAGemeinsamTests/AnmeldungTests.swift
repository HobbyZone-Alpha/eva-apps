import XCTest
@testable import EVAGemeinsam

final class AnmeldungTests: XCTestCase {
    let gut = "eva-app://anmelden?basis=https%3A%2F%2Fwww.egis-datenbankarchiv.de&app=app-weather&token=abc123"

    func testGuterCodeWirdGelesen() throws {
        let a = try Anmeldung.lesen(gut, erwarteteApp: "app-weather")
        XCTAssertEqual(a.basis.host, "www.egis-datenbankarchiv.de")
        XCTAssertEqual(a.token, "abc123")
    }

    func testNegativFremdeAdresse() {
        let boese = gut.replacingOccurrences(of: "www.egis-datenbankarchiv.de", with: "boese.example")
        XCTAssertThrowsError(try Anmeldung.lesen(boese, erwarteteApp: "app-weather")) {
            XCTAssertEqual($0 as? Anmeldung.Fehler, .fremdeAdresse("boese.example"))
        }
    }

    func testNegativNachahmerHost() {
        let boese = gut.replacingOccurrences(of: "www.egis-datenbankarchiv.de", with: "egis-datenbankarchiv.de.boese.example")
        XCTAssertThrowsError(try Anmeldung.lesen(boese, erwarteteApp: "app-weather"))
    }

    func testNegativOhneHttps() {
        let boese = gut.replacingOccurrences(of: "https%3A", with: "http%3A")
        XCTAssertThrowsError(try Anmeldung.lesen(boese, erwarteteApp: "app-weather"))
    }

    func testNegativFalscheApp() {
        XCTAssertThrowsError(try Anmeldung.lesen(gut, erwarteteApp: "app-music")) {
            XCTAssertEqual($0 as? Anmeldung.Fehler, .falscheApp("app-weather"))
        }
    }

    func testNegativKeinEvaCodeUndOhneToken() {
        XCTAssertThrowsError(try Anmeldung.lesen("https://example.org", erwarteteApp: "app-weather"))
        XCTAssertThrowsError(try Anmeldung.lesen(gut.replacingOccurrences(of: "abc123", with: ""), erwarteteApp: "app-weather"))
    }
}
