import Foundation
import CoreData

@objc(AIAnalysisRecord)
public class AIAnalysisRecord: NSManagedObject {
    
    // MARK: - Convenience Properties
    
    var analysisTypeEnum: GeminiAnalysisManager.AnalysisType {
        return GeminiAnalysisManager.AnalysisType(rawValue: analysisType) ?? .comprehensive
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdDate)
    }
    
    var privacySettings: PortfolioAnalysisFormatter.PrivacySettings? {
        guard let data = privacySettingsData else { return nil }
        return try? JSONDecoder().decode(PortfolioAnalysisFormatter.PrivacySettings.self, from: data)
    }
    
    var displayTitle: String {
        return title ?? generateDefaultTitle()
    }
    
    // MARK: - Helper Methods
    
    private func generateDefaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        let dateString = formatter.string(from: createdDate)
        
        return "\(analysisTypeEnum.rawValue) - \(dateString)"
    }
    
    func updateLastViewedDate() {
        lastViewedDate = Date()
    }
    
    // MARK: - Static Methods
    
    static func fetchLatest(for portfolio: Portfolio, in context: NSManagedObjectContext) -> AIAnalysisRecord? {
        let request: NSFetchRequest<AIAnalysisRecord> = AIAnalysisRecord.fetchRequest()
        request.predicate = NSPredicate(format: "portfolioID == %@", portfolio.portfolioID! as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AIAnalysisRecord.createdDate, ascending: false)]
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            return results.first
        } catch {
            print("❌ Failed to fetch latest analysis: \(error)")
            return nil
        }
    }
    
    static func create(from result: GeminiAnalysisManager.AnalysisResult, 
                      for portfolio: Portfolio, 
                      in context: NSManagedObjectContext) -> AIAnalysisRecord {
        let record = AIAnalysisRecord(context: context)
        
        // 基本資訊
        record.id = UUID()
        record.portfolioID = portfolio.portfolioID!
        record.createdDate = Date()
        record.lastViewedDate = Date()
        
        // 分析設定
        record.analysisType = result.analysisType.rawValue
        if let privacyData = try? JSONEncoder().encode(result.privacySettings) {
            record.privacySettingsData = privacyData
        }
        
        // 分析內容
        record.aiAnalysisText = result.aiAnalysis
        record.portfolioSummary = result.portfolioSummary
        record.combinedReport = result.combinedReport
        
        // 元數據
        record.title = nil // 使用自動生成的標題
        record.wordCount = Int32(result.combinedReport.count)
        record.isFavorite = false
        
        // 關聯
        record.portfolio = portfolio
        
        return record
    }
}