import Foundation
import Testing
@testable import ChargeLimitKit

// Echte Ausgaben vom 24.11.2026 (Plan 4.2, Probelauf-Protokoll, Schritt 0).

let zweiMal80 = """
Battery level limits:
(
        {
        Terminated = 0;
        chargeSocLimitDrain = 1;
        chargeSocLimitIsEOC = 1;
        chargeSocLimitNoChargeToFull = 0;
        chargeSocLimitOwner = 483;
        chargeSocLimitReason = manualChargeLimit;
        chargeSocLimitSoc = 80;
    },
        {
        Terminated = 0;
        chargeSocLimitDrain = 1;
        chargeSocLimitIsEOC = 1;
        chargeSocLimitNoChargeToFull = 0;
        chargeSocLimitOwner = 0;
        chargeSocLimitReason = manualChargeLimit;
        chargeSocLimitSoc = 80;
    }
)
"""

@Test func grenze_zwei_eintraege_80() {
    #expect(grenzeAusBattlimit(zweiMal80) == 80)
}

@Test func grenze_keine() {
    #expect(grenzeAusBattlimit("No battery level limits set\n") == 100)
}

@Test func grenze_uneinig_oder_gescheitert() {
    let uneinig = zweiMal80.replacingOccurrences(of: "chargeSocLimitOwner = 0;\n        chargeSocLimitReason = manualChargeLimit;\n        chargeSocLimitSoc = 80;",
                                                 with: "chargeSocLimitOwner = 0;\n        chargeSocLimitReason = manualChargeLimit;\n        chargeSocLimitSoc = 65;")
    #expect(uneinig != zweiMal80)
    #expect(grenzeAusBattlimit(uneinig) == nil)
    #expect(grenzeAusBattlimit(nil) == nil)
    #expect(grenzeAusBattlimit("") == nil)
}

@Test func batt_laedt_nicht_am_netzteil() throws {
    let w = try #require(werteAusBatt("Now drawing from 'AC Power'\n -InternalBattery-0 (id=24510563)\t80%; AC attached; not charging present: true\n"))
    #expect(w.prozent == 80 && w.amNetzteil && !w.laedt)
}

@Test func batt_laedt() throws {
    let w = try #require(werteAusBatt("Now drawing from 'AC Power'\n -InternalBattery-0 (id=24510563)\t63%; charging; (no estimate) present: true\n"))
    #expect(w.prozent == 63 && w.amNetzteil && w.laedt)
}

@Test func batt_akkubetrieb() throws {
    let w = try #require(werteAusBatt("Now drawing from 'Battery Power'\n -InternalBattery-0 (id=24510563)\t64%; discharging; 1:56 remaining present: true\n"))
    #expect(w.prozent == 64 && !w.amNetzteil && !w.laedt)
}

@Test func am_akku_ist_die_grenze_nicht_lesbar() {
    // Probelauf 24.11.: am Akku meldet macOS nach ~5 Min „No battery level limits set“, die Grenze bleibt aber.
    let akku = "Now drawing from 'Battery Power'\n -InternalBattery-0 (id=24510563)\t64%; discharging; 1:56 remaining present: true\n"
    #expect(akkuStand(batt: akku, battlimit: "No battery level limits set\n")?.grenze == nil)
    let netz = "Now drawing from 'AC Power'\n -InternalBattery-0 (id=24510563)\t80%; AC attached; not charging present: true\n"
    #expect(akkuStand(batt: netz, battlimit: zweiMal80) == AkkuStand(prozent: 80, amNetzteil: true, laedt: false, grenze: 80))
    #expect(akkuStand(batt: netz, battlimit: "No battery level limits set\n")?.grenze == 100)
}

/// Gerätetest (läuft auf dem MacBook des Nutzers): ein eingebauter Akku wird erkannt → die App beendet sich nicht.
@Test func dieses_macbook_hat_einen_akku() {
    #expect(hatEingebautenAkku())
}

@Test func batt_nicht_auswertbar() {
    #expect(werteAusBatt("") == nil)
    #expect(werteAusBatt("Now drawing from 'AC Power'\n") == nil)
}

/// Liest nur (pmset -g batt / battlimit) und gibt aus — ändert nichts.
@Test func echt_lesen_nur_ausgeben() async {
    let s = await liesAkku()
    print("liesAkku() echt:", s as Any)
    #expect(s != nil)
}
