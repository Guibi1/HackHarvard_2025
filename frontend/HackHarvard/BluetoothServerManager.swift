import CoreBluetooth
import Foundation
import CryptoKit

class BluetoothServerManager: NSObject, CBPeripheralManagerDelegate {
    var sessionID: String
    var encryptionKey: SymmetricKey

    private var peripheralManager: CBPeripheralManager!
    private var transferCharacteristic: CBMutableCharacteristic!

    // Your UUIDs
    private let serviceUUID = CBUUID(
        string: "08590F7E-DB05-467E-8757-72F6FAEB13D4"
    )
    private let characteristicUUID = CBUUID(
        string: "08590F7E-DB05-467E-8757-72F6FAEB13D5"
    )  // different last digit

    init(sessionID: String, encryptionKey: SymmetricKey) {
        self.sessionID = sessionID
        self.encryptionKey = encryptionKey
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
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
        ])
        print("📣 Advertising service \(serviceUUID.uuidString)")
    }

    var receivedDataBuffer = Data()

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveWrite requests: [CBATTRequest]
    ) {
        for request in requests {
            guard let value = request.value else { continue }
            receivedDataBuffer.append(value)
            peripheral.respond(to: request, withResult: .success)
        }

        processReceivedEncryptionData()
    }

    func processReceivedEncryptionData() {
        let keyLength = 32
        let sessionIdLength = 5

        guard receivedDataBuffer.count >= sessionIdLength + keyLength else {
            return
        }

        let decryptionKey = receivedDataBuffer.subdata(in: 0..<sessionIdLength)
        let sessionID = receivedDataBuffer.subdata(
            in: sessionIdLength..<(sessionIdLength + keyLength)
        )

        print("✅ Received key: \(decryptionKey as NSData)")
        print("✅ Received session: \(sessionID as NSData)")

        receivedDataBuffer.removeSubrange(0...keyLength + sessionIdLength)
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveRead request: CBATTRequest
    ) {
        let key = encryptionKey.withUnsafeBytes { Data($0) }
        request.value = key + sessionID.data(using: .utf8)!
        peripheral.respond(to: request, withResult: .success)
        print("📤 Sent read response with session and key: \(encryptionKey) + \(String(describing: sessionID.data(using: .utf8)))")
    }
}

extension Data {
    func chunked(into size: Int) -> [Data] {
        var chunks: [Data] = []
        var index = 0
        while index < count {
            let length = Swift.min(size, count - index)
            let chunk = self.subdata(in: index..<index + length)
            chunks.append(chunk)
            index += length
        }
        return chunks
    }
}
