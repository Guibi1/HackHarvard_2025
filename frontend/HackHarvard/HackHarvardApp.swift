import SwiftUI

@main
struct HackHarvardApp: App {
    @State private var modelData = ModelData()
    @State private var preferredColumn: NavigationSplitViewColumn = .detail

    var body: some Scene {
        WindowGroup {
            switch modelData.bluetooth {
            case .client(let bluetoothManager):
                ClientView(bluetoothManager: bluetoothManager)
                    .environment(modelData)

            case .server(let bluetoothManager):
                ServerView(bluetoothManager: bluetoothManager)
                    .environment(modelData)
            }
        }
    }
}
