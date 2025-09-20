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
        
        let portfolioName = NSAttributeDescription()
        portfolioName.name = "name"
        portfolioName.type = .string
        portfolioName.isOptional = true
        
        let portfolioCreatedAt = NSAttributeDescription()
        portfolioCreatedAt.name = "createdAt"
        portfolioCreatedAt.type = .date
        portfolioCreatedAt.isOptional = true
        
        let portfolioUpdatedAt = NSAttributeDescription()
        portfolioUpdatedAt.name = "updatedAt"
        portfolioUpdatedAt.type = .date
        portfolioUpdatedAt.isOptional = true
        
        portfolioEntity.properties = [portfolioId, portfolioName, portfolioCreatedAt, portfolioUpdatedAt]
        
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
        stockCurrentPrice.type = .double
        stockCurrentPrice.defaultValue = 0.0
        
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
        
        stockEntity.properties = [stockSymbol, stockName, stockCurrentPrice, stockPreviousClose, stockChange, stockChangePercent, stockVolume, stockMarketCap, stockSector, stockIndustry, stockLastUpdated]
        
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
        
        holdingEntity.properties = [holdingId, holdingQuantity, holdingAverageCost, holdingPurchaseDate, holdingCreatedAt, holdingUpdatedAt]
        
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
        dividendAmount.type = .double
        dividendAmount.defaultValue = 0.0
        
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
        
        dividendEntity.properties = [dividendId, dividendAmount, dividendExDate, dividendPayDate, dividendDeclarationDate, dividendFrequency, dividendCreatedAt]
        
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
        
        // Add relationships to entities
        portfolioEntity.properties.append(contentsOf: [portfolioHoldingsRelationship])
        holdingEntity.properties.append(contentsOf: [holdingPortfolioRelationship, holdingStockRelationship])
        stockEntity.properties.append(contentsOf: [stockHoldingsRelationship, stockDividendsRelationship])
        dividendEntity.properties.append(contentsOf: [dividendStockRelationship])
        
        // Add entities to model
        model.entities = [portfolioEntity, stockEntity, holdingEntity, dividendEntity]
        
        return model
    }
}