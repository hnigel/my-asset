//
//  ContentView.swift
//  my asset
//
//  Created by 洪子翔 on 2025/9/7.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var backgroundService: BackgroundUpdateService
    
    var body: some View {
        TabView {
            PortfolioListView()
                .tabItem {
                    Image(systemName: "chart.pie.fill")
                    Text("Portfolios")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var backgroundService: BackgroundUpdateService
    @StateObject private var exportManager = ExportManager()
    @State private var isUpdating = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                Section("Data Management") {
                    Button("Update All Prices") {
                        updatePrices()
                    }
                    .disabled(isUpdating)
                    
                    if isUpdating {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Updating prices...")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Features")
                        Text("• Portfolio tracking\n• Real-time price updates\n• Performance analytics\n• Export/Import (CSV, JSON)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Import Result", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func updatePrices() {
        isUpdating = true
        Task {
            await backgroundService.updateAllStockPrices()
            await MainActor.run {
                isUpdating = false
            }
        }
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, DataManager.shared.context)
            .environmentObject(DataManager.shared)
            .environmentObject(BackgroundUpdateService())
    }
}
