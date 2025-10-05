import CoreBluetooth
import CryptoKit
import Foundation

class BluetoothServerManager: NSObject, CBPeripheralManagerDelegate {
    var sessionID: String
    var encryptionKey: SymmetricKey

    private var peripheralManager: CBPeripheralManager!

    // Your UUIDs
    private static let serviceUUID = CBUUID(
        string: "08590F7E-DB05-467E-8757-72F6FAEB13D4"
    )
    private static let characteristicUUID = CBUUID(
        string: "08590F7E-DB05-467E-8757-72F6FAEB13D5"
    )  // different last digit

    private static let transferCharacteristic = CBMutableCharacteristic(
        type: characteristicUUID,
        properties: [.write, .notify],
        value: nil,
        permissions: [.writeEncryptionRequired]
    )

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
        let service = CBMutableService(
            type: BluetoothServerManager.serviceUUID,
            primary: true
        )
        service.characteristics = [
            BluetoothServerManager.transferCharacteristic
        ]

        peripheralManager.add(service)
        peripheralManager.startAdvertising([
            CBAdvertisementDataLocalNameKey: "TempLock sharing",
            CBAdvertisementDataServiceUUIDsKey: [
                BluetoothServerManager.serviceUUID
            ],
        ])
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveWrite requests: [CBATTRequest]
    ) {
        for request in requests {
            guard let value = request.value else { continue }
            let received = String(data: value, encoding: .utf8)
            if received == sessionID {
                peripheral.respond(to: request, withResult: .success)

                let keyData = encryptionKey.withUnsafeBytes { Data($0) }
                peripheral.updateValue(
                    keyData,
                    for: BluetoothServerManager.transferCharacteristic,
                    onSubscribedCentrals: [request.central]
                )
            } else {
                peripheral.respond(
                    to: request,
                    withResult: .insufficientAuthentication
                )
                peripheral.updateValue(
                    Data(),
                    for: BluetoothServerManager.transferCharacteristic,
                    onSubscribedCentrals: [request.central]
                )
            }
        }
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
