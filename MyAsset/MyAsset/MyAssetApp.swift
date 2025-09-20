import SwiftUI

@main
@MainActor
struct MyAssetApp: App {
    let dataManager = DataManager.shared
    let backgroundService = BackgroundUpdateService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataManager.context)
                .environmentObject(dataManager)
                .environmentObject(backgroundService)
        }
    }
    
    init() {
        backgroundService.registerBackgroundTasks()
    }
}