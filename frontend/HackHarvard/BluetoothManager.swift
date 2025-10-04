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

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager?
    @Published var devices: [DiscoveredDevice] = []
    @Published var isScanning: Bool = false
    @Published var connectedPeripheral: CBPeripheral?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is On")
        case .poweredOff:
            print("Bluetooth is Off")
        case .unauthorized:
            print("Bluetooth unauthorized")
        case .unsupported:
            print("Bluetooth unsupported")
        case .resetting:
            print("Bluetooth resetting")
        case .unknown:
            print("Bluetooth unknown")
        @unknown default:
            print("Unknown state")
        }
    }

    func scanForDevices() {
        guard let central = centralManager, central.state == .poweredOn else {
            print("Bluetooth not ready")
            return
        }
        devices.removeAll()
        central.scanForPeripherals(withServices: nil, options: nil)
        print("Started scanning...")

        // Stop after 10s
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.stopScan()
        }
    }

    func stopScan() {
        centralManager?.stopScan()
        print("Stopped scanning.")
    }


    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        
        guard let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data else {
            return // Ignore if no manufacturer data
        }
        
        let bytes = [UInt8](manufacturerData)
        guard bytes.count >= 6 else { return }
        
        // Match manufacturer prefix
        /*guard (bytes[2] == 0xDE && bytes[3] == 0xAD &&
               bytes[4] == 0xCA && bytes[5] == 0xCA) else {
            return
        }*/
        
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let deviceName = advertisedName ?? peripheral.name ?? "Unknown"
        let connectable = (advertisementData[CBAdvertisementDataIsConnectable] as? Bool) ?? false
        
        // Check if already discovered
        if let index = devices.firstIndex(where: { $0.identifier == peripheral.identifier }) {
            // Update existing device if name changed
            if devices[index].name != deviceName {
                devices[index] = DiscoveredDevice(
                    name: deviceName,
                    peripheral: peripheral,
                    identifier: peripheral.identifier,
                    rssi: RSSI,
                    advertisementData: advertisementData,
                    connectable: connectable
                )
                print("♻️ Updated device name → \(deviceName)")
            }
        } else {
            // New device
            let device = DiscoveredDevice(
                name: deviceName,
                peripheral: peripheral,
                identifier: peripheral.identifier,
                rssi: RSSI,
                advertisementData: advertisementData,
                connectable: connectable
            )
            devices.append(device)
            
            print("📡 MATCHED device: \(deviceName)")
            print("   UUID: \(peripheral.identifier)")
            print("   RSSI: \(RSSI) dBm")
            let hexString = manufacturerData.map { String(format: "%02hhx", $0) }.joined(separator: " ")
            print("   Manufacturer Data: \(hexString)")
            print("-----------------------------")
        }
    }
    
    // connect to device
    func connect(device: DiscoveredDevice) {
        connectedPeripheral = device.peripheral
        centralManager?.connect(device.peripheral, options: nil)
        print("🔗 Connecting to \(device.name)...")
    }
    
    // Callback for didConnect
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to \(peripheral.name ?? "Unknown")")
        peripheral.discoverServices(nil)
    }
    
    // Callback for didDiscoverServices
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        for service in services {
            print("📡 Service found: \(service.uuid)")
            // Discover characteristics of each service
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    // Callback didDiscoverCharacteristicsFor
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            print("🔑 Characteristic: \(characteristic.uuid), properties: \(characteristic.properties)")
            
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
            
        }
    }
        
}
