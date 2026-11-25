import Testing
@testable import ChargeLimitKit

// Aus Paket 0 — Paket A ergänzt weitere Tests in eigenen Dateien.
@Test func werteliste_hat_genau_die_13_werte() {
    #expect(Stufen.schonend + Stufen.apple == [30, 35, 40, 45, 50, 55, 60, 65, 80, 85, 90, 95, 100])
}
