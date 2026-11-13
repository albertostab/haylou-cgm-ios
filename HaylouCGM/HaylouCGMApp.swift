import SwiftUI
import BackgroundTasks
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: BridgeModel.refreshID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: BridgeModel.refreshID, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            Self.scheduleBackgroundRefresh()
            let bridge = BridgeModel.shared
            guard bridge.automatic else { task.setTaskCompleted(success: true); return }
            task.expirationHandler = { task.setTaskCompleted(success: false) }
            bridge.refreshNow { success in task.setTaskCompleted(success: success) }
        }
        if BridgeModel.shared.automatic { Self.scheduleBackgroundRefresh() }
        return true
    }
}

@main
struct HaylouCGMApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var bridge = BridgeModel.shared
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            BridgeView(bridge: bridge)
                .onChange(of: phase) { newPhase in
                    bridge.handleForeground(newPhase == .active)
                }
        }
    }
}

struct BridgeView: View {
    @ObservedObject var bridge: BridgeModel
    private var df: DateFormatter {
        let d = DateFormatter()
        d.dateStyle = .short; d.timeStyle = .medium
        d.timeZone = TimeZone(identifier: "Europe/Rome")
        return d
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(spacing: 12) {
                        Text(bridge.latest == nil ? "—" : String(bridge.latest!.value))
                            .font(.system(size: 67, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("mg/dL · \(bridge.latest?.direction ?? "—")").font(.headline)
                        if let reading = bridge.latest {
                            Text("Lettura: \(df.string(from: reading.date))")
                                .font(.caption)
                            if !reading.fresh { Text("ATTENZIONE: LETTURA NON RECENTE").foregroundStyle(.orange).fontWeight(.bold) }
                            if reading.value < 70 { Text("IPOglicemia: verifica subito sul Libre e correggi secondo il tuo piano").foregroundStyle(.red).fontWeight(.bold).multilineTextAlignment(.center) }
                            if let a = reading.approx {
                                Text("Display sperimentale: ≈\(a.shownFahrenheit) °F (±\(a.difference))").font(.caption)
                            } else {
                                Text("Fuori scala per il campo meteo: NON trasmesso").foregroundStyle(.orange)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))

                    GroupBox("1 · Nightscout") {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("URL Nightscout", text: $bridge.nightscoutURL)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .keyboardType(.URL).textContentType(.URL)
                                .textFieldStyle(.roundedBorder)
                            SecureField("Token readonly Nightscout", text: $bridge.token)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)
                            HStack {
                                Button("Salva") { bridge.saveSettings() }
                                Spacer()
                                Button("Verifica lettura") { bridge.saveSettings(); bridge.refreshNow() }
                            }.buttonStyle(.borderedProminent)
                            Text(bridge.nightscoutStatus).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    GroupBox("2 · Bluetooth Haylou RT2") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(bridge.bluetoothStatus).font(.subheadline).bold()
                            Button("Cerca orologio") { bridge.beginScan() }
                                .buttonStyle(.borderedProminent)
                            ForEach(bridge.scanResults, id: \.identifier) { device in
                                Button("Connetti: \(device.name ?? "Haylou")") { bridge.connect(device) }
                                    .buttonStyle(.bordered)
                            }
                            Text("La ricerca non deve competere con Haylou Fun. Nessun pairing automatico.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    GroupBox("3 · Aggiornamento sperimentale") {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Invia automaticamente nuove letture", isOn: Binding(
                                get: { bridge.automatic }, set: { bridge.setAutomatic($0) }
                            ))
                            Text("Polling 60 secondi quando l'app è attiva. In background, iOS decide quando eseguire controlli: nessuna frequenza garantita.")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("Il valore sull'orologio è in °F e NON rappresenta una glicemia medica affidabile. Può rimanere vecchio quando l'app è sospesa. Non sostituisce il FreeStyle Libre né gli allarmi.")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    GroupBox("4 · Diagnostica") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ultima scrittura richiesta: \(bridge.lastQueued.map { df.string(from: $0) } ?? "Mai")")
                            Text("Ultimo dato richiesto: \(bridge.lastQueuedReading > 0 ? df.string(from: Date(timeIntervalSince1970: Double(bridge.lastQueuedReading) / 1000)) : "Mai")")
                            Text("Ricezione BLE: \(bridge.lastReply)")
                            Text(bridge.diagnostic)
                            Text("Write Without Response: richiesta di invio ≠ aggiornamento confermato del display.")
                                .foregroundStyle(.orange)
                        }.font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .navigationTitle("Haylou CGM")
        }
    }
}
