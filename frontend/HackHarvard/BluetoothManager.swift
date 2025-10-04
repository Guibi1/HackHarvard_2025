//
//  BluetoothManager.swift
//  test
//
//  Created by Emil Rose Levy on 2025-10-03.
//

import CoreBluetooth
import Combine

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

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager?
    @Published var devices: [DiscoveredDevice] = []
    @Published var isScanning: Bool = false
    @Published var connectedPeripheral: CBPeripheral?
    
    private var shouldAutoReconnect: Bool = true
    private var characteristics: [CBUUID: CBCharacteristic] = [:] // Cache for later read/write

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("✅ Bluetooth is On")
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

        devices.removeAll()
        isScanning = true

        // You can temporarily use nil to see all peripherals
        central.scanForPeripherals(withServices: [CBUUID(string: "08590F7E-DB05-467E-8757-72F6FAEB13D4")],
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        print("🔍 Started scanning...")

        // Stop after 30s
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.stopScan()
        }
    }

    func stopScan() {
        centralManager?.stopScan()
        isScanning = false
        print("🛑 Stopped scanning.")
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {

        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let deviceName = advertisedName ?? peripheral.name ?? "Unknown"
        let connectable = (advertisementData[CBAdvertisementDataIsConnectable] as? Bool) ?? false

        let device = DiscoveredDevice(
            name: deviceName,
            peripheral: peripheral,
            identifier: peripheral.identifier,
            rssi: RSSI,
            advertisementData: advertisementData,
            connectable: connectable
        )

        // Update or insert the device
        if let index = devices.firstIndex(where: { $0.identifier == peripheral.identifier }) {
            devices[index] = device
        } else {
            devices.append(device)
        }

        print("📡 Device: \(deviceName)")
        print("   UUID: \(peripheral.identifier)")
        print("   RSSI: \(RSSI) dBm")
        print("-----------------------------")
    }

    // MARK: - Connection & Callbacks
    func connect(device: DiscoveredDevice) {
        connectedPeripheral = device.peripheral
        connectedPeripheral?.delegate = self
        shouldAutoReconnect = true
        centralManager?.connect(device.peripheral, options: nil)
        print("🔗 Connecting to \(device.name)...")
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to \(peripheral.name ?? "Unknown")")
        characteristics.removeAll()
        peripheral.discoverServices(nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
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

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error = error {
            print("❌ Error discovering characteristics: \(error.localizedDescription)")
            return
        }

        guard let chars = service.characteristics else { return }
        for characteristic in chars {
            print("🔑 Characteristic: \(characteristic.uuid), properties: \(characteristic.properties)")
            
            // Cache for later use
            characteristics[characteristic.uuid] = characteristic

            // Try reading only if explicitly readable
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            print("❌ Error updating value for \(characteristic.uuid): \(error.localizedDescription)")
            return
        }

        guard let value = characteristic.value else {
            print("⚠️ No value for \(characteristic.uuid)")
            return
        }

        let hexString = value.map { String(format: "%02hhx", $0) }.joined(separator: " ")
        print("📥 Value for \(characteristic.uuid): \(hexString)")

        // Example: Battery Level (standard characteristic)
        if characteristic.uuid == CBUUID(string: "2A19"), let battery = value.first {
            print("🔋 Battery Level: \(battery)%")
        }
    }

    // MARK: - Disconnect / Reconnect
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        print("⚠️ Disconnected from \(peripheral.name ?? "Unknown")")

        if shouldAutoReconnect, connectedPeripheral?.identifier == peripheral.identifier {
            print("🔄 Attempting to reconnect...")
            central.connect(peripheral, options: nil)
        } else {
            connectedPeripheral = nil
        }
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            shouldAutoReconnect = false
            centralManager?.cancelPeripheralConnection(peripheral)
            print("🔌 Disconnecting from \(peripheral.name ?? "Unknown")...")
        }
    }

    // MARK: - Writing
    func write(to characteristicUUID: CBUUID,
               value: Data,
               type: CBCharacteristicWriteType = .withResponse) {
        guard let peripheral = connectedPeripheral, peripheral.state == .connected else {
            print("⚠️ Cannot write: peripheral not connected")
            return
        }

        guard let characteristic = characteristics[characteristicUUID] else {
            print("⚠️ Characteristic \(characteristicUUID) not found yet")
            return
        }

        peripheral.writeValue(value, for: characteristic, type: type)
        print("✍️ Wrote \(value.count) bytes to \(characteristicUUID)")
    }

    // MARK: - Helpers
    func isDeviceConnected(_ device: DiscoveredDevice) -> Bool {
        return connectedPeripheral?.identifier == device.identifier
    }
}
