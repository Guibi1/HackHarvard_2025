import SwiftUI

struct ScanningForServerView: View {
    @ObservedObject var bluetoothManager: BluetoothClientManager
    @Environment(ModelData.self) var modelData

    @Namespace private var namespace
    @State private var sessionID: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var isExpanded: Bool = false

    var body: some View {

        ScrollView {
            VStack(spacing: 48) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue.gradient)
                    .symbolEffect(.pulse, options: .repeating, value: true)
                    .shadow(radius: 4)
                    .padding(.vertical, 32)

                VStack(spacing: 4) {
                    Text("Welcome to TempLock")
                        .font(.title2)
                        .bold()
                    Text(
                        "Please wait while your device connects to the network."
                    )
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                }

                // Input bar like iMessage
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 8) {
                        HStack {
                            TextField(
                                "Room code",
                                text: $sessionID
                            )
                            .onChange(of: sessionID) { _, new in
                                sessionID = new.filter { $0.isLetter }
                                if isExpanded != (new.count != 0) {
                                    withAnimation {
                                        isExpanded = new.count != 0
                                    }
                                }
                            }
                            .focused($isTextFieldFocused)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.alphabet)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                        }
                        .glassEffect(.regular.interactive())
                        .glassEffectID("input", in: namespace)

                        if isExpanded {
                            Button(action: {
                                bluetoothManager.startKeyExchange(
                                    sessionID: sessionID
                                )
                                isTextFieldFocused = false
                            }) {
                                Image(systemName: "arrow.turn.down.right")
                            }
                            .disabled(bluetoothManager.isScanning)
                            .frame(width: 48, height: 48)
                            .font(.system(size: 24))
                            .backgroundStyle(.blue.gradient)
                            .glassEffect(.regular.interactive())
                            .glassEffectID("submit", in: namespace)
                        }
                    }
                }

                if bluetoothManager.isScanning {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(.circular)
                        Text("Connecting to host").font(.footnote)
                    }
                }

                Button("I want to share my files") {
                    bluetoothManager.stopScan()
                    bluetoothManager.disconnect()
                    modelData.switchToBluetoothServer()
                }
            }
            .padding(40)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

#Preview {
    ScanningForServerView(bluetoothManager: BluetoothClientManager())
        .environment(ModelData())
}
