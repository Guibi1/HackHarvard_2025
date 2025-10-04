//
//  ContentView.swift
//  HackHarvard
//
//  Created by Laurent Stéphenne on 2025-10-03.
//

import SwiftUI


struct ContentView: View {
    @StateObject private var bluetoothVM = BluetoothManager()

    var body: some View {
        VStack {
            HStack {
                Button("Scan for 10s") {
                    bluetoothVM.scanForDevices()
                }
                Button("Stop Now") {
                    bluetoothVM.stopScan()
                }
            }
            List(bluetoothVM.devices, id: \.identifier) { device in
                VStack(alignment: .leading) {
                    Text("Name: \(device.name)")
                        .font(.headline)
                    Text("UUID: \(device.identifier.uuidString)")
                    Text("RSSI: \(device.rssi)")
                    Text("Advertisement: \(device.advertisementData.description)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(5)
                    
                    if device.connectable {
                        Spacer().frame(height: 8)
                        Button("Connect") {
                            print("Connect tapped for \(device.name)")
                            bluetoothVM.connect(device: device)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
