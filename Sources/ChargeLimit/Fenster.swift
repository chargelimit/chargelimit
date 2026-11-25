// Fenster.swift — das Menüleisten-Fenster (Plan 3, Entwurf outputs/berichte/chargelimit-bauplan-2026-11-24.html)
import AppKit
import SwiftUI
import ChargeLimitKit

/// Schonend = grün, Apple-Stufen = blau
func farbe(_ wert: Int) -> Color { wert < 80 ? .green : .blue }

struct Fenster: View {
    let modell: Modell
    @Environment(\.colorScheme) private var schema

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            kopf
            AkkuBild(stand: modell.stand)
                .padding(.top, 20).padding(.bottom, 6)
            Text(zustandsText).padding(.top, 2).padding(.bottom, 12)
                .fixedSize(horizontal: false, vertical: true)

            gruppenKopf(T.schonend, T.faustregel)
            knopfRaster(Stufen.schonend, spalten: 4)
            gruppenKopf(T.appleStufen, nil)
            knopfRaster(Stufen.apple, spalten: 5)

            setzenKnopf.padding(.top, 12).padding(.bottom, 6)
            if modell.fehlgeschlagen {
                Text(T.hatNichtGeklappt).font(.system(size: 11.5)).foregroundStyle(.red).padding(.bottom, 4)
            }
            Text(T.zurueckstellen).font(.system(size: 11.5)).opacity(0.62)
                .fixedSize(horizontal: false, vertical: true)

            Divider().padding(.horizontal, -14).padding(.top, 9).padding(.bottom, 6)
            fusszeile
            Button(T.appBeenden) { Self.beendenFragen() }
                .buttonStyle(.plain).font(.system(size: 11.5)).opacity(0.5)
                .padding(.top, 5).padding(.bottom, 1)
        }
        .font(.system(size: 13))
        .monospacedDigit()
        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)
        .frame(width: 300)
    }

    // MARK: Teile

    private var kopf: some View {
        HStack(alignment: .top) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let g = modell.stand?.grenze {
                    Text(prozent(g)).foregroundStyle(textFarbe(farbe(g)))
                } else {
                    Text("–").foregroundStyle(.secondary)
                }
                Text(T.ladegrenze).font(.system(size: 13, weight: .medium)).opacity(0.65)
            }
            .font(.system(size: 34, weight: .semibold))
            Spacer()
            HStack(spacing: 4) {
                fahne("🇩🇪", .de)
                fahne("🇬🇧", .en)
            }
            .padding(.top, 2)
        }
    }

    /// Fähnchen wie LocDict: aktive Sprache voll, andere 40 %.
    private func fahne(_ symbol: String, _ ziel: Sprache) -> some View {
        Button { modell.sprache = ziel } label: {
            Text(symbol).font(.system(size: 19)).opacity(modell.sprache == ziel ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .help(ziel == .de ? "Deutsch" : "English")
    }

    private var zustandsText: AttributedString {
        guard modell.gelesen else { return AttributedString(" ") }
        guard let s = modell.stand else { return zeileText(T.nichtLesbar, vorne: nil) }
        let z = modell.merkerAktiv ? T.angefordert(modell.angefordert ?? 0)
                                   : T.zeile(zustand(s), grenze: s.grenze)
        return zeileText(z, vorne: T.akku(s.prozent))
    }

    private func zeileText(_ z: Zeile, vorne: String?) -> AttributedString {
        var text = AttributedString(vorne.map { "\($0) · " } ?? "")
        var fett = AttributedString(z.kopf)
        fett.inlinePresentationIntent = .stronglyEmphasized
        text.append(fett)
        if !z.rest.isEmpty { text.append(AttributedString(" – \(z.rest)")) }
        return text
    }

    private func gruppenKopf(_ titel: String, _ zusatz: String?) -> some View {
        var text = AttributedString(titel)
        text.font = .system(size: 10.5, weight: .semibold)
        text.kern = 0.4
        if let zusatz { text.append(AttributedString(" · \(zusatz)")) }
        return Text(text).font(.system(size: 10.5))
            .fixedSize(horizontal: false, vertical: true)
            .opacity(0.6)
        .padding(.top, 8).padding(.bottom, 5)
    }

    private func knopfRaster(_ werte: [Int], spalten: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: spalten), spacing: 6) {
            ForEach(werte, id: \.self) { wert in
                Button("\(wert)") { modell.antippen(wert) }
                    .buttonStyle(StufenKnopf(farbe: farbe(wert), schema: schema,
                                             gilt: modell.stand?.grenze == wert,
                                             angetippt: modell.angetippt == wert))
            }
        }
        .disabled(modell.gesperrt || modell.setztGerade)
        .opacity(modell.gesperrt ? 0.45 : 1)
    }

    private var setzenKnopf: some View {
        let wert = modell.gesperrt ? nil : modell.neuerWert
        return Button(wert.map { T.grenzeSetzen($0) } ?? T.wertWaehlen) {
            Task { await modell.setzenAngetippt() }
        }
        .buttonStyle(SetzenKnopf(farbe: wert.map(farbe), schema: schema))
        .disabled(wert == nil || modell.setztGerade)
    }

    private var fusszeile: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button { modell.autostartUmschalten() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: modell.autostart == .enabled ? "checkmark" : "xmark")
                            .font(.system(size: 9, weight: .heavy)).foregroundStyle(.white)
                            .frame(width: 17, height: 17)
                            .background(Circle().fill(modell.autostart == .enabled ? Color.green : Color.red))
                        Text(T.autostart)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                Button(T.fertig) { NSApp.keyWindow?.close() }
            }
            if modell.autostart == .requiresApproval {
                Button(T.erlauben) { Autostart.erlaubenOeffnen() }
                    .buttonStyle(.link).font(.system(size: 11.5))
            }
        }
        .padding(.vertical, 2)
    }

    /// Text in Gruppenfarbe, im Hellen etwas dunkler (wie Entwurf), im Dunkeln etwas heller.
    private func textFarbe(_ c: Color) -> Color {
        schema == .dark ? c.mix(with: .white, by: 0.25) : c.mix(with: .black, by: 0.3)
    }

    /// Rückfrage vor dem Beenden; Eingabetaste = Abbrechen. Die Grenze bleibt (Schutzregel 2).
    static func beendenFragen() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = T.beendenFrage
        alert.informativeText = T.beendenInfo
        alert.addButton(withTitle: T.abbrechen)
        alert.addButton(withTitle: T.beenden)
        // Ausdrücklich: Ein Knopf namens „Cancel“ bekäme sonst Esc statt der Eingabetaste (Abnahme 24.11.: nur Fehlerton).
        alert.buttons[0].keyEquivalent = "\r"
        if alert.runModal() == .alertSecondButtonReturn { NSApp.terminate(nil) }
    }

    /// Mac ohne eingebauten Akku (iMac, Mac mini, Mac Studio): Hinweis, dann beenden (Wunsch des Nutzers 24.11.).
    static func keinAkkuUndBeenden() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = T.keinAkku
        alert.informativeText = T.keinAkkuInfo
        alert.addButton(withTitle: T.okBeenden)
        alert.runModal()
        NSApp.terminate(nil)
    }
}

// MARK: Akku-Bild — Füllung = Ladestand, dünne Linie = Grenze

struct AkkuBild: View {
    let stand: AkkuStand?

    var body: some View {
        HStack(spacing: 2) {
            GeometryReader { geo in
                let innen = geo.size.width - 4
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5).strokeBorder(Color(nsColor: .systemGray), lineWidth: 1.5)
                    if let s = stand {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(s.grenze.map(farbe) ?? Color(nsColor: .systemGray))
                            .frame(width: innen * CGFloat(min(max(s.prozent, 0), 100)) / 100)
                            .padding(2)
                    }
                    if let g = stand?.grenze, g < 100 {
                        let x = 2 + innen * CGFloat(g) / 100
                        Rectangle().fill(.primary).frame(width: 2, height: geo.size.height + 12)
                            .position(x: x, y: geo.size.height / 2)
                        Text("\(g)").font(.system(size: 10, weight: .semibold))
                            .position(x: x, y: -9)
                    }
                }
            }
            .frame(height: 22)
            RoundedRectangle(cornerRadius: 2).fill(Color(nsColor: .systemGray)).frame(width: 4, height: 9)
        }
    }
}

// MARK: Knopf-Stile

/// Schrift auf gefüllten Knöpfen: im Dunkel-Modus leuchtet Grün hell → schwarz (Wunsch des Nutzers 24.11.), sonst weiß.
func schriftAufFuellung(_ farbe: Color, _ schema: ColorScheme) -> Color {
    schema == .dark && farbe == .green ? .black : .white
}

/// Stufen-Knopf: getönt; geltender Wert = Ring, angetippter Wert = gefüllt.
struct StufenKnopf: ButtonStyle {
    let farbe: Color
    let schema: ColorScheme
    let gilt: Bool
    let angetippt: Bool

    func makeBody(configuration: Configuration) -> some View {
        let text = schema == .dark ? farbe.mix(with: .white, by: 0.35) : farbe.mix(with: .black, by: 0.35)
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .frame(maxWidth: .infinity).frame(height: 28)
            .foregroundStyle(angetippt ? schriftAufFuellung(farbe, schema) : text)
            .background(RoundedRectangle(cornerRadius: 7)
                .fill(angetippt ? farbe : farbe.opacity(schema == .dark ? 0.2 : 0.14)))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(farbe, lineWidth: gilt ? 2 : 0))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}

/// „Grenze auf X % setzen“: gefüllt in Gruppenfarbe, sonst grau („Wert wählen“).
struct SetzenKnopf: ButtonStyle {
    let farbe: Color?
    let schema: ColorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .frame(maxWidth: .infinity).frame(height: 30)
            .foregroundStyle(farbe.map { AnyShapeStyle(schriftAufFuellung($0, schema)) } ?? AnyShapeStyle(.primary.opacity(0.35)))
            .background(RoundedRectangle(cornerRadius: 7)
                .fill(farbe.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.primary.opacity(0.06))))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}
