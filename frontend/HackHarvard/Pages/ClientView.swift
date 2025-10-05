import SwiftUI

struct ClientView: View {
    @ObservedObject var bluetoothManager: BluetoothClientManager

    var body: some View {
        if bluetoothManager.connectedPeripheral == nil {
            ScanningForServerView(bluetoothManager: bluetoothManager)
        } else {
            FilesView(bluetoothManager: bluetoothManager)
        }
    }
}
