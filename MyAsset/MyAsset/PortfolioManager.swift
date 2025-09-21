import Foundation
import CoreData

@MainActor
class PortfolioManager: ObservableObject {
    private let dataManager: DataManager
    private let stockPriceService: StockPriceService
    
    init(dataManager: DataManager = DataManager.shared, stockPriceService: StockPriceService? = nil) {
        self.dataManager = dataManager
        self.stockPriceService = stockPriceService ?? StockPriceService()
    }
    
    func createPortfolio(name: String) -> Portfolio {
        let portfolio = Portfolio(context: dataManager.context)
        portfolio.portfolioID = UUID()
        portfolio.name = name
        portfolio.createdDate = Date()
        
        dataManager.save()
        return portfolio
    }
    
    func deletePortfolio(_ portfolio: Portfolio) {
        dataManager.context.delete(portfolio)
        dataManager.save()
    }
    
    func updateHolding(_ holding: Holding, quantity: Int32, pricePerShare: Decimal) {
        guard let context = holding.managedObjectContext else {
            print("Warning: Holding has no managed object context")
            return
        }
        
        // Use async perform to prevent blocking and deadlocks
        context.perform {
            guard !holding.isDeleted else {
                print("Warning: Attempting to update deleted holding")
                return
            }
            
            holding.quantity = Double(quantity)
            holding.pricePerShare = NSDecimalNumber(decimal: pricePerShare)
            self.dataManager.save(context: context)
        }
    }

    func updateHolding(_ holding: Holding, quantity: Int32, pricePerShare: Decimal, datePurchased: Date?) {
        guard let context = holding.managedObjectContext else {
            print("Warning: Holding has no managed object context")
            return
        }
        
        // Use async perform to prevent blocking and deadlocks
        context.perform {
            guard !holding.isDeleted else {
                print("Warning: Attempting to update deleted holding")
                return
            }
            
            holding.quantity = Double(quantity)
            holding.pricePerShare = NSDecimalNumber(decimal: pricePerShare)
            if let datePurchased = datePurchased {
                holding.purchaseDate = datePurchased
            }
            self.dataManager.save(context: context)
        }
    }

    func deleteHolding(_ holding: Holding) {
        guard let context = holding.managedObjectContext else {
            print("Warning: Holding has no managed object context")
            return
        }
        
        // Use performAndWait to ensure proper context isolation
        context.performAndWait {
            guard !holding.isDeleted else {
                print("Warning: Attempting to delete already deleted holding")
                return
            }
            
            context.delete(holding)
            try? context.save()
        }
    }

    func addHolding(to portfolio: Portfolio, symbol: String, quantity: Int32, pricePerShare: Decimal, datePurchased: Date) -> Holding {
        let stock = findOrCreateStock(symbol: symbol)
        
        // Update stock with current price if it's more recent
        stock.currentPrice = NSDecimalNumber(decimal: pricePerShare)
        stock.lastUpdated = Date()
        
        let holding = Holding(context: dataManager.context)
        holding.id = UUID()
        holding.quantity = Double(quantity)
        holding.pricePerShare = NSDecimalNumber(decimal: pricePerShare)
        holding.purchaseDate = datePurchased
        holding.stock = stock
        holding.portfolio = portfolio
        
        dataManager.save()
        return holding
    }
    
    // New method that correctly separates purchase price from current price
    func addHoldingWithCurrentPrice(to portfolio: Portfolio, symbol: String, quantity: Int32, pricePerShare: Decimal, currentPrice: Decimal, datePurchased: Date) -> Holding {
        let stock = findOrCreateStock(symbol: symbol)
        
        // Always update stock with the CURRENT price, not the purchase price
        stock.currentPrice = NSDecimalNumber(decimal: currentPrice)
        stock.lastUpdated = Date()
        
        let holding = Holding(context: dataManager.context)
        holding.id = UUID()
        holding.quantity = Double(quantity)
        holding.pricePerShare = NSDecimalNumber(decimal: pricePerShare) // This is the purchase price
        holding.purchaseDate = datePurchased
        holding.stock = stock
        holding.portfolio = portfolio
        
        dataManager.save()
        return holding
    }

    // New method for adding holdings with automatic price fetching
    func addHolding(to portfolio: Portfolio, stockQuote: StockQuote, quantity: Int32, datePurchased: Date) async throws -> Holding {
        let stock = findOrCreateStock(symbol: stockQuote.symbol)
        
        // Update stock with fetched data
        stock.currentPrice = NSDecimalNumber(value: stockQuote.price)
        stock.lastUpdated = stockQuote.lastUpdated
        if let companyName = stockQuote.companyName, !companyName.isEmpty {
            stock.name = companyName
        }
        
        let holding = Holding(context: dataManager.context)
        holding.id = UUID()
        holding.quantity = Double(quantity)
        holding.pricePerShare = NSDecimalNumber(value: stockQuote.price)
        holding.purchaseDate = datePurchased
        holding.stock = stock
        holding.portfolio = portfolio
        
        dataManager.save()
        return holding
    }
    
    func findStock(symbol: String) -> Stock? {
        let cleanSymbol = symbol.uppercased()
        let request: NSFetchRequest<Stock> = Stock.fetchRequest()
        request.predicate = NSPredicate(format: "symbol == %@", cleanSymbol)
        request.fetchLimit = 1
        request.returnsObjectsAsFaults = false
        
        return try? dataManager.context.fetch(request).first
    }
    
    func save() {
        dataManager.save()
    }
    
    private func findOrCreateStock(symbol: String) -> Stock {
        let cleanSymbol = symbol.uppercased()
        let request: NSFetchRequest<Stock> = Stock.fetchRequest()
        request.predicate = NSPredicate(format: "symbol == %@", cleanSymbol)
        request.fetchLimit = 1
        request.returnsObjectsAsFaults = false
        
        if let existingStock = try? dataManager.context.fetch(request).first {
            return existingStock
        }
        
        let newStock = Stock(context: dataManager.context)
        newStock.stockID = UUID()
        newStock.symbol = cleanSymbol
        newStock.name = ""
        newStock.currentPrice = NSDecimalNumber(value: 0)
        newStock.lastUpdated = Date()
        
        return newStock
    }
    
    func fetchPortfolios(limit: Int? = nil) -> [Portfolio] {
        let request: NSFetchRequest<Portfolio> = Portfolio.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
        request.returnsObjectsAsFaults = false
        request.includesSubentities = false
        
        if let limit = limit {
            request.fetchLimit = limit
        }
        
        do {
            return try dataManager.context.fetch(request)
        } catch {
            print("Fetch portfolios error: \(error.localizedDescription)")
            return []
        }
    }
    
    func calculatePortfolioValue(_ portfolio: Portfolio) -> Decimal {
        // Use manual calculation to ensure we get effective prices (including user-provided data)
        // Core Data aggregation doesn't support computed properties
        guard let holdings = portfolio.holdings as? Set<Holding> else { return 0 }
        return holdings.reduce(0) { total, holding in
            let currentPrice = holding.stock?.effectiveCurrentPrice ?? 0
            let quantity = Decimal(holding.quantity)
            return total + (currentPrice * quantity)
        }
    }
    
    func getPortfolioPerformance(_ portfolio: Portfolio, days: Int = 30) -> [PortfolioPerformanceData] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        guard let holdings = portfolio.holdings as? Set<Holding> else { return [] }
        
        var performanceData: [PortfolioPerformanceData] = []
        var currentDate = startOfDay(for: startDate)
        let endDate = startOfDay(for: Date())
        
        while currentDate <= endDate {
            var dailyValue: Decimal = 0
            
            for holding in holdings {
                if let priceHistory = getPriceForDate(stock: holding.stock, date: currentDate) {
                    let quantity = Decimal(holding.quantity)
                    dailyValue += (priceHistory * quantity)
                }
            }
            
            performanceData.append(PortfolioPerformanceData(date: currentDate, value: dailyValue))
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? Date()
        }
        
        return performanceData
    }
    
    private func getPriceForDate(stock: Stock?, date: Date) -> Decimal? {
        guard let stock = stock else { return nil }
        
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        
        // Use optimized fetch request instead of loading all price history
        let request: NSFetchRequest<PriceHistory> = PriceHistory.fetchRequest()
        request.predicate = NSPredicate(format: "stock == %@ AND date <= %@", stock, targetDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchLimit = 1
        request.returnsObjectsAsFaults = false
        
        do {
            if let closestPrice = try dataManager.context.fetch(request).first {
                return closestPrice.closePrice?.decimalValue ?? 0
            }
        } catch {
            print("Price history fetch error: \(error.localizedDescription)")
        }
        
        return stock.currentPrice?.decimalValue ?? 0
    }

    // MARK: - Daily Change Helpers
    private func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    /// Return today's change (value, percent) compared to the start-of-day price, if available.
    func getDailyChange(for stock: Stock?) -> (change: Decimal, percent: Decimal)? {
        guard let stock = stock,
              let current = stock.currentPrice?.decimalValue as Decimal? else { return nil }
        let referenceDate = startOfDay(for: Date())
        guard let openPrice = getPriceForDate(stock: stock, date: referenceDate) else { return nil }
        let change = current - openPrice
        let percent = openPrice > 0 ? (change / openPrice) * 100 : 0
        return (change, percent)
    }

}

struct PortfolioPerformanceData {
    let date: Date
    let value: Decimal
}


// MARK: - Performance and Analytics Extensions
extension PortfolioManager {
    
    /// Batch create multiple holdings for better performance
    func batchAddHoldings(
        to portfolio: Portfolio,
        holdings: [(symbol: String, quantity: Int32, pricePerShare: Decimal, datePurchased: Date)]
    ) {
        dataManager.performInBackground({ context in
            let portfolioInContext = context.object(with: portfolio.objectID) as! Portfolio
            
            for holdingData in holdings {
                let stock = self.findOrCreateStockInContext(symbol: holdingData.symbol, context: context)
                
                let holding = Holding(context: context)
                holding.id = UUID()
                holding.quantity = Double(holdingData.quantity)
                holding.pricePerShare = NSDecimalNumber(decimal: holdingData.pricePerShare)
                holding.purchaseDate = holdingData.datePurchased
                holding.stock = stock
                holding.portfolio = portfolioInContext
            }
            
            try context.save()
        }) { result in
            switch result {
            case .success:
                print("Batch holdings added successfully")
            case .failure(let error):
                print("Batch add holdings error: \(error.localizedDescription)")
            }
        }
    }

    private func findOrCreateStockInContext(symbol: String, context: NSManagedObjectContext) -> Stock {
        let cleanSymbol = symbol.uppercased()
        let request: NSFetchRequest<Stock> = Stock.fetchRequest()
        request.predicate = NSPredicate(format: "symbol == %@", cleanSymbol)
        request.fetchLimit = 1
        
        if let existingStock = try? context.fetch(request).first {
            return existingStock
        }
        
        let newStock = Stock(context: context)
        newStock.stockID = UUID()
        newStock.symbol = cleanSymbol
        newStock.name = ""
        newStock.currentPrice = NSDecimalNumber(value: 0)
        newStock.lastUpdated = Date()
        
        return newStock
    }
    
    /// Get portfolio statistics with optimized queries
    func getPortfolioStatistics(_ portfolio: Portfolio) -> PortfolioStatistics {
        let request: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "Holding")
        request.predicate = NSPredicate(format: "portfolio == %@", portfolio)
        request.resultType = .dictionaryResultType
        
        let countExpression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "id")])
        let countExpressionDescription = NSExpressionDescription()
        countExpressionDescription.name = "count"
        countExpressionDescription.expression = countExpression
        countExpressionDescription.expressionResultType = .integer32AttributeType
        
        let totalQuantityExpression = NSExpression(forFunction: "sum:", arguments: [NSExpression(forKeyPath: "quantity")])
        let totalQuantityExpressionDescription = NSExpressionDescription()
        totalQuantityExpressionDescription.name = "totalQuantity"
        totalQuantityExpressionDescription.expression = totalQuantityExpression
        totalQuantityExpressionDescription.expressionResultType = .integer32AttributeType
        
        request.propertiesToFetch = [countExpressionDescription, totalQuantityExpressionDescription]
        
        do {
            let results = try dataManager.context.fetch(request)
            if let result = results.first {
                let holdingsCount = result["count"] as? Int32 ?? 0
                let totalShares = result["totalQuantity"] as? Int32 ?? 0
                let currentValue = calculatePortfolioValue(portfolio)
                
                return PortfolioStatistics(
                    holdingsCount: holdingsCount,
                    totalShares: totalShares,
                    currentValue: currentValue
                )
            }
        } catch {
            print("Portfolio statistics error: \(error.localizedDescription)")
        }
        
        return PortfolioStatistics(
            holdingsCount: 0,
            totalShares: 0,
            currentValue: 0
        )
    }

    /// Clean up old price history data to maintain performance
    func cleanupOldPriceHistory(olderThan days: Int = 365) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        dataManager.performInBackground({ context in
            let request: NSFetchRequest<PriceHistory> = PriceHistory.fetchRequest()
            request.predicate = NSPredicate(format: "date < %@", cutoffDate as NSDate)
            
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)
            try context.execute(batchDeleteRequest)
            try context.save()
        }) { result in
            switch result {
            case .success:
                print("Old price history cleaned up successfully")
            case .failure(let error):
                print("Price history cleanup error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Get holdings with advanced filtering and sorting
    func getHoldings(
        for portfolio: Portfolio,
        sortBy sortKey: String = "datePurchased",
        ascending: Bool = false,
        limit: Int? = nil
    ) -> [Holding] {
        let request: NSFetchRequest<Holding> = Holding.fetchRequest()
        request.predicate = NSPredicate(format: "portfolio == %@", portfolio)
        request.sortDescriptors = [NSSortDescriptor(key: sortKey, ascending: ascending)]
        request.relationshipKeyPathsForPrefetching = ["stock"]
        request.returnsObjectsAsFaults = false
        
        if let limit = limit {
            request.fetchLimit = limit
        }
        
        do {
            return try dataManager.context.fetch(request)
        } catch {
            print("Holdings fetch error: \(error.localizedDescription)")
            return []
        }
    }
}

struct PortfolioStatistics {
    let holdingsCount: Int32
    let totalShares: Int32
    let currentValue: Decimal
}
