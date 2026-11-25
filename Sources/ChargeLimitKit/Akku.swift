// ChargeLimitKit/Akku.swift — Akku und Ladegrenze lesen, ohne Kennwort (Plan 4.2)
import Foundation
import IOKit.ps

/// Hat dieser Mac einen eingebauten Akku? Apples Stromquellen-Liste (IOKit, öffentlich; dieselbe Quelle wie `pmset -g batt`):
/// eine Quelle vom Typ „InternalBattery“ — eine USV zählt nicht. Gemessen 24.11.: MacBook ja; Mac Studio nein (`pmset`
/// zeigt nur „AC Power“). NICHT über den Treiber `AppleSmartBattery` — den hat auch der Mac Studio (Amperage 0).
/// Liste nicht lesbar → true (beenden nur, wenn sicher kein Akku da ist).
public func hatEingebautenAkku() -> Bool {
    guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
          let liste = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return true }
    return liste.contains { quelle in
        let d = IOPSGetPowerSourceDescription(info, quelle)?.takeUnretainedValue() as? [String: Any]
        return d?[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
    }
}

/// Liest `pmset -g batt` und `pmset -g battlimit` (nicht auf dem Hauptthread).
/// nil = `pmset -g batt` nicht auswertbar.
public func liesAkku() async -> AkkuStand? {
    async let batt = fuehreAus("/usr/bin/pmset", ["-g", "batt"])
    async let limit = fuehreAus("/usr/bin/pmset", ["-g", "battlimit"])
    guard let b = await batt, b.ausgang == 0 else { return nil }
    let l = await limit
    return akkuStand(batt: b.ausgabe, battlimit: l?.ausgang == 0 ? l?.ausgabe : nil)
}

/// Fügt beide Ausgaben zusammen. Am Akku ist die Grenze nicht lesbar (nil): macOS meldet dort nach etwa 5 Min
/// „No battery level limits set“, obwohl die Grenze bleibt (Probelauf 24.11.).
func akkuStand(batt: String, battlimit: String?) -> AkkuStand? {
    guard let werte = werteAusBatt(batt) else { return nil }
    let grenze = werte.amNetzteil ? grenzeAusBattlimit(battlimit) : nil
    return AkkuStand(prozent: werte.prozent, amNetzteil: werte.amNetzteil, laedt: werte.laedt, grenze: grenze)
}

/// Auswertung von `pmset -g batt`: Netzteil = erste Zeile enthält 'AC Power'; Ladestand = Zahl vor `%;`;
/// lädt = enthält `; charging;`.
func werteAusBatt(_ text: String) -> (prozent: Int, amNetzteil: Bool, laedt: Bool)? {
    guard let ersteZeile = text.split(separator: "\n").first,
          let treffer = text.firstMatch(of: /(\d+)%;/), let prozent = Int(treffer.1) else { return nil }
    return (prozent, ersteZeile.contains("'AC Power'"), text.contains("; charging;"))
}

/// Auswertung von `pmset -g battlimit`: nil-Text = Befehl gescheitert → nil;
/// „No battery level limits set“ → 100; alle `chargeSocLimitSoc` gleich → N; uneinig oder keiner → nil.
func grenzeAusBattlimit(_ text: String?) -> Int? {
    guard let text else { return nil }
    if text.contains("No battery level limits set") { return 100 }
    let werte = Set(text.matches(of: /chargeSocLimitSoc = (\d+);/).compactMap { Int($0.1) })
    return werte.count == 1 ? werte.first : nil
}

// MARK: - Programme starten (gemeinsam mit Setzen.swift)

struct Ausgabe: Sendable {
    var ausgang: Int32
    var ausgabe: String
    var fehlertext: String
}

/// Startet ein Programm auf einem Hintergrund-Thread und wartet auf sein Ende. nil = ließ sich nicht starten.
func fuehreAus(_ pfad: String, _ argumente: [String]) async -> Ausgabe? {
    await withCheckedContinuation { fortsetzung in
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: pfad)
            p.arguments = argumente
            let aus = Pipe(), fehler = Pipe()
            p.standardOutput = aus
            p.standardError = fehler
            do { try p.run() } catch { fortsetzung.resume(returning: nil); return }
            let a = aus.fileHandleForReading.readDataToEndOfFile()
            let f = fehler.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            fortsetzung.resume(returning: Ausgabe(ausgang: p.terminationStatus,
                                                  ausgabe: String(decoding: a, as: UTF8.self),
                                                  fehlertext: String(decoding: f, as: UTF8.self)))
        }
    }
}
