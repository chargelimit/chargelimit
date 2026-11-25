import Testing
@testable import ChargeLimitKit

// Nur reine Hilfsfunktionen — `setzen(…)` wird in Tests nie aufgerufen (Schutzregel).

@Test(arguments: [0, 25, 29, 31, 70, 75, 79, 81, 101, -5])
func verweigert_werte_ausserhalb_der_stufen(_ wert: Int) {
    #expect(!Stufen.erlaubt(wert))
    #expect(weg(wert) == .verweigert)
}

@Test(arguments: [30, 60, 95])
func befehlstext_fuer_kennwort_weg(_ wert: Int) throws {
    guard case .kennwort(let befehl) = weg(wert) else { Issue.record("kein Kennwort-Weg für \(wert)"); return }
    let datei = "/var/root/Library/Preferences/com.apple.smartcharging.topoffprotection"
    #expect(befehl == "/usr/bin/defaults write \(datei) MCLFeatureState -int 1"
        + " && /usr/bin/defaults write \(datei) mclLimitValue -int \(wert)"
        + " && /usr/bin/notifyutil -p com.apple.smartcharging.defaultschanged")
    #expect(befehl.contains("MCLFeatureState -int 1"))
    #expect(!befehl.contains("MCLFeatureState -int 0"))
}

@Test func alle_erlaubten_werte_ausser_100_gehen_den_kennwort_weg() {
    for wert in Stufen.schonend + Stufen.apple where wert != 100 {
        guard case .kennwort(let befehl) = weg(wert) else { Issue.record("\(wert)"); continue }
        #expect(befehl.contains("mclLimitValue -int \(wert) "))
    }
}

@Test func hundert_baut_keinen_befehlstext_und_kein_osascript() {
    #expect(weg(100) == .ausschalten)
}

@Test func abbruch_wird_erkannt() {
    let a = Ausgabe(ausgang: 1, ausgabe: "", fehlertext: "0:120: execution error: User canceled. (-128)\n")
    #expect(ergebnis(a) == .abgebrochen)
}

@Test func ausgang_null_ist_gesetzt_und_sonst_fehler_mit_text() {
    #expect(ergebnis(Ausgabe(ausgang: 0, ausgabe: "", fehlertext: "")) == .gesetzt)
    #expect(ergebnis(Ausgabe(ausgang: 1, ausgabe: "", fehlertext: "execution error: kaputt (1)\n"))
        == .fehler("execution error: kaputt (1)"))
    #expect(ergebnis(Ausgabe(ausgang: 1, ausgabe: "", fehlertext: "")) == .fehler("osascript endete mit 1"))
}

@Test func hinweis_wird_fuer_applescript_maskiert() {
    let s = appleScript(befehl: "/usr/bin/true", hinweis: #"Sag "ja" \ bitte"#)
    #expect(s == #"do shell script "/usr/bin/true" with administrator privileges with prompt "Sag \"ja\" \\ bitte""#)
}
