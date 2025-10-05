import Combine
import CoreBluetooth
import CryptoKit
import SwiftUI

// A model to hold discovered device info
struct DiscoveredDevice: Identifiable {
    let id = UUID()
    let name: String
    let peripheral: CBPeripheral
    let identifier: UUID
    let rssi: NSNumber
    let advertisementData: [String: Any]
    let connectable: Bool
}

class BluetoothClientManager: NSObject, ObservableObject,
    CBCentralManagerDelegate, CBPeripheralDelegate
{
    private var centralManager: CBCentralManager?
    @Published var device: DiscoveredDevice? = nil
    @Published var isScanning: Bool = false
    @Published var connectedPeripheral: CBPeripheral?
    @Published var sessionID: String?
    @Published var decryptionKey: SymmetricKey?
    var onConnection: (() -> Void)?

    private var shouldAutoReconnect: Bool = true
    private var authCharacteristic: CBCharacteristic? = nil

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("✅ Bluetooth is On")
            scanForDevices()
        case .poweredOff:
            print("⚠️ Bluetooth is Off")
        case .unauthorized:
            print("🚫 Bluetooth unauthorized")
        case .unsupported:
            print("❌ Bluetooth unsupported")
        case .resetting:
            print("♻️ Bluetooth resetting")
        case .unknown:
            print("❓ Bluetooth unknown")
        @unknown default:
            print("❓ Unknown Bluetooth state")
        }
    }

    // MARK: - Scanning
    func scanForDevices() {
        guard let central = centralManager, central.state == .poweredOn else {
            print("⚠️ Bluetooth not ready")
            return
        }

        device = nil
        isScanning = true

        // You can temporarily use nil to see all peripherals
        central.scanForPeripherals(
            withServices: [
                CBUUID(string: "08590F7E-DB05-467E-8757-72F6FAEB13D4")
            ],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        print("🔍 Started scanning...")

        // Stop after 30s
//        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
//            self?.stopScan()
//        }
    }

    func stopScan() {
        centralManager?.stopScan()
        isScanning = false
        print("🛑 Stopped scanning.")
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {

        let advertisedName =
            advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let deviceName = advertisedName ?? peripheral.name ?? "Unknown"
        let connectable =
            (advertisementData[CBAdvertisementDataIsConnectable] as? Bool)
            ?? false

        let device = DiscoveredDevice(
            name: deviceName,
            peripheral: peripheral,
            identifier: peripheral.identifier,
            rssi: RSSI,
            advertisementData: advertisementData,
            connectable: connectable
        )

        stopScan()
        connect(device: device)

        print("📡 Device: \(deviceName)")
        print("   UUID: \(peripheral.identifier)")
        print("   RSSI: \(RSSI) dBm")
        print("-----------------------------")
    }

    // MARK: - Connection & Callbacks
    func connect(device: DiscoveredDevice) {
        self.device = device
        connectedPeripheral = device.peripheral
        connectedPeripheral?.delegate = self
        shouldAutoReconnect = true
        centralManager?.connect(device.peripheral, options: nil)
        print("🔗 Connecting to \(device.name)...")
    }

    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        print("✅ Connected to \(peripheral.name ?? "Unknown")")
        authCharacteristic = nil
        peripheral.discoverServices(nil)
        stopScan()
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        if let error = error {
            print("❌ Error discovering services: \(error.localizedDescription)")
            return
        }

        guard let services = peripheral.services else { return }
        for service in services {
            print("📡 Service found: \(service.uuid)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard let chars = service.characteristics else { return }

        for characteristic in chars {
            print("Caracteristic found: \(characteristic.uuid)")

            if characteristic.uuid
                == CBUUID(string: "08590F7E-DB05-467E-8757-72F6FAEB13D5")
            {
                authCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                print("Ready to exchange key!")
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil else { return }
        guard let value = characteristic.value else { return }

        if characteristic.uuid
            == CBUUID(string: "08590F7E-DB05-467E-8757-72F6FAEB13D5")
        {
            let keyLength = 32
            guard value.count >= keyLength else {
                if value.count == 0 {
                    sessionID = nil
                }
                return
            }

            let decryptionKeyData = value.subdata(in: 0..<keyLength)
            decryptionKey = SymmetricKey(data: decryptionKeyData)
            self.onConnection?()
        }
    }

    // MARK: - Disconnect / Reconnect
    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        print("⚠️ Disconnected from \(peripheral.name ?? "Unknown")")

        if shouldAutoReconnect,
            connectedPeripheral?.identifier == peripheral.identifier
        {
            print("🔄 Attempting to reconnect...")
            central.connect(peripheral, options: nil)
        } else {
            connectedPeripheral = nil
            authCharacteristic = nil
            sessionID = nil
        }
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            shouldAutoReconnect = false
            authCharacteristic = nil
            sessionID = nil
            decryptionKey = nil
            device = nil
            centralManager?.cancelPeripheralConnection(peripheral)
            print("🔌 Disconnecting from \(peripheral.name ?? "Unknown")...")
        }
    }

    // MARK: - Helpers
    func isDeviceConnected(_ device: DiscoveredDevice) -> Bool {
        return connectedPeripheral?.identifier == device.identifier
    }

    func startKeyExchange(sessionID: String) {
        if let peripheral = connectedPeripheral,
            let authStartCharacteristic = authCharacteristic
        {
            peripheral.writeValue(
                sessionID.data(using: .utf8)!,
                for: authStartCharacteristic,
                type: .withResponse,
            )

            print("✍️ Wrote sessionID")
            self.sessionID = sessionID
        }
    }
}
