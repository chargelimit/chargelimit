// Texte.swift — alle Texte paarweise Deutsch / Englisch (Plan 4.9)
import ChargeLimitKit

enum Sprache: String { case de, en }

/// Wählt den Text der aktiven Sprache. Neu gezeichnet wird über `.id(modell.sprache)` an der Wurzelansicht.
@MainActor func L(_ de: String, _ en: String) -> String {
    Modell.geteilt.sprache == .de ? de : en
}

/// „60 %“ (Deutsch, geschütztes Leerzeichen) bzw. „60%“ (Englisch)
@MainActor func prozent(_ n: Int) -> String { L("\(n)\u{00A0}%", "\(n)%") }

/// Eine Zustandszeile: der fett gesetzte Kopf und der Rest nach dem Gedankenstrich.
struct Zeile { var kopf: String; var rest: String = "" }

@MainActor enum T {
    static var ladegrenze: String { L("Ladegrenze", "Charge limit") }
    static func akku(_ p: Int) -> String { L("Akku \(prozent(p))", "Battery \(prozent(p))") }

    static func zeile(_ z: Zustand, grenze: Int?) -> Zeile {
        switch z {
        case .laedtBis(let g):
            return Zeile(kopf: L("Lädt bis \(prozent(g))", "Charging to \(prozent(g))"))
        case .haelt(let g):
            return Zeile(kopf: L("Hält \(prozent(g))", "Holding at \(prozent(g))"),
                         rest: L("das Netzteil versorgt den Mac", "running on the power adapter"))
        case .sinktAuf(let g):
            return Zeile(kopf: L("Sinkt auf \(prozent(g))", "Discharging to \(prozent(g))"),
                         rest: L("das Netzteil lädt im Moment nicht nach", "plugged in, not charging right now"))
        case .keineGrenze:
            return Zeile(kopf: L("Keine Grenze", "No limit"),
                         rest: L("lädt bis \(prozent(100))", "charges to \(prozent(100))"))
        case .laedtVoll:
            let g = grenze ?? 0
            return Zeile(kopf: L("Lädt über \(prozent(g))", "Charging above \(prozent(g))"),
                         rest: L("macOS lädt den Akku gelegentlich voll", "macOS tops up to 100% now and then"))
        case .amAkku:
            return Zeile(kopf: L("Mac läuft am Akku", "On battery"),
                         rest: L("zum Setzen bitte das Netzteil anstecken", "connect the power adapter to set a limit"))
        case .unbekannt:
            return Zeile(kopf: L("Grenze gerade nicht lesbar", "Limit can't be read right now"))
        }
    }
    static var nichtLesbar: Zeile { Zeile(kopf: L("Akkuzustand nicht lesbar", "Battery status can't be read")) }
    static func angefordert(_ w: Int) -> Zeile {
        Zeile(kopf: L("\(prozent(w)) angefordert", "\(prozent(w)) requested"),
              rest: L("noch nicht bestätigt, kann einige Minuten dauern",
                      "not confirmed yet, may take a few minutes"))
    }

    static var schonend: String { L("SCHONEND", "BATTERY CARE") }
    static var faustregel: String { L("Faustregel am Netzteil: 50–60\u{00A0}%", "Rule of thumb when plugged in: 50–60%") }
    static var appleStufen: String { L("APPLE-STUFEN", "APPLE LEVELS") }
    static func grenzeSetzen(_ w: Int) -> String { L("Grenze auf \(prozent(w)) setzen", "Set limit to \(prozent(w))") }
    static var wertWaehlen: String { L("Wert wählen", "Choose a value") }
    static var hatNichtGeklappt: String { L("Hat nicht geklappt", "Couldn't set the limit") }
    static func kennwortHinweis(_ w: Int) -> String {
        L("ChargeLimit möchte die Ladegrenze auf \(prozent(w)) setzen.",
          "ChargeLimit wants to set the charge limit to \(prozent(w)).")
    }
    static var zurueckstellen: String {
        L("Zurückstellen geht auch über Systemeinstellungen → Batterie (dort steht bei Schonend-Werten „0\u{00A0}%“).",
          "You can also change the limit in System Settings → Battery (it shows “0%” there for battery-care values).")
    }
    static var autostart: String { L("Autostart", "Open at login") }
    static var erlauben: String { L("In Systemeinstellungen erlauben", "Allow in System Settings") }
    static var fertig: String { L("Fertig", "Done") }
    static var appBeenden: String { L("⏻ App beenden", "⏻ Quit app") }
    static var beendenFrage: String { L("ChargeLimit beenden?", "Quit ChargeLimit?") }
    static var beendenInfo: String {
        L("Das Symbol verschwindet aus der Menüleiste. Ihre Ladegrenze bleibt bestehen.",
          "The icon disappears from the menu bar. Your charge limit stays in place.")
    }
    static var beenden: String { L("Beenden", "Quit") }
    static var abbrechen: String { L("Abbrechen", "Cancel") }
    static var keinAkku: String { L("Dieser Rechner hat keinen Akku.", "This computer has no battery.") }
    static var keinAkkuInfo: String {
        L("ChargeLimit ist für MacBooks. Die App wird wieder beendet.",
          "ChargeLimit is made for MacBooks. The app will now quit.")
    }
    static var okBeenden: String { L("OK, beenden", "OK, Quit") }
}
