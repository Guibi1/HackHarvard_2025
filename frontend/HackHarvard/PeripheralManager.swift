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
            properties: [.read, .write],
            value: nil,
            permissions: [.readable, .writeable]
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
    
    var receivedDataBuffer = Data()

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            guard let value = request.value else { continue }
            receivedDataBuffer.append(value)
            peripheral.respond(to: request, withResult: .success)
        }

        // Detect when full message received
        if receivedDataBuffer.count >= 48 {
            processReceivedEncryptionData()
            receivedDataBuffer.removeAll()
        }
    }

    func processReceivedEncryptionData() {
        let keyLength = 32
        let ivLength = 16
        
        guard receivedDataBuffer.count >= keyLength + ivLength else {
            print("❌ Incomplete data received")
            return
        }

        let key = receivedDataBuffer.subdata(in: 0..<keyLength)
        let iv = receivedDataBuffer.subdata(in: keyLength..<(keyLength + ivLength))
        
        print("✅ Received key: \(key as NSData)")
        print("✅ Received IV: \(iv as NSData)")
        
        KeychainManager.shared.saveEncryptionKey(key, iv: iv)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        let responseString = "Hello from Mac!"
        if let data = responseString.data(using: .utf8) {
            request.value = data
            peripheral.respond(to: request, withResult: .success)
            print("📤 Sent read response: \(responseString)")
        } else {
            peripheral.respond(to: request, withResult: .unlikelyError)
        }
    }
}
