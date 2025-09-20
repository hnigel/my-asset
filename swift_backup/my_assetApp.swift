//
//  my_assetApp.swift
//  my asset
//
//  Created by 洪子翔 on 2025/9/7.
//

import SwiftUI

@main
@MainActor
struct my_assetApp: App {
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
