import Foundation
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif
import CoreData

@MainActor
class BackgroundUpdateService: ObservableObject, @unchecked Sendable {
    private let stockPriceService: StockPriceService
    private let dividendManager = DividendManager()
    
    init() {
        self.stockPriceService = StockPriceService()
    }
    private let dataManager = DataManager.shared
    private let backgroundTaskIdentifier = "com.myasset.stockupdate"
    
    // Rate limiting for stock price updates (5 seconds)
    private var lastStockUpdateTime: Date?
    private let stockUpdateCooldownInterval: TimeInterval = 5.0
    
    // Reuse single background context to prevent threading conflicts
    private lazy var sharedBackgroundContext: NSManagedObjectContext = {
        let context = dataManager.persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }()
    
    // Serialize background operations to prevent race conditions
    private let backgroundQueue = DispatchQueue(label: "background.stock.updates", qos: .utility)
    
    func registerBackgroundTasks() {
        #if canImport(BackgroundTasks) && !targetEnvironment(macCatalyst)
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
                self.handleBackgroundUpdate(task: task as! BGAppRefreshTask)
            }
        }
        #endif
    }
    
    func scheduleBackgroundUpdate() {
        #if canImport(BackgroundTasks) && !targetEnvironment(macCatalyst)
        if #available(iOS 13.0, *) {
            let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
            request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60) // 24 hours from now
            
            try? BGTaskScheduler.shared.submit(request)
        }
        #endif
    }
    
    #if canImport(BackgroundTasks) && os(iOS) && !targetEnvironment(macCatalyst)
    @available(iOS 13.0, *)
    private func handleBackgroundUpdate(task: BGAppRefreshTask) {
        scheduleBackgroundUpdate() // Schedule the next update
        
        let operation = UpdateStockPricesOperation()
        task.expirationHandler = {
            operation.cancel()
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }
        
        let queue = OperationQueue()
        queue.addOperation(operation)
    }
    #endif
    
    func updateAllStockPrices() async {
        // Check rate limiting for stock price updates (5 seconds cooldown)
        let currentTime = Date()
        if let lastUpdate = lastStockUpdateTime,
           currentTime.timeIntervalSince(lastUpdate) < stockUpdateCooldownInterval {
            print("⏱️ Stock price update rate limited. Please wait \(Int(stockUpdateCooldownInterval - currentTime.timeIntervalSince(lastUpdate) + 1)) more seconds.")
            return
        }
        
        // Update timestamp
        lastStockUpdateTime = currentTime
        
        // Serialize all background operations to prevent race conditions
        await withCheckedContinuation { continuation in
            backgroundQueue.async {
                Task {
                    await self.performPriceUpdate()
                    continuation.resume()
                }
            }
        }
    }
    
    private func performPriceUpdate() async {
        let stocks = await fetchAllStocks(using: sharedBackgroundContext)
        let symbols = stocks.compactMap { $0.symbol }
        
        guard !symbols.isEmpty else { return }
        
        // Use real API - no more demo data fallback
        let quotes = await stockPriceService.fetchMultipleStockPrices(symbols: symbols)
        
        // Update stocks sequentially to prevent conflicts
        for (symbol, quote) in quotes {
            await updateStock(symbol: symbol, with: quote, using: sharedBackgroundContext)
            // Also update dividend data
            await updateDividendData(for: symbol, using: sharedBackgroundContext)
        }
        
        // Log failed symbols but don't use demo data
        let successfulSymbols = Set(quotes.keys)
        let failedSymbols = Set(symbols).subtracting(successfulSymbols)
        
        if !failedSymbols.isEmpty {
            print("Failed to update prices for symbols (will remain at last known values or N/A): \(failedSymbols.joined(separator: ", "))")
        }
    }
    
    private func fetchAllStocks(using context: NSManagedObjectContext? = nil) async -> [Stock] {
        let contextToUse = context ?? dataManager.context
        
        do {
            return try await CoreDataThreadingHelper.safeRead(context: contextToUse) { context in
                let request: NSFetchRequest<Stock> = Stock.fetchRequest()
                return try context.fetch(request)
            }
        } catch {
            print("Failed to fetch stocks: \(error)")
            return []
        }
    }
    
    private func updateStock(symbol: String, with quote: StockQuote, using context: NSManagedObjectContext) async {
        do {
            try await CoreDataThreadingHelper.safeWrite(backgroundContext: context) { context in
                let request: NSFetchRequest<Stock> = Stock.fetchRequest()
                request.predicate = NSPredicate(format: "symbol == %@", symbol)
                
                let stocks = try context.fetch(request)
                if let stock = stocks.first {
                    // Always update price from API
                    stock.currentPrice = NSDecimalNumber(value: quote.price)
                    stock.lastUpdated = quote.lastUpdated
                    
                    // Always update company name if it's empty (doesn't interfere with user data)
                    if stock.name?.isEmpty ?? true {
                        stock.name = quote.companyName ?? symbol
                    }
                    
                    // Add price history
                    let priceHistory = PriceHistory(context: context)
                    priceHistory.priceHistoryID = UUID()
                    priceHistory.date = quote.lastUpdated
                    priceHistory.closePrice = NSDecimalNumber(value: quote.price)
                    priceHistory.stock = stock
                }
            }
        } catch {
            print("Failed to update stock \(symbol): \(error)")
        }
    }
    
    private func updateDividendData(for symbol: String, using context: NSManagedObjectContext) async {
        // First fetch the stock from Core Data
        let stock: Stock?
        do {
            stock = try await CoreDataThreadingHelper.safeRead(context: context) { context in
                let request: NSFetchRequest<Stock> = Stock.fetchRequest()
                request.predicate = NSPredicate(format: "symbol == %@", symbol)
                return try context.fetch(request).first
            }
        } catch {
            print("Failed to fetch stock \(symbol) for dividend update: \(error)")
            return
        }
        
        guard let validStock = stock else { return }
        
        // Fetch dividend data using StockPriceService
        let distributionInfo = await stockPriceService.fetchDistributionInfo(symbol: symbol)
        
        // Save dividend data to Core Data using the same context
        await dividendManager.saveDividendToCore(distributionInfo: distributionInfo, for: validStock, context: context)
    }
    
    private func saveBackgroundContext(_ context: NSManagedObjectContext) async {
        // This is now handled by the CoreDataThreadingHelper.safeWrite method
        // No explicit save needed as it's handled automatically
    }
}

// Background operation for updating stock prices
class UpdateStockPricesOperation: Operation, @unchecked Sendable {
    private var updateTask: Task<Void, Never>?
    
    override init() {
        super.init()
    }
    
    override func main() {
        guard !isCancelled else { return }
        
        // Use async/await properly without blocking threads
        let semaphore = DispatchSemaphore(value: 0)
        
        updateTask = Task { @MainActor in
            let backgroundService = BackgroundUpdateService()
            await backgroundService.updateAllStockPrices()
            semaphore.signal()
        }
        
        // Wait for completion or cancellation
        while !isCancelled {
            if semaphore.wait(timeout: .now() + 1.0) == .success {
                break
            }
        }
        
        if isCancelled {
            updateTask?.cancel()
        }
    }
    
    override func cancel() {
        super.cancel()
        updateTask?.cancel()
    }
}
