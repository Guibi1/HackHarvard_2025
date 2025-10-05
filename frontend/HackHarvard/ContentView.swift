//
//  ContentView.swift
//  HackHarvard
//
//  Created by Laurent Stéphenne on 2025-10-03.
//

import SwiftUI
import CoreBluetooth



struct ContentView: View {
//    @State private var role: BluetoothManager? = nil
//    @StateObject private var bluetoothVM = BluetoothClientManager()
//    @State private var showingInputDialog = false
//    @State private var inputText: String = ""
//    @State private var peripheralManager: BluetoothServerManager? = nil

    
    var body: some View {
        VStack {
            HStack {
                Button("I want to share") {
//                    role = .server(bluetoothManager: BluetoothServerManager())
                }
                Button("I want to receive"){
//                    role = .client(bluetoothManager: BluetoothClientManager())
                }
            }
            
//            if role == .server {
//                VStack {
//                    Button("Scan for 30s") {
//                        bluetoothVM.scanForDevices()
//                    }
//                    Button("Stop Now") {
//                        bluetoothVM.stopScan()
//                    }
//                    
//                    List(bluetoothVM.devices, id: \.identifier) { device in
//                        VStack(alignment: .leading) {
//                            Text("Name: \(device.name)")
//                            Text("UUID: \(device.identifier.uuidString)")
//                            Text("RSSI: \(device.rssi)")
//                            
//                            if device.connectable {
//                                if bluetoothVM.connectedPeripheral?.identifier == device.identifier {
//                                    HStack {
//                                        if !showingInputDialog {
//                                            Button("Write to him!") {
//                                                showingInputDialog.toggle()
//                                            }
//                                        } else {
//                                            Button("Are you sure!") {
//                                                if let (key, iv) = KeychainManager.shared.loadEncryptionKeyAndIV() {
//                                                    // Combine and split into 20-byte BLE chunks
//                                                    let chunks = KeychainManager.shared.sendEncryptionDataOverBluetooth(key: key, iv: iv)
//                                                    
//                                                    // Send each chunk via BLE
//                                                    for chunk in chunks {
//                                                        bluetoothVM.write(
//                                                            to: CBUUID(string: "08590F7E-DB05-467E-8757-72F6FAEB13D5"),
//                                                            value: chunk
//                                                        )
//                                                    }
//                                                    bluetoothVM.write(to: CBUUID(string: "08590F7E-DB05-467E-8757-72F6FAEB13D5"), value: "EOF".data(using: .utf8)!)
//                                                }
//                                            }
//                                            .foregroundColor(.red)
//                                        }
//                                    }
//                                } else {
//                                    Button("Connect") {
//                                        bluetoothVM.connect(device: device)
//                                    }
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//            
//            if role == .peripheral {
//                Text("📡 Advertising as Peripheral…")
//            }
        }
    }
}
