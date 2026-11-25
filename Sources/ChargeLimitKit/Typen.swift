// ChargeLimitKit/Typen.swift — gemeinsame Verabredung zwischen Paket A und B
public enum Stufen {
    public static let schonend: [Int] = [30, 35, 40, 45, 50, 55, 60, 65]
    public static let apple: [Int] = [80, 85, 90, 95, 100]
    public static func erlaubt(_ wert: Int) -> Bool { schonend.contains(wert) || apple.contains(wert) }
}

public struct AkkuStand: Equatable, Sendable {
    public var prozent: Int
    public var amNetzteil: Bool
    public var laedt: Bool
    /// nil = nicht lesbar oder Einträge uneinig · 100 = keine Grenze
    public var grenze: Int?
    public init(prozent: Int, amNetzteil: Bool, laedt: Bool, grenze: Int?) {
        self.prozent = prozent; self.amNetzteil = amNetzteil; self.laedt = laedt; self.grenze = grenze
    }
    public static let vorschau: [AkkuStand] = [
        AkkuStand(prozent: 72, amNetzteil: true, laedt: false, grenze: 60),
        AkkuStand(prozent: 80, amNetzteil: true, laedt: false, grenze: 80),
        AkkuStand(prozent: 55, amNetzteil: true, laedt: true, grenze: 60),
        AkkuStand(prozent: 64, amNetzteil: false, laedt: false, grenze: nil),
    ]
}

public enum Zustand: Equatable, Sendable {
    case laedtBis(Int), haelt(Int), sinktAuf(Int), keineGrenze, laedtVoll, amAkku, unbekannt
}

public func zustand(_ s: AkkuStand) -> Zustand {
    guard s.amNetzteil else { return .amAkku }
    guard let g = s.grenze else { return .unbekannt }
    if g == 100 { return .keineGrenze }
    if s.laedt { return s.prozent > g ? .laedtVoll : .laedtBis(g) }
    return s.prozent > g ? .sinktAuf(g) : .haelt(g)
}

public enum SetzenErgebnis: Equatable, Sendable {
    /// Befehl lief ohne Fehler (heißt NICHT: Apple hat schon übernommen)
    case gesetzt
    case abgebrochen
    case fehler(String)
}

// Paket A liefert in Akku.swift bzw. Setzen.swift (Paket 0 legt dort Platzhalter an):
//   public func liesAkku() async -> AkkuStand?               // nil = `pmset -g batt` nicht auswertbar
//   public func setzen(_ wert: Int, hinweis: String) async -> SetzenErgebnis
//       Wert außerhalb von Stufen → .fehler, es läuft nichts.
//       `hinweis` = Text im Kennwort-Fenster, kommt fertig übersetzt aus der App (Paket B, L(de, en));
//       Paket A maskiert " und \ für den AppleScript-Text.
//       100 = Apples Aufruf `disableMCL:` ohne Kennwort (Plan 4.3) — `hinweis` bleibt dann ungenutzt.
