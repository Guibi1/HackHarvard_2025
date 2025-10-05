import SwiftUI

struct ScanningForServerView: View {
    @ObservedObject var bluetoothManager: BluetoothClientManager
    @Environment(ModelData.self) var modelData

    var body: some View {
        VStack(spacing: 48) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
                .symbolEffect(.pulse, options: .repeating, value: true)
                .shadow(radius: 4)
                .padding(.bottom, 32)

            VStack {
                Text("Connecting to nodes")
                    .font(.title2)
                    .bold()
                Text("Please wait while your device connects to the network.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            if bluetoothManager.isScanning {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(.circular)
            } else {
                Button("Scan again") {
                    bluetoothManager.scanForDevices()
                }.buttonStyle(.glassProminent).controlSize(.large)
            }

            Button("Host files instead") {
                bluetoothManager.stopScan()
                bluetoothManager.disconnect()
                modelData.switchToServer()

            }
        }
        .padding(40)
        .onAppear {
            bluetoothManager.scanForDevices()
        }
    }
}

#Preview {
    ScanningForServerView(bluetoothManager: BluetoothClientManager())
        .environment(ModelData())
}
