// ChargeLimitKit/Setzen.swift — Ladegrenze setzen (Plan 4.3, Schutzregel 3)
import Foundation
import ObjectiveC

/// Setzt die Ladegrenze. Wert außerhalb von `Stufen` → `.fehler`, es läuft nichts.
/// 30–95: Kennwort-Fenster über osascript · 100: Apples Aufruf `disableMCL:` ohne Kennwort (`hinweis` ungenutzt).
public func setzen(_ wert: Int, hinweis: String) async -> SetzenErgebnis {
    switch weg(wert) {
    case .verweigert:
        return .fehler("Wert \(wert) ist nicht erlaubt")
    case .kennwort(let befehl):
        guard let a = await fuehreAus("/usr/bin/osascript", ["-e", appleScript(befehl: befehl, hinweis: hinweis)]) else {
            return .fehler("osascript ließ sich nicht starten")
        }
        return ergebnis(a)
    case .ausschalten:
        return await grenzeAusschalten()
    }
}

/// Welcher Weg für einen Wert gilt — der einzige Ort, an dem aus einem Wert ein Befehl wird.
enum Weg: Equatable {
    case verweigert
    case kennwort(String)
    case ausschalten
}

func weg(_ wert: Int) -> Weg {
    guard Stufen.erlaubt(wert) else { return .verweigert }
    if wert == 100 { return .ausschalten }
    return .kennwort(befehlstext(wert))
}

/// Befehl für 30–95 (im Probelauf so gelaufen). Nur über `weg(_:)` aufrufen — dort ist der Wert geprüft.
/// Nie „MCLFeatureState 0“ schreiben (Messung M3).
private func befehlstext(_ wert: Int) -> String {
    let datei = "/var/root/Library/Preferences/com.apple.smartcharging.topoffprotection"
    return "/usr/bin/defaults write \(datei) MCLFeatureState -int 1"
        + " && /usr/bin/defaults write \(datei) mclLimitValue -int \(wert)"
        + " && /usr/bin/notifyutil -p com.apple.smartcharging.defaultschanged"
}

func appleScript(befehl: String, hinweis: String) -> String {
    "do shell script \"\(maskiert(befehl))\" with administrator privileges with prompt \"\(maskiert(hinweis))\""
}

/// Maskiert `\` und `"` für einen AppleScript-Text.
func maskiert(_ text: String) -> String {
    text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
}

/// Ausgang 0 → gesetzt · Fehlertext mit „-128“ (Kennwort-Fenster abgebrochen) → abgebrochen · sonst Fehler.
func ergebnis(_ a: Ausgabe) -> SetzenErgebnis {
    if a.ausgang == 0 { return .gesetzt }
    if a.fehlertext.contains("-128") { return .abgebrochen }
    let text = a.fehlertext.trimmingCharacters(in: .whitespacesAndNewlines)
    return .fehler(text.isEmpty ? "osascript endete mit \(a.ausgang)" : text)
}

/// Apples Aufruf `disableMCL:` (PowerUISmartChargeClient, privates PowerUI.framework) auf einem Hintergrund-Thread.
/// Vorlage: recherche/proben/aus-aufruf.swift (am Gerät gemessen, M4.2). Idee aus batt, eigener Code.
private func grenzeAusschalten() async -> SetzenErgebnis {
    await withCheckedContinuation { fortsetzung in
        DispatchQueue.global(qos: .userInitiated).async {
            guard dlopen("/System/Library/PrivateFrameworks/PowerUI.framework/Versions/A/PowerUI", RTLD_NOW) != nil,
                  let klasse = NSClassFromString("PowerUISmartChargeClient") as? NSObject.Type,
                  klasse.instancesRespond(to: NSSelectorFromString("initWithClientName:")),
                  klasse.instancesRespond(to: NSSelectorFromString("disableMCL:")),
                  let roh = klasse.perform(NSSelectorFromString("alloc"))?.takeUnretainedValue() else {
                fortsetzung.resume(returning: .fehler("PowerUISmartChargeClient nicht verfügbar")); return
            }
            typealias InitFn = @convention(c) (AnyObject, Selector, NSString) -> AnyObject?
            let initSel = NSSelectorFromString("initWithClientName:")
            let initImp = unsafeBitCast(class_getMethodImplementation(klasse, initSel), to: InitFn.self)
            guard let client = initImp(roh, initSel, "ChargeLimit") as? NSObject else {
                fortsetzung.resume(returning: .fehler("PowerUISmartChargeClient: init fehlgeschlagen")); return
            }
            // Bewusst nie freigegeben: die Besitzregeln über den C-Zeiger sind unklar, ein Überfreigeben würde abstürzen.
            _ = Unmanaged.passRetained(client)
            typealias BoolErr = @convention(c) (AnyObject, Selector, UnsafeMutablePointer<NSError?>) -> Bool
            let sel = NSSelectorFromString("disableMCL:")
            let f = unsafeBitCast(class_getMethodImplementation(type(of: client), sel), to: BoolErr.self)
            var fehler: NSError? = nil
            let ok = f(client, sel, &fehler)
            fortsetzung.resume(returning: ok ? .gesetzt
                : .fehler(fehler?.localizedDescription ?? "disableMCL: lehnte ab"))
        }
    }
}
