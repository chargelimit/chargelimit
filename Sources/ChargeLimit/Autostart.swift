// Autostart.swift — Anmeldeobjekt über SMAppService (Plan 4.7, Muster LocDict LaunchAtLogin.swift)
import Foundation
import ServiceManagement

enum Autostart {
    /// Der von macOS gelesene Zustand; grüner Haken nur bei `.enabled`.
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    /// Klick auf den Schalter: an → aus; „wartet auf Erlaubnis“ → Systemeinstellungen öffnen
    /// (nicht erneut registrieren); sonst → einschalten.
    static func umschalten() {
        do {
            switch status {
            case .enabled: try SMAppService.mainApp.unregister()
            case .requiresApproval: SMAppService.openSystemSettingsLoginItems()
            default: try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("ChargeLimit Autostart: \(error.localizedDescription)")
        }
    }

    static func erlaubenOeffnen() { SMAppService.openSystemSettingsLoginItems() }
}
