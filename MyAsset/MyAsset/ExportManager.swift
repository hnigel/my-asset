import Foundation
import CoreData
import UniformTypeIdentifiers

@MainActor
class ExportManager: ObservableObject {
    private let portfolioManager = PortfolioManager()
    private let textExportManager = TextExportManager()
    
    enum ExportFormat: String, CaseIterable {
        case text = "Text Summary"
        
        var fileExtension: String {
            return "txt"
        }
        
        var contentType: UTType {
            return .plainText
        }
    }
    
    func exportPortfolio(_ portfolio: Portfolio) async -> URL? {
        return await exportToText(portfolio)
    }
    
    private func exportToText(_ portfolio: Portfolio) async -> URL? {
        let textContent = await textExportManager.generatePortfolioTextSummary(portfolio)
        return saveToFile(content: textContent, fileName: "\(portfolio.name ?? "Portfolio")_summary.txt")
    }
    
    private func saveToFile(content: String, fileName: String) -> URL? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("File save error: \(error)")
            return nil
        }
    }
    
}