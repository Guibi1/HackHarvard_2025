//
//  ContentView.swift
//  HackHarvard
//
//  Created by Laurent Stéphenne on 2025-10-03.
//

import SwiftUI
import CoreBluetooth
enum BluetoothRole {
    case central
    case peripheral
}

struct ContentView: View {
    @State private var role: BluetoothRole? = nil
    @StateObject private var bluetoothVM = BluetoothManager()
    @State private var peripheralManager: PeripheralManager? = nil
    
    var body: some View {
        VStack {
            HStack {
                Button("Act as Central") {
                    role = .central
                    peripheralManager = nil
                }
                Button("Act as Peripheral") {
                    role = .peripheral
                    peripheralManager = PeripheralManager()
                }
            }
            
            if role == .central {
                VStack {
                    Button("Scan for 30s") {
                        bluetoothVM.scanForDevices()
                    }
                    Button("Stop Now") {
                        bluetoothVM.stopScan()
                    }
                    
                    List(bluetoothVM.devices, id: \.identifier) { device in
                        VStack(alignment: .leading) {
                            Text("Name: \(device.name)")
                            Text("UUID: \(device.identifier.uuidString)")
                            Text("RSSI: \(device.rssi)")
                            
                            if device.connectable {
                                if bluetoothVM.connectedPeripheral?.identifier == device.identifier {
                                    HStack {
                                        Button("Disconnect") {
                                            bluetoothVM.disconnect()
                                        }
                                        .foregroundColor(.red)
                                        Button("Write!") {
                                            let data = "hello".data(using: .utf8)!
                                            bluetoothVM.write(to: CBUUID(string: "5678"), value: data)
                                        }
                                    }
                                } else {
                                    Button("Connect") {
                                        bluetoothVM.connect(device: device)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            if role == .peripheral {
                Text("📡 Advertising as Peripheral…")
            }
        }
    }
}
