import Testing
@testable import ChargeLimitKit

private func s(_ p: Int, netz: Bool = true, laedt: Bool = false, _ g: Int?) -> AkkuStand {
    AkkuStand(prozent: p, amNetzteil: netz, laedt: laedt, grenze: g)
}

@Test func zustand_alle_sieben_faelle() {
    #expect(zustand(s(55, laedt: true, 60)) == .laedtBis(60))
    #expect(zustand(s(60, 60)) == .haelt(60))
    #expect(zustand(s(72, 60)) == .sinktAuf(60))
    #expect(zustand(s(80, 100)) == .keineGrenze)
    #expect(zustand(s(70, laedt: true, 60)) == .laedtVoll)
    #expect(zustand(s(64, netz: false, 60)) == .amAkku)
    #expect(zustand(s(64, nil)) == .unbekannt)
}

@Test func zustand_grenzfaelle() {
    #expect(zustand(s(60, laedt: true, 60)) == .laedtBis(60))   // Stand = Grenze beim Laden
    #expect(zustand(s(61, laedt: true, 60)) == .laedtVoll)      // Stand > Grenze beim Laden
    #expect(zustand(s(57, 60)) == .haelt(60))                   // Stand < Grenze ohne Laden
}
