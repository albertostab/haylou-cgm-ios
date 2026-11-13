import Foundation

import SwiftUI

import CoreBluetooth

import UIKit

import BackgroundTasks



/// Prototipo NON medicale: il watch non comunica l'effettivo aggiornamento del display.

/// iOS non garantisce polling a intervalli fissi in background.

final class BridgeModel: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    static let shared = BridgeModel()

    static let refreshID = "it.albertostabile.haylou-cgm.refresh"



    @Published var nightscoutURL: String = ""

    @Published var token: String = ""

    @Published var nightscoutStatus = "Da verificare"

    @Published var bluetoothStatus = "Bluetooth non inizializzato"

    @Published var automatic = false

    @Published var scanResults: [CBPeripheral] = []

    @Published var latest: Reading?

    @Published var lastQueued: Date?

    @Published var lastQueuedReading: Int64 = 0

    @Published var lastReply = "Nessuna risposta ricevuta"

    @Published var diagnostic = "Avvia dall'iPhone con Bluetooth acceso"

    @Published var lastNightscoutCheck: Date?

    @Published var lastNightscoutSuccess: Date?

    @Published var lastBLEEvent: Date?

    @Published var lastBLEEventKind = "Nessun evento BLE ricevuto"

    @Published var backgroundBLEWakeCount = 0

    @Published var eventLog: [String] = []



    struct Reading {

        let value: Int

        let timestampMS: Int64

        let direction: String

        var date: Date { Date(timeIntervalSince1970: TimeInterval(timestampMS) / 1000) }

        var ageSeconds: TimeInterval { Date().timeIntervalSince(date) }

        var fresh: Bool { ageSeconds >= -120 && ageSeconds <= 720 }

        var approx: WeatherCodec.Approximation? { WeatherCodec.approximate(value) }

    }

    private struct NightscoutEntry: Decodable {

        let sgv: Int?

        let date: Int64?

        let direction: String?

        let type: String?

    }



    private var central: CBCentralManager!

    private var activePeripheral: CBPeripheral?

    private var writeCharacteristic: CBCharacteristic?

    private var timer: Timer?

    private var inFlight = false

    private var requestGeneration = UUID()

    private var requestStarted: Date?

    private var requestCompletions: [(Bool) -> Void] = []

    private var discovering = false

    private var readyHandled = false

    private var subscriptions = Set<CBUUID>()

    private var reconnectAttempt = 0

    private var retryWork: DispatchWorkItem?

    private var requestTask: URLSessionDataTask?

    private var appInForeground = UIApplication.shared.applicationState == .active

    private var lastBackgroundRefresh: Date?

    private var lastBLETriggeredCheck: Date?

    private static let eventDateFormatter: DateFormatter = {

        let f = DateFormatter()

        f.dateFormat = "dd/MM HH:mm:ss"

        f.timeZone = TimeZone(identifier: "Europe/Rome")

        return f

    }()

    func recordEvent(_ event: String) {

        let line = "\(Self.eventDateFormatter.string(from: Date())) · \(event)"

        eventLog.insert(line, at: 0)

        if eventLog.count > 2000 { eventLog = Array(eventLog.prefix(2000)) }

        UserDefaults.standard.set(eventLog, forKey: "background-event-log")

    }

    var diagnosticExport: String {

        "Haylou CGM diagnostics; display never confirmed; age of last queued reading: \(lastQueuedReading > 0 ? String(Int(Date().timeIntervalSince1970 - Double(lastQueuedReading) / 1000)) : "unknown") seconds\n" + eventLog.reversed().joined(separator: "\n")

    }

    func cancelRefresh() {

        requestGeneration = UUID()

        requestTask?.cancel(); requestTask = nil; inFlight = false; requestStarted = nil

        let callbacks = requestCompletions; requestCompletions = []

        callbacks.forEach { $0(false) }

        recordEvent("BG task expired: network cancellation requested")

    }

    private func finishRefresh(_ success: Bool) {

        inFlight = false; requestStarted = nil; requestTask = nil

        let callbacks = requestCompletions; requestCompletions = []

        callbacks.forEach { $0(success) }

    }

    private func discoverOnce(_ peripheral: CBPeripheral) {

        guard peripheral.identifier == activePeripheral?.identifier,

              peripheral.state == .connected, !discovering, !readyHandled else { return }

        discovering = true

        peripheral.discoverServices([CBUUID(string: WeatherCodec.serviceUUID)])

    }

    private func resetGATT() {

        discovering = false; readyHandled = false; subscriptions.removeAll(); writeCharacteristic = nil

    }

    func startLiveActivity() {

        guard UIApplication.shared.applicationState == .active else { return }

        LiveSession.shared.start(log: recordEvent)

    }

    private func retryConnection() {

        guard automatic, central.state == .poweredOn, retryWork == nil else { return }

        let delay = SyncPolicy.retryDelay(reconnectAttempt)

        reconnectAttempt += 1

        recordEvent("BLE retry scheduled in \(Int(delay))s; execution subject to iOS suspension")

        let work = DispatchWorkItem { [weak self] in

            guard let self = self else { return }

            self.retryWork = nil

            self.restoreKnownDevice()

        }

        retryWork = work

        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)

    }

    var isConnected: Bool { activePeripheral?.state == .connected && writeCharacteristic != nil }



    private override init() {

        super.init()

        nightscoutURL = UserDefaults.standard.string(forKey: "nightscout-url") ?? nightscoutURL

        token = KeychainStore.load()

        automatic = UserDefaults.standard.bool(forKey: "automatic-enabled")

        lastNightscoutCheck = UserDefaults.standard.object(forKey: "last-nightscout-check") as? Date

        lastNightscoutSuccess = UserDefaults.standard.object(forKey: "last-nightscout-success") as? Date

        lastBLEEvent = UserDefaults.standard.object(forKey: "last-ble-event") as? Date

        backgroundBLEWakeCount = UserDefaults.standard.integer(forKey: "background-ble-wake-count")

        eventLog = UserDefaults.standard.stringArray(forKey: "background-event-log") ?? []

        lastQueuedReading = Int64(UserDefaults.standard.object(forKey: "last-queued-ms") as? Int ?? 0)

        if let t = UserDefaults.standard.object(forKey: "last-queued-at") as? Date { lastQueued = t }

        central = CBCentralManager(delegate: self, queue: .main,

                options: [CBCentralManagerOptionRestoreIdentifierKey: "haylou-cgm-corebluetooth"])

        restartTimerIfNeeded()

    }



    func saveSettings() {

        let normalized = nightscoutURL.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: normalized), url.scheme == "https",

              url.host != nil, url.user == nil, url.password == nil,

              url.query == nil, url.fragment == nil else {

            nightscoutStatus = "URL Nightscout non valido: serve HTTPS"

            return

        }

        nightscoutURL = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        UserDefaults.standard.set(nightscoutURL, forKey: "nightscout-url")

        guard KeychainStore.save(token.trimmingCharacters(in: .whitespacesAndNewlines)) else {

            nightscoutStatus = "Impossibile salvare il token nel portachiavi"

            return

        }

        nightscoutStatus = "Configurazione salvata sul dispositivo"

    }



    func setAutomatic(_ enabled: Bool) {

        automatic = enabled

        UserDefaults.standard.set(enabled, forKey: "automatic-enabled")

        restartTimerIfNeeded()

        if enabled {

            diagnostic = "Sessione abilitata; iOS può sospendere il polling a schermo bloccato"

            recordEvent("Invio automatico attivato")

            startLiveActivity()

            restoreKnownDevice()

            refreshNow(reason: "automatic enabled")

            AppDelegate.scheduleBackgroundRefresh()

        } else {

            LiveSession.shared.stop(log: recordEvent)

            retryWork?.cancel(); retryWork = nil

            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshID)

            diagnostic = "Invio automatico disattivato. Il watch potrebbe mostrare l'ultimo valore."

            recordEvent("Invio automatico disattivato")

        }

    }



    private func restartTimerIfNeeded() {

        timer?.invalidate()

        timer = nil

        guard automatic else { return }

        let newTimer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in

            guard let self = self, self.appInForeground || LiveSession.shared.isActive else { return }

            self.refreshNow(reason: self.appInForeground ? "foreground timer" : "Live Activity runtime opportunity (not guaranteed)")

        }

        RunLoop.main.add(newTimer, forMode: .common)

        timer = newTimer

    }



    func handleForeground(_ foreground: Bool) {

        appInForeground = foreground

        if foreground {

            diagnostic = "In primo piano: controllo immediato Nightscout"

            recordEvent("App in primo piano")

            if automatic { startLiveActivity(); restoreKnownDevice(); refreshNow(reason: "foreground") }

        } else {

            diagnostic = "In background: aggiornamenti solo se iOS concede esecuzione"

            recordEvent("App in background o schermo bloccato")

            AppDelegate.scheduleBackgroundRefresh()

        }

    }



    /// Chiamato anche da BGAppRefreshTask quando iOS decide di concederlo.

    func refreshNow(reason: String = "manuale/timer", completion: @escaping (Bool) -> Void = { _ in }) {

        if inFlight, Date().timeIntervalSince(requestStarted ?? .distantPast) > 30 {

            recordEvent("Nightscout abandoned request replaced after elapsed deadline")

            cancelRefresh()

        }

        guard !inFlight else {

            requestCompletions.append(completion)

            recordEvent("Nightscout trigger joined active request: \(reason)"); return

        }

        lastNightscoutCheck = Date()

        UserDefaults.standard.set(lastNightscoutCheck, forKey: "last-nightscout-check")

        recordEvent("Nightscout: controllo (\(reason))")

        guard let base = URL(string: nightscoutURL), base.scheme == "https", base.host != nil,

              base.user == nil, base.password == nil,

              base.query == nil, base.fragment == nil else {

            nightscoutStatus = "Indirizzo HTTPS non valido"

            completion(false); return

        }

        inFlight = true

        requestStarted = Date(); requestGeneration = UUID()

        let generation = requestGeneration

        requestCompletions.append(completion)

        var components = URLComponents(url: base.appendingPathComponent("api/v1/entries/sgv.json"), resolvingAgainstBaseURL: false)

        var items = [URLQueryItem(name: "count", value: "3")]

        if !token.isEmpty { items.append(URLQueryItem(name: "token", value: token)) }

        components?.queryItems = items

        guard let apiURL = components?.url else {

            finishRefresh(false); return

        }

        var request = URLRequest(url: apiURL, cachePolicy: .reloadIgnoringLocalCacheData,

                                 timeoutInterval: UIApplication.shared.applicationState == .active ? 25 : 8)

        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Non stampare mai request.url: contiene il token nell'eventuale query.

        requestTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in

            DispatchQueue.main.async {

                guard let self = self else { return }

                guard generation == self.requestGeneration else { return }

                if let error = error {

                    self.nightscoutStatus = "Connessione Nightscout fallita: \((error as NSError).code)"

                    self.recordEvent("Nightscout transport error code \((error as NSError).code); retry at next trigger")

                    self.finishRefresh(false); return

                }

                guard let http = response as? HTTPURLResponse, http.statusCode == 200, let data = data else {

                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0

                    self.nightscoutStatus = "Nightscout HTTP \(status)"

                    self.recordEvent("Nightscout HTTP \(status)")

                    self.finishRefresh(false); return

                }

                do {

                    let items = try JSONDecoder().decode([NightscoutEntry].self, from: data)

                    let readings = items.compactMap { entry -> Reading? in

                        guard let value = entry.sgv, let ms = entry.date, (20...600).contains(value),

                              entry.type != "mbg" else { return nil }

                        let unix = ms < 100_000_000_000 ? ms * 1000 : ms

                        return Reading(value: value, timestampMS: unix, direction: entry.direction ?? "—")

                    }.sorted { $0.timestampMS > $1.timestampMS }

                    guard let fresh = readings.first else {

                        self.nightscoutStatus = "Nessuna lettura CGM valida"

                        self.finishRefresh(false); return

                    }

                    self.recordEvent("CGM timestamp=\(fresh.timestampMS); age=\(Int(fresh.ageSeconds))s")

                    self.latest = fresh

                    LiveSession.shared.update(glucose: fresh.value, reading: fresh.date, write: self.lastQueued, status: fresh.fresh ? "Nightscout recente; display non confermato" : "Dato obsoleto: invio bloccato")

                    self.lastNightscoutSuccess = Date()

                    UserDefaults.standard.set(self.lastNightscoutSuccess, forKey: "last-nightscout-success")

                    self.recordEvent(fresh.fresh ? "Nightscout: risposta valida" : "Nightscout: risposta obsoleta, non inviata")

                    self.nightscoutStatus = fresh.fresh ? "Lettura ricevuta da Nightscout" : "Lettura vecchia: invio bloccato"

                    if self.automatic { self.sendIfNew(fresh) }

                    self.finishRefresh(true)

                } catch {

                    self.nightscoutStatus = "Risposta Nightscout non decodificabile"

                    self.finishRefresh(false)

                }

            }

        }

        requestTask?.resume()

    }



    func beginScan() {

        guard central.state == .poweredOn else { bluetoothStatus = "Accendi il Bluetooth"; return }

        scanResults = []

        bluetoothStatus = "Ricerca Haylou RT2..."

        // Nessun filtro service: l'RT2 pubblicizza FEE7, ma espone 001FF dopo connessione.

        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])

        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in

            guard let self = self, self.central.isScanning else { return }

            self.central.stopScan()

            self.bluetoothStatus = self.scanResults.isEmpty ? "RT2 non trovato; libera la connessione Haylou Fun" : "Seleziona Haylou RT2"

        }

    }

    func connect(_ peripheral: CBPeripheral) {

        central.stopScan()

        activePeripheral = peripheral

        peripheral.delegate = self

        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: "rt2-identifier")

        bluetoothStatus = "Connessione a \(peripheral.name ?? "RT2")..."

        guard peripheral.state != .connecting else { return }

        if peripheral.state == .connected {

            discoverOnce(peripheral); return

        }

        writeCharacteristic = nil

        recordEvent("BLE connection requested for authorized peripheral")

        central.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true])

    }

    private func restoreKnownDevice() {

        guard central.state == .poweredOn, let text = UserDefaults.standard.string(forKey: "rt2-identifier"),

              let uuid = UUID(uuidString: text), !isConnected else { return }

        let matches = central.retrievePeripherals(withIdentifiers: [uuid])

        guard let device = matches.first else { return }

        connect(device)

    }



    private func sendIfNew(_ reading: Reading) {

        guard reading.fresh else { diagnostic = "Dato vecchio: invio bloccato (il watch può mostrare un valore precedente)"; return }

        guard let approx = reading.approx else { diagnostic = "Fuori scala: invio bloccato (40–260 mg/dL)"; return }

        guard SyncPolicy.shouldSend(timestamp: reading.timestampMS, previous: lastQueuedReading, now: Date()) else { return }

        guard isConnected, let peripheral = activePeripheral, let characteristic = writeCharacteristic else {

            diagnostic = "RT2 non connesso; nuova lettura non trasmessa"

            recordEvent("BLE deferred: disconnected; latest reading retained")

            return

        }

        do {

            let bytes = try WeatherCodec.build(temperature: approx.celsius)

            let maxSize = peripheral.maximumWriteValueLength(for: .withoutResponse)

            guard bytes.count <= maxSize else {

                diagnostic = "MTU insufficiente: \(maxSize) byte disponibili, frame \(bytes.count); nessuna scrittura"

                return

            }

            guard peripheral.canSendWriteWithoutResponse else {

                diagnostic = "BLE occupato: non invio, riproverò alla lettura successiva"

                return

            }

            peripheral.writeValue(Data(bytes), for: characteristic, type: .withoutResponse)

            lastQueuedReading = reading.timestampMS

            lastQueued = Date()

            LiveSession.shared.update(glucose: reading.value, reading: reading.date, write: lastQueued, status: "Invio BLE richiesto; display non confermato")

            UserDefaults.standard.set(Int(reading.timestampMS), forKey: "last-queued-ms")

            UserDefaults.standard.set(lastQueued, forKey: "last-queued-at")

            diagnostic = "Scrittura BLE richiesta: \(reading.value) mg/dL → \(approx.shownFahrenheit) °F (±\(approx.difference)). Ricezione non confermata."

            recordEvent("BLE: API write requested; CGM timestamp=\(reading.timestampMS); age=\(Int(reading.ageSeconds))s; display NOT confirmed")

        } catch {

            diagnostic = "Errore encoder: \((error as NSError).code)"

        }

    }



    // MARK: Core Bluetooth

    func centralManagerDidUpdateState(_ central: CBCentralManager) {

        if central.state == .poweredOn {

            bluetoothStatus = "Bluetooth acceso"

            if automatic { restoreKnownDevice() }

        } else {

            resetGATT()

            bluetoothStatus = "Bluetooth non disponibile (stato \(central.state.rawValue))"

        }

    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {

        let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []

        recordEvent("Core Bluetooth: ripristino sessione (\(restored.count) periferiche)")

        if let device = restored.first(where: { $0.identifier.uuidString == UserDefaults.standard.string(forKey: "rt2-identifier") }) {

            activePeripheral = device

            device.delegate = self

            bluetoothStatus = "Connessione BLE recuperata dal sistema"

            if automatic, device.state == .disconnected { retryConnection() }

            if device.state == .connected {

                discoverOnce(device)

            }

        }

    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,

                        advertisementData: [String: Any], rssi RSSI: NSNumber) {

        let label = (peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "").lowercased()

        guard label.contains("haylou") || label.contains("ls10") || label.contains("rt2") else { return }

        if !scanResults.contains(where: { $0.identifier == peripheral.identifier }) {

            scanResults.append(peripheral)

        }

    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {

        retryWork?.cancel(); retryWork = nil

        resetGATT()

        activePeripheral = peripheral

        peripheral.delegate = self

        bluetoothStatus = "Connesso, identifico servizi..."

        recordEvent("Core Bluetooth: connessione stabilita")

        discoverOnce(peripheral)

    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {

        bluetoothStatus = "Connessione non riuscita"

        recordEvent("BLE connection failed; code=\((error as NSError?)?.code ?? 0)"); retryConnection()

    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,

                        error: Error?) {

        resetGATT()

        bluetoothStatus = "Disconnesso: \(error?.localizedDescription ?? "nessun errore")"

        diagnostic = "Nessun nuovo invio: il quadrante può mostrare una glicemia obsoleta"

        recordEvent("Core Bluetooth: periferica disconnessa")

        retryConnection()

    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {

        guard discovering, peripheral.identifier == activePeripheral?.identifier else { return }

        guard error == nil, let service = peripheral.services?.first(where: {

            $0.uuid == CBUUID(string: WeatherCodec.serviceUUID)

        }) else {

            bluetoothStatus = "Servizio 000001FF non trovato"

            recordEvent("GATT service discovery failed"); central.cancelPeripheralConnection(peripheral); retryConnection()

            return

        }

        peripheral.discoverCharacteristics([CBUUID(string: WeatherCodec.writeUUID),

                                            CBUUID(string: WeatherCodec.notifyUUID),

                                            CBUUID(string: WeatherCodec.indicateUUID)], for: service)

    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {

        guard discovering, !readyHandled, peripheral.identifier == activePeripheral?.identifier else { return }

        guard error == nil else { bluetoothStatus = "Errore GATT"; central.cancelPeripheralConnection(peripheral); retryConnection(); return }

        for ch in service.characteristics ?? [] {

            if ch.uuid == CBUUID(string: WeatherCodec.writeUUID) { writeCharacteristic = ch }

            if ch.uuid == CBUUID(string: WeatherCodec.notifyUUID) || ch.uuid == CBUUID(string: WeatherCodec.indicateUUID) {

                if (ch.properties.contains(.notify) || ch.properties.contains(.indicate)), !ch.isNotifying, subscriptions.insert(ch.uuid).inserted { peripheral.setNotifyValue(true, for: ch) }

            }

        }

        if writeCharacteristic != nil {

            readyHandled = true; discovering = false

            reconnectAttempt = 0

            bluetoothStatus = "Haylou RT2 pronto"

            recordEvent("Core Bluetooth: caratteristica meteo pronta")

            if automatic {

                if let pending = latest { sendIfNew(pending) }

                refreshNow(reason: "connessione BLE")

            }

        } else { bluetoothStatus = "Caratteristica 000002FF mancante"; central.cancelPeripheralConnection(peripheral); retryConnection() }

    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,

                    error: Error?) {

        let ok = error == nil && characteristic.isNotifying

        recordEvent("BLE: \(characteristic.uuid.uuidString) notifiche \(ok ? "attive" : "non attive")")

    }



    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        guard error == nil, let data = characteristic.value else {

            recordEvent("BLE: evento non leggibile")

            return

        }

        lastReply = data.prefix(32).map { String(format: "%02x", $0) }.joined(separator: " ")

        lastBLEEvent = Date()

        lastBLEEventKind = characteristic.uuid.uuidString

        UserDefaults.standard.set(lastBLEEvent, forKey: "last-ble-event")

        recordEvent("BLE callback in \(UIApplication.shared.applicationState == .active ? "foreground" : "background/inactive"); not a proven suspension wake")

        recordEvent("BLE: notifica da \(characteristic.uuid.uuidString), \(data.count) byte")



        // Soltanto notifiche spontanee dal watch possono risvegliare un central sospeso.

        // Senza eventi l'iPhone non garantisce polling periodico; non forzare timer falsi.

        guard automatic, isConnected, !inFlight else { return }

        let now = Date()

        guard now.timeIntervalSince(lastBLETriggeredCheck ?? .distantPast) >= 60,

              now.timeIntervalSince(lastNightscoutCheck ?? .distantPast) >= 55 else { return }

        lastBLETriggeredCheck = now

        if UIApplication.shared.applicationState != .active { backgroundBLEWakeCount += 1 }

        UserDefaults.standard.set(backgroundBLEWakeCount, forKey: "background-ble-wake-count")

        recordEvent("Risveglio BLE in background: controllo Nightscout")

        refreshNow(reason: "notifica BLE (foreground/background state in preceding event)")

    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {

        if automatic, let pending = latest { sendIfNew(pending) }

    }

}

