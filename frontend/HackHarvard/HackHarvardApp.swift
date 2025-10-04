import SwiftUI

@main
struct HackHarvardApp: App {
    @State private var modelData = ModelData()
    @State private var preferredColumn: NavigationSplitViewColumn = .detail

    var body: some Scene {
        WindowGroup {
            TabView {
                ForEach(NavigationOptions.mainPages) { page in
                    Tab(page.name, systemImage: page.symbolName) {
                        page.viewForPage()
                            .environment(modelData)
                    }
                }
            }.fullScreenCover(isPresented: $modelData.isConnection) {
                ConnectingView()
                    .environment(modelData)
            }
        }
    }
}
