import Foundation
import CoreData

extension DataManager {
    
    // Create the Core Data model programmatically
    static func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Portfolio Entity
        let portfolioEntity = NSEntityDescription()
        portfolioEntity.name = "Portfolio"
        portfolioEntity.managedObjectClassName = "Portfolio"
        
        let portfolioId = NSAttributeDescription()
        portfolioId.name = "id"
        portfolioId.type = .uuid
        portfolioId.isOptional = true
        
        let portfolioPortfolioID = NSAttributeDescription()
        portfolioPortfolioID.name = "portfolioID"
        portfolioPortfolioID.type = .uuid
        portfolioPortfolioID.isOptional = true
        
        let portfolioName = NSAttributeDescription()
        portfolioName.name = "name"
        portfolioName.type = .string
        portfolioName.isOptional = true
        
        let portfolioCreatedAt = NSAttributeDescription()
        portfolioCreatedAt.name = "createdAt"
        portfolioCreatedAt.type = .date
        portfolioCreatedAt.isOptional = true
        
        let portfolioCreatedDate = NSAttributeDescription()
        portfolioCreatedDate.name = "createdDate"
        portfolioCreatedDate.type = .date
        portfolioCreatedDate.isOptional = true
        
        let portfolioUpdatedAt = NSAttributeDescription()
        portfolioUpdatedAt.name = "updatedAt"
        portfolioUpdatedAt.type = .date
        portfolioUpdatedAt.isOptional = true
        
        portfolioEntity.properties = [portfolioId, portfolioPortfolioID, portfolioName, portfolioCreatedAt, portfolioCreatedDate, portfolioUpdatedAt]
        
        // Stock Entity
        let stockEntity = NSEntityDescription()
        stockEntity.name = "Stock"
        stockEntity.managedObjectClassName = "Stock"
        
        let stockSymbol = NSAttributeDescription()
        stockSymbol.name = "symbol"
        stockSymbol.type = .string
        stockSymbol.isOptional = true
        
        let stockName = NSAttributeDescription()
        stockName.name = "name"
        stockName.type = .string
        stockName.isOptional = true
        
        let stockCurrentPrice = NSAttributeDescription()
        stockCurrentPrice.name = "currentPrice"
        stockCurrentPrice.type = .decimal
        stockCurrentPrice.isOptional = true
        
        let stockPreviousClose = NSAttributeDescription()
        stockPreviousClose.name = "previousClose"
        stockPreviousClose.type = .double
        stockPreviousClose.defaultValue = 0.0
        
        let stockChange = NSAttributeDescription()
        stockChange.name = "change"
        stockChange.type = .double
        stockChange.defaultValue = 0.0
        
        let stockChangePercent = NSAttributeDescription()
        stockChangePercent.name = "changePercent"
        stockChangePercent.type = .double
        stockChangePercent.defaultValue = 0.0
        
        let stockVolume = NSAttributeDescription()
        stockVolume.name = "volume"
        stockVolume.type = .integer64
        stockVolume.defaultValue = 0
        
        let stockMarketCap = NSAttributeDescription()
        stockMarketCap.name = "marketCap"
        stockMarketCap.type = .double
        stockMarketCap.defaultValue = 0.0
        
        let stockSector = NSAttributeDescription()
        stockSector.name = "sector"
        stockSector.type = .string
        stockSector.isOptional = true
        
        let stockIndustry = NSAttributeDescription()
        stockIndustry.name = "industry"
        stockIndustry.type = .string
        stockIndustry.isOptional = true
        
        let stockLastUpdated = NSAttributeDescription()
        stockLastUpdated.name = "lastUpdated"
        stockLastUpdated.type = .date
        stockLastUpdated.isOptional = true
        
        let stockStockID = NSAttributeDescription()
        stockStockID.name = "stockID"
        stockStockID.type = .uuid
        stockStockID.isOptional = true
        
        stockEntity.properties = [stockSymbol, stockName, stockCurrentPrice, stockPreviousClose, stockChange, stockChangePercent, stockVolume, stockMarketCap, stockSector, stockIndustry, stockLastUpdated, stockStockID]
        
        // Holding Entity
        let holdingEntity = NSEntityDescription()
        holdingEntity.name = "Holding"
        holdingEntity.managedObjectClassName = "Holding"
        
        let holdingId = NSAttributeDescription()
        holdingId.name = "id"
        holdingId.type = .uuid
        holdingId.isOptional = true
        
        let holdingQuantity = NSAttributeDescription()
        holdingQuantity.name = "quantity"
        holdingQuantity.type = .double
        holdingQuantity.defaultValue = 0.0
        
        let holdingAverageCost = NSAttributeDescription()
        holdingAverageCost.name = "averageCost"
        holdingAverageCost.type = .double
        holdingAverageCost.defaultValue = 0.0
        
        let holdingPurchaseDate = NSAttributeDescription()
        holdingPurchaseDate.name = "purchaseDate"
        holdingPurchaseDate.type = .date
        holdingPurchaseDate.isOptional = true
        
        let holdingCreatedAt = NSAttributeDescription()
        holdingCreatedAt.name = "createdAt"
        holdingCreatedAt.type = .date
        holdingCreatedAt.isOptional = true
        
        let holdingUpdatedAt = NSAttributeDescription()
        holdingUpdatedAt.name = "updatedAt"
        holdingUpdatedAt.type = .date
        holdingUpdatedAt.isOptional = true
        
        let holdingPricePerShare = NSAttributeDescription()
        holdingPricePerShare.name = "pricePerShare"
        holdingPricePerShare.type = .decimal
        holdingPricePerShare.isOptional = true
        
        holdingEntity.properties = [holdingId, holdingQuantity, holdingAverageCost, holdingPurchaseDate, holdingCreatedAt, holdingUpdatedAt, holdingPricePerShare]
        
        // Dividend Entity
        let dividendEntity = NSEntityDescription()
        dividendEntity.name = "Dividend"
        dividendEntity.managedObjectClassName = "Dividend"
        
        let dividendId = NSAttributeDescription()
        dividendId.name = "id"
        dividendId.type = .uuid
        dividendId.isOptional = true
        
        let dividendAmount = NSAttributeDescription()
        dividendAmount.name = "amount"
        dividendAmount.type = .decimal
        dividendAmount.isOptional = true
        
        let dividendExDate = NSAttributeDescription()
        dividendExDate.name = "exDate"
        dividendExDate.type = .date
        dividendExDate.isOptional = true
        
        let dividendPayDate = NSAttributeDescription()
        dividendPayDate.name = "payDate"
        dividendPayDate.type = .date
        dividendPayDate.isOptional = true
        
        let dividendDeclarationDate = NSAttributeDescription()
        dividendDeclarationDate.name = "declarationDate"
        dividendDeclarationDate.type = .date
        dividendDeclarationDate.isOptional = true
        
        let dividendFrequency = NSAttributeDescription()
        dividendFrequency.name = "frequency"
        dividendFrequency.type = .string
        dividendFrequency.isOptional = true
        
        let dividendCreatedAt = NSAttributeDescription()
        dividendCreatedAt.name = "createdAt"
        dividendCreatedAt.type = .date
        dividendCreatedAt.isOptional = true
        
        let dividendAnnualizedAmount = NSAttributeDescription()
        dividendAnnualizedAmount.name = "annualizedAmount"
        dividendAnnualizedAmount.type = .decimal
        dividendAnnualizedAmount.isOptional = true
        
        let dividendYield = NSAttributeDescription()
        dividendYield.name = "yield"
        dividendYield.type = .decimal
        dividendYield.isOptional = true
        
        let dividendCurrency = NSAttributeDescription()
        dividendCurrency.name = "currency"
        dividendCurrency.type = .string
        dividendCurrency.isOptional = true
        
        let dividendDividendType = NSAttributeDescription()
        dividendDividendType.name = "dividendType"
        dividendDividendType.type = .string
        dividendDividendType.isOptional = true
        
        let dividendPaymentDate = NSAttributeDescription()
        dividendPaymentDate.name = "paymentDate"
        dividendPaymentDate.type = .date
        dividendPaymentDate.isOptional = true
        
        let dividendExDividendDate = NSAttributeDescription()
        dividendExDividendDate.name = "exDividendDate"
        dividendExDividendDate.type = .date
        dividendExDividendDate.isOptional = true
        
        let dividendRecordDate = NSAttributeDescription()
        dividendRecordDate.name = "recordDate"
        dividendRecordDate.type = .date
        dividendRecordDate.isOptional = true
        
        let dividendIsUserProvided = NSAttributeDescription()
        dividendIsUserProvided.name = "isUserProvided"
        dividendIsUserProvided.type = .boolean
        dividendIsUserProvided.defaultValue = false
        
        let dividendDataSource = NSAttributeDescription()
        dividendDataSource.name = "dataSource"
        dividendDataSource.type = .string
        dividendDataSource.isOptional = true
        
        let dividendNotes = NSAttributeDescription()
        dividendNotes.name = "notes"
        dividendNotes.type = .string
        dividendNotes.isOptional = true
        
        let dividendLastUpdated = NSAttributeDescription()
        dividendLastUpdated.name = "lastUpdated"
        dividendLastUpdated.type = .date
        dividendLastUpdated.isOptional = true
        
        dividendEntity.properties = [dividendId, dividendAmount, dividendExDate, dividendPayDate, dividendDeclarationDate, dividendFrequency, dividendCreatedAt, dividendAnnualizedAmount, dividendYield, dividendCurrency, dividendDividendType, dividendPaymentDate, dividendExDividendDate, dividendRecordDate, dividendIsUserProvided, dividendDataSource, dividendNotes, dividendLastUpdated]
        
        // PriceHistory Entity
        let priceHistoryEntity = NSEntityDescription()
        priceHistoryEntity.name = "PriceHistory"
        priceHistoryEntity.managedObjectClassName = "PriceHistory"
        
        let priceHistoryPriceHistoryID = NSAttributeDescription()
        priceHistoryPriceHistoryID.name = "priceHistoryID"
        priceHistoryPriceHistoryID.type = .uuid
        priceHistoryPriceHistoryID.isOptional = true
        
        let priceHistoryDate = NSAttributeDescription()
        priceHistoryDate.name = "date"
        priceHistoryDate.type = .date
        priceHistoryDate.isOptional = true
        
        let priceHistoryOpenPrice = NSAttributeDescription()
        priceHistoryOpenPrice.name = "openPrice"
        priceHistoryOpenPrice.type = .decimal
        priceHistoryOpenPrice.isOptional = true
        
        let priceHistoryHighPrice = NSAttributeDescription()
        priceHistoryHighPrice.name = "highPrice"
        priceHistoryHighPrice.type = .decimal
        priceHistoryHighPrice.isOptional = true
        
        let priceHistoryLowPrice = NSAttributeDescription()
        priceHistoryLowPrice.name = "lowPrice"
        priceHistoryLowPrice.type = .decimal
        priceHistoryLowPrice.isOptional = true
        
        let priceHistoryClosePrice = NSAttributeDescription()
        priceHistoryClosePrice.name = "closePrice"
        priceHistoryClosePrice.type = .decimal
        priceHistoryClosePrice.isOptional = true
        
        let priceHistoryVolume = NSAttributeDescription()
        priceHistoryVolume.name = "volume"
        priceHistoryVolume.type = .integer64
        priceHistoryVolume.defaultValue = 0
        
        priceHistoryEntity.properties = [priceHistoryPriceHistoryID, priceHistoryDate, priceHistoryOpenPrice, priceHistoryHighPrice, priceHistoryLowPrice, priceHistoryClosePrice, priceHistoryVolume]
        
        // AIAnalysisRecord Entity
        let aiAnalysisRecordEntity = NSEntityDescription()
        aiAnalysisRecordEntity.name = "AIAnalysisRecord"
        aiAnalysisRecordEntity.managedObjectClassName = "AIAnalysisRecord"
        
        // Core Properties
        let aiAnalysisId = NSAttributeDescription()
        aiAnalysisId.name = "id"
        aiAnalysisId.type = .uuid
        aiAnalysisId.isOptional = false
        
        let aiAnalysisPortfolioID = NSAttributeDescription()
        aiAnalysisPortfolioID.name = "portfolioID"
        aiAnalysisPortfolioID.type = .uuid
        aiAnalysisPortfolioID.isOptional = false
        
        let aiAnalysisCreatedDate = NSAttributeDescription()
        aiAnalysisCreatedDate.name = "createdDate"
        aiAnalysisCreatedDate.type = .date
        aiAnalysisCreatedDate.isOptional = false
        
        let aiAnalysisLastViewedDate = NSAttributeDescription()
        aiAnalysisLastViewedDate.name = "lastViewedDate"
        aiAnalysisLastViewedDate.type = .date
        aiAnalysisLastViewedDate.isOptional = true
        
        // Analysis Configuration
        let aiAnalysisAnalysisType = NSAttributeDescription()
        aiAnalysisAnalysisType.name = "analysisType"
        aiAnalysisAnalysisType.type = .string
        aiAnalysisAnalysisType.isOptional = false
        
        let aiAnalysisPrivacySettingsData = NSAttributeDescription()
        aiAnalysisPrivacySettingsData.name = "privacySettingsData"
        aiAnalysisPrivacySettingsData.type = .binaryData
        aiAnalysisPrivacySettingsData.isOptional = true
        
        // Analysis Content
        let aiAnalysisAiAnalysisText = NSAttributeDescription()
        aiAnalysisAiAnalysisText.name = "aiAnalysisText"
        aiAnalysisAiAnalysisText.type = .string
        aiAnalysisAiAnalysisText.isOptional = false
        
        let aiAnalysisPortfolioSummary = NSAttributeDescription()
        aiAnalysisPortfolioSummary.name = "portfolioSummary"
        aiAnalysisPortfolioSummary.type = .string
        aiAnalysisPortfolioSummary.isOptional = false
        
        let aiAnalysisCombinedReport = NSAttributeDescription()
        aiAnalysisCombinedReport.name = "combinedReport"
        aiAnalysisCombinedReport.type = .string
        aiAnalysisCombinedReport.isOptional = false
        
        // Metadata
        let aiAnalysisTitle = NSAttributeDescription()
        aiAnalysisTitle.name = "title"
        aiAnalysisTitle.type = .string
        aiAnalysisTitle.isOptional = true
        
        let aiAnalysisWordCount = NSAttributeDescription()
        aiAnalysisWordCount.name = "wordCount"
        aiAnalysisWordCount.type = .integer32
        aiAnalysisWordCount.isOptional = false
        aiAnalysisWordCount.defaultValue = 0
        
        let aiAnalysisIsFavorite = NSAttributeDescription()
        aiAnalysisIsFavorite.name = "isFavorite"
        aiAnalysisIsFavorite.type = .boolean
        aiAnalysisIsFavorite.isOptional = false
        aiAnalysisIsFavorite.defaultValue = false
        
        aiAnalysisRecordEntity.properties = [aiAnalysisId, aiAnalysisPortfolioID, aiAnalysisCreatedDate, aiAnalysisLastViewedDate, aiAnalysisAnalysisType, aiAnalysisPrivacySettingsData, aiAnalysisAiAnalysisText, aiAnalysisPortfolioSummary, aiAnalysisCombinedReport, aiAnalysisTitle, aiAnalysisWordCount, aiAnalysisIsFavorite]
        
        // Relationships
        
        // Portfolio -> Holdings (one-to-many)
        let portfolioHoldingsRelationship = NSRelationshipDescription()
        portfolioHoldingsRelationship.name = "holdings"
        portfolioHoldingsRelationship.destinationEntity = holdingEntity
        portfolioHoldingsRelationship.isOptional = true
        portfolioHoldingsRelationship.deleteRule = .cascadeDeleteRule
        portfolioHoldingsRelationship.maxCount = 0 // to-many
        
        // Holdings -> Portfolio (many-to-one)
        let holdingPortfolioRelationship = NSRelationshipDescription()
        holdingPortfolioRelationship.name = "portfolio"
        holdingPortfolioRelationship.destinationEntity = portfolioEntity
        holdingPortfolioRelationship.isOptional = true
        holdingPortfolioRelationship.maxCount = 1 // to-one
        
        // Set inverse relationships
        portfolioHoldingsRelationship.inverseRelationship = holdingPortfolioRelationship
        holdingPortfolioRelationship.inverseRelationship = portfolioHoldingsRelationship
        
        // Holdings -> Stock (many-to-one)
        let holdingStockRelationship = NSRelationshipDescription()
        holdingStockRelationship.name = "stock"
        holdingStockRelationship.destinationEntity = stockEntity
        holdingStockRelationship.isOptional = true
        holdingStockRelationship.maxCount = 1 // to-one
        
        // Stock -> Holdings (one-to-many)
        let stockHoldingsRelationship = NSRelationshipDescription()
        stockHoldingsRelationship.name = "holdings"
        stockHoldingsRelationship.destinationEntity = holdingEntity
        stockHoldingsRelationship.isOptional = true
        stockHoldingsRelationship.deleteRule = .cascadeDeleteRule
        stockHoldingsRelationship.maxCount = 0 // to-many
        
        // Set inverse relationships
        holdingStockRelationship.inverseRelationship = stockHoldingsRelationship
        stockHoldingsRelationship.inverseRelationship = holdingStockRelationship
        
        // Stock -> Dividends (one-to-many)
        let stockDividendsRelationship = NSRelationshipDescription()
        stockDividendsRelationship.name = "dividends"
        stockDividendsRelationship.destinationEntity = dividendEntity
        stockDividendsRelationship.isOptional = true
        stockDividendsRelationship.deleteRule = .cascadeDeleteRule
        stockDividendsRelationship.maxCount = 0 // to-many
        
        // Dividends -> Stock (many-to-one)
        let dividendStockRelationship = NSRelationshipDescription()
        dividendStockRelationship.name = "stock"
        dividendStockRelationship.destinationEntity = stockEntity
        dividendStockRelationship.isOptional = true
        dividendStockRelationship.maxCount = 1 // to-one
        
        // Set inverse relationships
        stockDividendsRelationship.inverseRelationship = dividendStockRelationship
        dividendStockRelationship.inverseRelationship = stockDividendsRelationship
        
        // Stock -> PriceHistory (one-to-many)
        let stockPriceHistoryRelationship = NSRelationshipDescription()
        stockPriceHistoryRelationship.name = "priceHistory"
        stockPriceHistoryRelationship.destinationEntity = priceHistoryEntity
        stockPriceHistoryRelationship.isOptional = true
        stockPriceHistoryRelationship.deleteRule = .cascadeDeleteRule
        stockPriceHistoryRelationship.maxCount = 0 // to-many
        
        // PriceHistory -> Stock (many-to-one)
        let priceHistoryStockRelationship = NSRelationshipDescription()
        priceHistoryStockRelationship.name = "stock"
        priceHistoryStockRelationship.destinationEntity = stockEntity
        priceHistoryStockRelationship.isOptional = true
        priceHistoryStockRelationship.maxCount = 1 // to-one
        
        // Set inverse relationships
        stockPriceHistoryRelationship.inverseRelationship = priceHistoryStockRelationship
        priceHistoryStockRelationship.inverseRelationship = stockPriceHistoryRelationship
        
        // Portfolio -> AIAnalysisRecord (one-to-many)
        let portfolioAIAnalysisRelationship = NSRelationshipDescription()
        portfolioAIAnalysisRelationship.name = "aiAnalysisRecords"
        portfolioAIAnalysisRelationship.destinationEntity = aiAnalysisRecordEntity
        portfolioAIAnalysisRelationship.isOptional = true
        portfolioAIAnalysisRelationship.deleteRule = .cascadeDeleteRule
        portfolioAIAnalysisRelationship.maxCount = 0 // to-many
        
        // AIAnalysisRecord -> Portfolio (many-to-one)
        let aiAnalysisPortfolioRelationship = NSRelationshipDescription()
        aiAnalysisPortfolioRelationship.name = "portfolio"
        aiAnalysisPortfolioRelationship.destinationEntity = portfolioEntity
        aiAnalysisPortfolioRelationship.isOptional = false
        aiAnalysisPortfolioRelationship.maxCount = 1 // to-one
        
        // Set inverse relationships
        portfolioAIAnalysisRelationship.inverseRelationship = aiAnalysisPortfolioRelationship
        aiAnalysisPortfolioRelationship.inverseRelationship = portfolioAIAnalysisRelationship
        
        // Add relationships to entities
        portfolioEntity.properties.append(contentsOf: [portfolioHoldingsRelationship, portfolioAIAnalysisRelationship])
        holdingEntity.properties.append(contentsOf: [holdingPortfolioRelationship, holdingStockRelationship])
        stockEntity.properties.append(contentsOf: [stockHoldingsRelationship, stockDividendsRelationship, stockPriceHistoryRelationship])
        dividendEntity.properties.append(contentsOf: [dividendStockRelationship])
        priceHistoryEntity.properties.append(contentsOf: [priceHistoryStockRelationship])
        aiAnalysisRecordEntity.properties.append(contentsOf: [aiAnalysisPortfolioRelationship])
        
        // Add entities to model
        model.entities = [portfolioEntity, stockEntity, holdingEntity, dividendEntity, priceHistoryEntity, aiAnalysisRecordEntity]
        
        return model
    }
}