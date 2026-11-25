// Modell.swift — App-Zustand: Akkustand, angetippter Wert, Merker, Sprache, Autostart (Plan 3, 4.4, 4.6, 4.7)
import Foundation
import Observation
import ServiceManagement
import ChargeLimitKit

@Observable @MainActor final class Modell {
    static let geteilt = Modell()
    private static let sprachSchluessel = "sprache"

    var sprache: Sprache {
        didSet { UserDefaults.standard.set(sprache.rawValue, forKey: Self.sprachSchluessel) }
    }
    /// nil = `liesAkku()` lieferte nichts (oder noch nicht gelesen, siehe `gelesen`)
    var stand: AkkuStand?
    var gelesen = false
    /// angetippt, aber noch nicht gesetzt
    var angetippt: Int?
    /// Merker (4.4): zuletzt erfolgreich angeforderter Wert, nur im Speicher
    var angefordert: Int?
    var setztGerade = false
    var fehlgeschlagen = false
    var autostart: SMAppService.Status = .notRegistered

    @ObservationIgnored private var takt: Task<Void, Never>?

    private init() {
        if let s = UserDefaults.standard.string(forKey: Self.sprachSchluessel), let gespeichert = Sprache(rawValue: s) {
            sprache = gespeichert
        } else {
            sprache = (Locale.preferredLanguages.first ?? "").hasPrefix("de") ? .de : .en
        }
    }

    /// 10-s-Takt, solange das Programm läuft.
    func starten() {
        guard takt == nil else { return }
        // Kein eingebauter Akku → Hinweis und beenden; läuft erst, wenn die App fertig gestartet ist.
        guard hatEingebautenAkku() else { Task { Fenster.keinAkkuUndBeenden() }; return }
        takt = Task {
            while !Task.isCancelled {
                await aktualisieren()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    func aktualisieren() async {
        stand = await liesAkku()
        gelesen = true
        autostart = Autostart.status
        if let a = angefordert, stand?.grenze == a { angefordert = nil }
    }

    /// Knöpfe nur im Akkubetrieb gesperrt.
    var gesperrt: Bool { stand?.amNetzteil == false }

    /// Etwas Neues ist angetippt (≠ geltende Grenze) → „Grenze auf X % setzen“ wird aktiv.
    var neuerWert: Int? {
        guard let a = angetippt, a != stand?.grenze else { return nil }
        return a
    }

    func antippen(_ wert: Int) {
        fehlgeschlagen = false
        angetippt = (wert == stand?.grenze) ? nil : wert
    }

    /// Merker-Zeile statt der Zustandszeile: am Netzteil, Grenze lesbar und ≠ angefordert.
    var merkerAktiv: Bool {
        guard let s = stand, s.amNetzteil, let g = s.grenze, let a = angefordert else { return false }
        return g != a
    }

    func setzenAngetippt() async {
        guard let wert = neuerWert, !setztGerade else { return }
        setztGerade = true
        fehlgeschlagen = false
        angefordert = nil
        let ergebnis = await setzen(wert, hinweis: T.kennwortHinweis(wert))
        switch ergebnis {
        case .gesetzt:
            angefordert = wert
            angetippt = nil
        case .abgebrochen:
            break
        case .fehler(let text):
            NSLog("ChargeLimit setzen: \(text)")
            fehlgeschlagen = true
        }
        setztGerade = false
        await aktualisieren()
    }

    func autostartUmschalten() {
        Autostart.umschalten()
        autostart = Autostart.status
    }
}
