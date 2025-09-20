import Foundation
import CoreData
import os.log

/**
 * Historical Data Persistence Manager
 * 
 * Handles Core Data persistence for historical stock price data,
 * integrating seamlessly with existing DataManager patterns and
 * providing thread-safe operations with the PriceHistory entity.
 */
class HistoricalDataPersistenceManager {
    
    // MARK: - Properties
    
    private let dataManager = DataManager.shared
    private let configuration: HistoricalDataServiceConfiguration
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HistoricalData", category: "Persistence")
    
    // MARK: - Initialization
    
    init(configuration: HistoricalDataServiceConfiguration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Public API
    
    /// Save historical prices to Core Data
    func saveHistoricalPrices(_ prices: [HistoricalPrice], for symbol: String) async throws {
        guard !prices.isEmpty else { return }
        
        try await withCheckedThrowingContinuation { continuation in
            dataManager.performInBackground({ context in
                // Find or create the Stock entity
                let stock = try self.findOrCreateStock(symbol: symbol, in: context)
                
                // Remove existing price history for the same date range to avoid duplicates
                let dateRange = self.getDateRange(from: prices)
                try self.removePriceHistory(for: stock, in: dateRange, context: context)
                
                // Create new PriceHistory entities
                var createdCount = 0
                for price in prices {
                    let priceHistory = PriceHistory(context: context)
                    self.populatePriceHistory(priceHistory, from: price)
                    priceHistory.stock = stock
                    createdCount += 1
                }
                
                try context.save()
                
                if self.configuration.enableLogging {
                    self.logger.info("Saved \(createdCount) historical prices for \(symbol)")
                }
                
                return createdCount
                
            }) { result in
                switch result {
                case .success(let count):
                    if self.configuration.enableLogging && self.configuration.logLevel == .debug {
                        self.logger.debug("Successfully persisted \(count) prices for \(symbol)")
                    }
                    continuation.resume()
                case .failure(let error):
                    self.logger.error("Failed to save historical prices for \(symbol): \(error.localizedDescription)")
                    continuation.resume(throwing: HistoricalDataError.persistenceError(error.localizedDescription))
                }
            }
        }
    }
    
    /// Fetch historical prices from Core Data
    func fetchHistoricalPrices(
        for symbol: String,
        startDate: Date,
        endDate: Date
    ) async throws -> [HistoricalPrice] {
        
        return try await withCheckedThrowingContinuation { continuation in
            dataManager.performInBackground({ context in
                let stock = try self.findStock(symbol: symbol, in: context)
                guard let stock = stock else {
                    return [] // No stock found
                }
                
                let fetchRequest: NSFetchRequest<PriceHistory> = PriceHistory.fetchRequest()
                fetchRequest.predicate = NSPredicate(
                    format: "stock == %@ AND date >= %@ AND date <= %@",
                    stock, startDate as NSDate, endDate as NSDate
                )
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
                
                let priceHistoryEntities = try context.fetch(fetchRequest)
                
                let historicalPrices = priceHistoryEntities.compactMap { entity in
                    HistoricalPrice(from: entity, symbol: symbol, dataSource: "CoreData")
                }
                
                if self.configuration.enableLogging && self.configuration.logLevel == .debug {
                    self.logger.debug("Fetched \(historicalPrices.count) historical prices for \(symbol) from Core Data")
                }
                
                return historicalPrices
                
            }) { result in
                switch result {
                case .success(let prices):
                    if let historicalPrices = prices as? [HistoricalPrice] {
                        continuation.resume(returning: historicalPrices)
                    } else {
                        continuation.resume(throwing: HistoricalDataError.persistenceError("Invalid data type returned from database"))
                    }
                case .failure(let error):
                    self.logger.error("Failed to fetch historical prices for \(symbol): \(error.localizedDescription)")
                    continuation.resume(throwing: HistoricalDataError.persistenceError(error.localizedDescription))
                }
            }
        }
    }
    
    /// Get the latest available price for a symbol from Core Data
    func fetchLatestPrice(for symbol: String) async throws -> HistoricalPrice? {
        return try await withCheckedThrowingContinuation { continuation in
            dataManager.performInBackground({ context in
                let stock = try self.findStock(symbol: symbol, in: context)
                guard let stock = stock else {
                    return nil as HistoricalPrice?
                }
                
                let fetchRequest: NSFetchRequest<PriceHistory> = PriceHistory.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "stock == %@", stock)
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
                fetchRequest.fetchLimit = 1
                
                let priceHistoryEntities = try context.fetch(fetchRequest)
                
                if let latestEntity = priceHistoryEntities.first {
                    return HistoricalPrice(from: latestEntity, symbol: symbol, dataSource: "CoreData")
                }
                
                return nil as HistoricalPrice?
                
            }) { result in
                switch result {
                case .success(let price):
                    continuation.resume(returning: price)
                case .failure(let error):
                    self.logger.error("Failed to fetch latest price for \(symbol): \(error.localizedDescription)")
                    continuation.resume(throwing: HistoricalDataError.persistenceError(error.localizedDescription))
                }
            }
        }
    }
    
    /// Check if historical data exists for a symbol and date range
    func hasHistoricalData(
        for symbol: String,
        startDate: Date,
        endDate: Date
    ) async -> Bool {
        
        do {
            return try await withCheckedThrowingContinuation { continuation in
                dataManager.performInBackground({ context in
                    let stock = try self.findStock(symbol: symbol, in: context)
                    guard let stock = stock else {
                        return false
                    }
                    
                    let fetchRequest: NSFetchRequest<PriceHistory> = PriceHistory.fetchRequest()
                    fetchRequest.predicate = NSPredicate(
                        format: "stock == %@ AND date >= %@ AND date <= %@",
                        stock, startDate as NSDate, endDate as NSDate
                    )
                    fetchRequest.fetchLimit = 1
                    
                    let count = try context.count(for: fetchRequest)
                    return count > 0
                    
                }) { result in
                    switch result {
                    case .success(let hasData):
                        continuation.resume(returning: hasData)
                    case .failure:
                        continuation.resume(returning: false)
                    }
                }
            }
        } catch {
            return false
        }
    }
    
    /// Get available date ranges for a symbol
    func getAvailableDateRanges(for symbol: String) async -> [(startDate: Date, endDate: Date)] {
        do {
            return try await withCheckedThrowingContinuation { continuation in
                dataManager.performInBackground({ context in
                    let stock = try self.findStock(symbol: symbol, in: context)
                    guard let stock = stock else {
                        return []
                    }
                    
                    let fetchRequest: NSFetchRequest<PriceHistory> = PriceHistory.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "stock == %@", stock)
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
                    
                    let priceHistoryEntities = try context.fetch(fetchRequest)
                    
                    if priceHistoryEntities.isEmpty {
                        return []
                    }
                    
                    // For now, return single range from earliest to latest
                    // This could be enhanced to detect gaps and return multiple ranges
                    let startDate = priceHistoryEntities.first?.date ?? Date()
                    let endDate = priceHistoryEntities.last?.date ?? Date()
                    
                    return [(startDate: startDate, endDate: endDate)]
                    
                }) { result in
                    switch result {
                    case .success(let ranges):
                        if let dateRanges = ranges as? [(startDate: Date, endDate: Date)] {
                            continuation.resume(returning: dateRanges)
                        } else {
                            continuation.resume(returning: [])
                        }
                    case .failure:
                        continuation.resume(returning: [])
                    }
                }
            }
        } catch {
            return []
        }
    }
    
    /// Delete historical data for a symbol and optional date range
    func deleteHistoricalData(
        for symbol: String,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws {
        
        try await withCheckedThrowingContinuation { continuation in
            dataManager.performInBackground({ context in
                let stock = try self.findStock(symbol: symbol, in: context)
                guard let stock = stock else {
                    return 0 // No stock found, nothing to delete
                }
                
                let fetchRequest: NSFetchRequest<PriceHistory> = PriceHistory.fetchRequest()
                
                if let startDate = startDate, let endDate = endDate {
                    fetchRequest.predicate = NSPredicate(
                        format: "stock == %@ AND date >= %@ AND date <= %@",
                        stock, startDate as NSDate, endDate as NSDate
                    )
                } else {
                    fetchRequest.predicate = NSPredicate(format: "stock == %@", stock)
                }
                
                // Use batch delete for better performance
                try self.dataManager.batchDelete(fetchRequest: fetchRequest, context: context)
                
                if self.configuration.enableLogging {
                    self.logger.info("Deleted historical data for \(symbol)")
                }
                
                return 1
                
            }) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    self.logger.error("Failed to delete historical data for \(symbol): \(error.localizedDescription)")
                    continuation.resume(throwing: HistoricalDataError.persistenceError(error.localizedDescription))
                }
            }
        }
    }
    
    /// Cleanup old historical data beyond retention period
    func cleanupOldData(retentionDays: Int = 365) async throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        
        try await withCheckedThrowingContinuation { continuation in
            dataManager.performInBackground({ context in
                let fetchRequest: NSFetchRequest<PriceHistory> = PriceHistory.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "date < %@", cutoffDate as NSDate)
                
                let count = try context.count(for: fetchRequest)
                
                if count > 0 {
                    try self.dataManager.batchDelete(fetchRequest: fetchRequest, context: context)
                    
                    if self.configuration.enableLogging {
                        self.logger.info("Cleaned up \(count) old historical price records")
                    }
                }
                
                return count
                
            }) { result in
                switch result {
                case .success(let deletedCount):
                    if self.configuration.enableLogging && deletedCount > 0 {
                        self.logger.info("Successfully cleaned up \(deletedCount) old records")
                    }
                    continuation.resume()
                case .failure(let error):
                    self.logger.error("Failed to cleanup old data: \(error.localizedDescription)")
                    continuation.resume(throwing: HistoricalDataError.persistenceError(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - Statistics
    
    func getStorageStats() async -> HistoricalDataStorageStats {
        do {
            return try await withCheckedThrowingContinuation { continuation in
                dataManager.performInBackground({ context in
                    let priceHistoryRequest: NSFetchRequest<PriceHistory> = PriceHistory.fetchRequest()
                    let totalRecords = try context.count(for: priceHistoryRequest)
                    
                    let stockRequest: NSFetchRequest<Stock> = Stock.fetchRequest()
                    stockRequest.predicate = NSPredicate(format: "priceHistory.@count > 0")
                    let symbolsWithHistory = try context.count(for: stockRequest)
                    
                    // Get oldest and newest records
                    priceHistoryRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
                    priceHistoryRequest.fetchLimit = 1
                    let oldestRecord = try context.fetch(priceHistoryRequest).first?.date
                    
                    priceHistoryRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
                    let newestRecord = try context.fetch(priceHistoryRequest).first?.date
                    
                    return HistoricalDataStorageStats(
                        totalRecords: totalRecords,
                        symbolsWithHistory: symbolsWithHistory,
                        oldestRecord: oldestRecord,
                        newestRecord: newestRecord,
                        estimatedSizeBytes: Int64(totalRecords * 200) // Rough estimate
                    )
                    
                }) { result in
                    switch result {
                    case .success(let stats):
                        continuation.resume(returning: stats)
                    case .failure:
                        let emptyStats = HistoricalDataStorageStats(
                            totalRecords: 0,
                            symbolsWithHistory: 0,
                            oldestRecord: nil,
                            newestRecord: nil,
                            estimatedSizeBytes: 0
                        )
                        continuation.resume(returning: emptyStats)
                    }
                }
            }
        } catch {
            return HistoricalDataStorageStats(
                totalRecords: 0,
                symbolsWithHistory: 0,
                oldestRecord: nil,
                newestRecord: nil,
                estimatedSizeBytes: 0
            )
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func findOrCreateStock(symbol: String, in context: NSManagedObjectContext) throws -> Stock {
        if let existingStock = try findStock(symbol: symbol, in: context) {
            return existingStock
        }
        
        // Create new stock
        let stock = Stock(context: context)
        stock.symbol = symbol.uppercased()
        stock.stockID = UUID()
        stock.currentPrice = NSDecimalNumber.zero
        stock.lastUpdated = Date()
        
        if configuration.enableLogging && configuration.logLevel == .debug {
            logger.debug("Created new stock entity for symbol: \(symbol)")
        }
        
        return stock
    }
    
    private func findStock(symbol: String, in context: NSManagedObjectContext) throws -> Stock? {
        let fetchRequest: NSFetchRequest<Stock> = Stock.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "symbol == %@", symbol.uppercased())
        fetchRequest.fetchLimit = 1
        
        return try context.fetch(fetchRequest).first
    }
    
    private func populatePriceHistory(_ priceHistory: PriceHistory, from historicalPrice: HistoricalPrice) {
        priceHistory.priceHistoryID = UUID()
        priceHistory.date = historicalPrice.date
        priceHistory.openPrice = historicalPrice.openPrice as NSDecimalNumber
        priceHistory.highPrice = historicalPrice.highPrice as NSDecimalNumber
        priceHistory.lowPrice = historicalPrice.lowPrice as NSDecimalNumber
        priceHistory.closePrice = historicalPrice.closePrice as NSDecimalNumber
        priceHistory.volume = historicalPrice.volume
    }
    
    private func getDateRange(from prices: [HistoricalPrice]) -> (start: Date, end: Date) {
        let sortedPrices = prices.sorted { $0.date < $1.date }
        return (
            start: sortedPrices.first?.date ?? Date(),
            end: sortedPrices.last?.date ?? Date()
        )
    }
    
    private func removePriceHistory(
        for stock: Stock,
        in dateRange: (start: Date, end: Date),
        context: NSManagedObjectContext
    ) throws {
        let fetchRequest: NSFetchRequest<PriceHistory> = PriceHistory.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "stock == %@ AND date >= %@ AND date <= %@",
            stock, dateRange.start as NSDate, dateRange.end as NSDate
        )
        
        let existingEntities = try context.fetch(fetchRequest)
        for entity in existingEntities {
            context.delete(entity)
        }
        
        if !existingEntities.isEmpty && configuration.enableLogging && configuration.logLevel == .debug {
            logger.debug("Removed \(existingEntities.count) existing price history records for date range")
        }
    }
}

// MARK: - Storage Statistics

struct HistoricalDataStorageStats: Sendable {
    let totalRecords: Int
    let symbolsWithHistory: Int
    let oldestRecord: Date?
    let newestRecord: Date?
    let estimatedSizeBytes: Int64
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: estimatedSizeBytes)
    }
    
    var dateRangeDescription: String {
        guard let oldest = oldestRecord, let newest = newestRecord else {
            return "No data"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: oldest)) - \(formatter.string(from: newest))"
    }
}