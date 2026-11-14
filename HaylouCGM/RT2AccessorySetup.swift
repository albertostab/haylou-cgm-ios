import Foundation
import AccessorySetupKit
import CoreBluetooth
import UIKit

/// Optional system authorization. It does not enable periodic network execution.
@available(iOS 18.0, *)
final class RT2AccessorySetup {
    private let session = ASAccessorySession()
    private let log: (String) -> Void
    private let selected: (UUID) -> Void
    private var activated = false
    private var wantsPicker = false
    private var pickerVisible = false
    private var pickedID: UUID?

    init(log: @escaping (String) -> Void, selected: @escaping (UUID) -> Void) {
        self.log = log
        self.selected = selected
        session.activate(on: .main) { [weak self] event in
            guard let self = self else { return }
            if let error = event.error {
                self.log("AccessorySetupKit error code=\((error as NSError).code)")
            }
            switch event.eventType {
            case .activated:
                self.activated = true
                self.log("AccessorySetupKit active; authorized accessories=\(self.session.accessories.count)")
                if let saved = UserDefaults.standard.string(forKey: "rt2-identifier"),
                   let id = self.session.accessories.compactMap(\.bluetoothIdentifier).first(where: { $0.uuidString == saved }) {
                    self.selected(id)
                }
                if self.wantsPicker { self.showPicker() }
            case .migrationComplete:
                self.pickedID = event.accessory?.bluetoothIdentifier ?? UserDefaults.standard.string(forKey: "rt2-identifier").flatMap(UUID.init(uuidString:))
            case .accessoryAdded:
                self.pickedID = event.accessory?.bluetoothIdentifier
            case .pickerDidDismiss:
                self.pickerVisible = false
                if let id = self.pickedID {
                    self.pickedID = nil
                    self.selected(id)
                }
            case .invalidated:
                self.activated = false; self.wantsPicker = false; self.pickerVisible = false
                self.log("AccessorySetupKit session invalidated; reopen app before retrying authorization")
            default:
                break
            }
        }
    }

    func showPicker() {
        guard UIApplication.shared.applicationState == .active else { return }
        wantsPicker = true
        guard activated, !pickerVisible else { return }
        wantsPicker = false
        let names = ["Haylou", "HAYLOU", "haylou", "LS10", "RT2"]
        let services = ["FEE7", WeatherCodec.serviceUUID]
        guard let image = UIImage(systemName: "applewatch") else { return }
        var items: [ASPickerDisplayItem] = services.flatMap { service in
            names.map { name -> ASPickerDisplayItem in
                let descriptor = ASDiscoveryDescriptor()
                descriptor.bluetoothServiceUUID = CBUUID(string: service)
                descriptor.bluetoothNameSubstring = name
                return ASPickerDisplayItem(name: "Haylou RT2", productImage: image, descriptor: descriptor)
            }
        }
        if let saved = UserDefaults.standard.string(forKey: "rt2-identifier"), let id = UUID(uuidString: saved) {
            let descriptor = ASDiscoveryDescriptor()
            descriptor.bluetoothServiceUUID = CBUUID(string: "FEE7")
            descriptor.bluetoothNameSubstring = "Haylou"
            let migration = ASMigrationDisplayItem(name: "Haylou RT2", productImage: image, descriptor: descriptor)
            migration.peripheralIdentifier = id
            items = [migration]
        }
        pickerVisible = true
        session.showPicker(for: items) { [weak self] error in
            if let error = error {
                self?.pickerVisible = false
                self?.log("AccessorySetupKit picker failed code=\((error as NSError).code); use standard IPA if authorization cannot complete")
            }
        }
    }
}
