import Foundation
import CoreData

extension AIAnalysisRecord {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AIAnalysisRecord> {
        return NSFetchRequest<AIAnalysisRecord>(entityName: "AIAnalysisRecord")
    }

    // MARK: - Core Properties
    @NSManaged public var id: UUID
    @NSManaged public var portfolioID: UUID
    @NSManaged public var createdDate: Date
    @NSManaged public var lastViewedDate: Date?

    // MARK: - Analysis Configuration
    @NSManaged public var analysisType: String
    @NSManaged public var privacySettingsData: Data?

    // MARK: - Analysis Content
    @NSManaged public var aiAnalysisText: String
    @NSManaged public var portfolioSummary: String
    @NSManaged public var combinedReport: String

    // MARK: - Metadata
    @NSManaged public var title: String?
    @NSManaged public var wordCount: Int32
    @NSManaged public var isFavorite: Bool

    // MARK: - Relationships
    @NSManaged public var portfolio: Portfolio

}

// MARK: - Generated accessors for relationships
extension AIAnalysisRecord : Identifiable {

}