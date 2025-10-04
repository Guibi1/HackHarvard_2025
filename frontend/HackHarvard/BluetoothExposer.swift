import Foundation
import CoreBluetooth

class PeripheralManager: NSObject, CBPeripheralManagerDelegate {
    private var peripheralManager: CBPeripheralManager!
    private var transferCharacteristic: CBMutableCharacteristic!
    
    // Your UUIDs
    private let serviceUUID = CBUUID(string: "08590F7E-DB05-467E-8757-72F6FAEB13D4")
    private let characteristicUUID = CBUUID(string: "08590F7E-DB05-467E-8757-72F6FAEB13D5") // different last digit
    
    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else {
            print("⚠️ Bluetooth not ready (\(peripheral.state.rawValue))")
            return
        }
        print("✅ Peripheral powered on")
        setupService()
    }
    
    private func setupService() {
        transferCharacteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.write, .read],
            value: nil,
            permissions: [.writeable, .readable]
        )
        
        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [transferCharacteristic]
        
        peripheralManager.add(service)
        peripheralManager.startAdvertising([
            CBAdvertisementDataLocalNameKey: "iPhonePeripheral",
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID]
        ])
        print("📣 Advertising service \(serviceUUID.uuidString)")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if let value = request.value, let msg = String(data: value, encoding: .utf8) {
                print("📥 Received message: \(msg)")
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }
}
