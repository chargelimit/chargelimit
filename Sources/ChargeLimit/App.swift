// App.swift — Menüleisten-Programm, kein Dock-Symbol (LSUIElement in bauen.sh)
import SwiftUI
import ChargeLimitKit

@main
struct ChargeLimitApp: App {
    @State private var modell = Modell.geteilt

    init() { Modell.geteilt.starten() }

    var body: some Scene {
        MenuBarExtra("ChargeLimit", systemImage: "battery.75percent") {
            Fenster(modell: modell).id(modell.sprache)
        }
        .menuBarExtraStyle(.window)
    }
}
