import Foundation

/**
 * Historical Data Service Actor
 * 
 * Thread-safe actor that handles all historical stock data operations including:
 * - Network requests to multiple API providers
 * - Cache management
 * - Core Data persistence
 * - Data validation and processing
 * 
 * This actor ensures all data operations are thread-safe and properly isolated,
 * complying with Swift 6.0 strict concurrency requirements.
 */
actor HistoricalDataService {
    
    // MARK: - Core Components
    
    private let apiManager: HistoricalStockDataManager
    private let persistenceManager: HistoricalDataPersistenceManager
    private let cache: HistoricalDataCacheManager
    private let configuration: HistoricalDataServiceConfiguration
    
    // MARK: - Internal State
    
    private var lastError: HistoricalDataError?
    private var isProcessing: Bool = false
    private var currentRequests: Set<String> = []
    
    // MARK: - Statistics (Actor-safe)
    
    private var _cacheStats: CacheStats?
    private var _storageStats: HistoricalDataStorageStats?
    
    // MARK: - Initialization
    
    init(configuration: HistoricalDataServiceConfiguration = .default) async {
        self.configuration = configuration
        self.apiManager = await HistoricalStockDataManager(configuration: configuration)
        self.persistenceManager = HistoricalDataPersistenceManager(configuration: configuration)
        self.cache = HistoricalDataCacheManager(configuration: configuration)
        
        if configuration.enableLogging {
            print("[HistoricalDataService] Initialized with configuration: \(configuration.logLevel.rawValue)")
        }
    }
    
    // MARK: - Public Data Fetching API
    
    /// Fetch historical prices with full fallback chain: Cache -> Core Data -> API
    func fetchHistoricalPrices(
        symbol: String,
        period: HistoricalPrice.TimePeriod,
        forceRefresh: Bool = false
    ) async throws -> [HistoricalPrice] {
        
        return try await fetchHistoricalPrices(
            symbol: symbol,
            startDate: period.startDate,
            endDate: period.endDate,
            forceRefresh: forceRefresh
        )
    }
    
    /// Fetch historical prices with custom date range
    func fetchHistoricalPrices(
        symbol: String,
        startDate: Date,
        endDate: Date,
        forceRefresh: Bool = false
    ) async throws -> [HistoricalPrice] {
        
        let cleanSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Prevent duplicate concurrent requests for the same symbol
        guard !currentRequests.contains(cleanSymbol) else {
            throw HistoricalDataError.dataQualityError("Request already in progress for \(cleanSymbol)")
        }
        
        currentRequests.insert(cleanSymbol)
        defer { currentRequests.remove(cleanSymbol) }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // Step 1: Check memory cache (unless forcing refresh)
            if !forceRefresh {
                if let cachedData = await cache.get(symbol: cleanSymbol, startDate: startDate, endDate: endDate) {
                    if configuration.enableLogging {
                        print("[HistoricalDataService] Cache hit for \(cleanSymbol)")
                    }
                    return cachedData
                }
            }
            
            // Step 2: Check Core Data persistence (unless forcing refresh)  
            if !forceRefresh {
                let persistedData = try await persistenceManager.fetchHistoricalPrices(
                    for: cleanSymbol,
                    startDate: startDate,
                    endDate: endDate
                )
                
                if !persistedData.isEmpty {
                    // Cache the persisted data for faster future access
                    await cache.set(symbol: cleanSymbol, prices: persistedData, startDate: startDate, endDate: endDate)
                    
                    if configuration.enableLogging {
                        print("[HistoricalDataService] Core Data hit for \(cleanSymbol): \(persistedData.count) records")
                    }
                    return persistedData
                }
            }
            
            // Step 3: Fetch from API with fallback mechanisms
            let apiData = try await apiManager.fetchHistoricalPrices(
                symbol: cleanSymbol,
                startDate: startDate,
                endDate: endDate
            )
            
            // Step 4: Persist to Core Data for future use
            try await persistenceManager.saveHistoricalPrices(apiData, for: cleanSymbol)
            
            // Step 5: Update cache
            await cache.set(symbol: cleanSymbol, prices: apiData, startDate: startDate, endDate: endDate)
            
            if configuration.enableLogging {
                print("[HistoricalDataService] Successfully fetched and saved \(apiData.count) prices for \(cleanSymbol)")
            }
            
            return apiData
            
        } catch {
            // Step 6: Last resort - try to get stale cached data
            if let staleData = await cache.getStale(symbol: cleanSymbol) {
                if configuration.enableLogging {
                    print("[HistoricalDataService] Using stale cache data for \(cleanSymbol)")
                }
                return staleData
            }
            
            lastError = error as? HistoricalDataError ?? HistoricalDataError.networkError(error)
            throw lastError!
        }
    }
    
    /// Fetch multiple symbols with controlled concurrency
    func fetchMultipleHistoricalPrices(
        symbols: [String],
        period: HistoricalPrice.TimePeriod,
        forceRefresh: Bool = false
    ) async -> [String: [HistoricalPrice]] {
        
        // Use TaskGroup with controlled concurrency to avoid overwhelming APIs
        let semaphore = AsyncSemaphore(value: 3) // Max 3 concurrent requests
        
        return await withTaskGroup(of: (String, [HistoricalPrice]?).self) { group in
            for symbol in symbols {
                group.addTask {
                    await semaphore.wait()
                    
                    do {
                        let prices = try await self.fetchHistoricalPrices(
                            symbol: symbol,
                            period: period,
                            forceRefresh: forceRefresh
                        )
                        await semaphore.signal()
                        return (symbol, prices)
                    } catch {
                        if self.configuration.enableLogging {
                            print("[HistoricalDataService] Failed to fetch \(symbol): \(error)")
                        }
                        await semaphore.signal()
                        return (symbol, nil)
                    }
                }
            }
            
            var results: [String: [HistoricalPrice]] = [:]
            for await (symbol, prices) in group {
                if let prices = prices {
                    results[symbol] = prices
                }
            }
            
            return results
        }
    }
    
    /// Get latest price for a symbol
    func fetchLatestPrice(for symbol: String) async throws -> HistoricalPrice {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        
        let prices = try await fetchHistoricalPrices(
            symbol: symbol,
            startDate: startDate,
            endDate: endDate
        )
        
        guard let latestPrice = prices.max(by: { $0.date < $1.date }) else {
            throw HistoricalDataError.noData
        }
        
        return latestPrice
    }
    
    // MARK: - Data Management
    
    /// Clear all cached data
    func clearAllCache() async {
        await cache.clear(symbol: nil)
        await refreshStats()
        
        if configuration.enableLogging {
            print("[HistoricalDataService] All cache cleared")
        }
    }
    
    /// Clear data for specific symbol
    func clearData(for symbol: String) async {
        await cache.clear(symbol: symbol)
        
        do {
            try await persistenceManager.deleteHistoricalData(for: symbol)
            await refreshStats()
            
            if configuration.enableLogging {
                print("[HistoricalDataService] Cleared all data for \(symbol)")
            }
        } catch {
            lastError = HistoricalDataError.persistenceError(error.localizedDescription)
            if configuration.enableLogging {
                print("[HistoricalDataService] Error clearing data for \(symbol): \(error)")
            }
        }
    }
    
    /// Cleanup old data beyond retention period
    func cleanupOldData(retentionDays: Int = 365) async {
        do {
            try await persistenceManager.cleanupOldData(retentionDays: retentionDays)
            await cache.clearExpired()
            await refreshStats()
            
            if configuration.enableLogging {
                print("[HistoricalDataService] Cleaned up data older than \(retentionDays) days")
            }
        } catch {
            lastError = HistoricalDataError.persistenceError(error.localizedDescription)
            if configuration.enableLogging {
                print("[HistoricalDataService] Error during cleanup: \(error)")
            }
        }
    }
    
    // MARK: - Statistics and Health
    
    func refreshStats() async {
        async let cacheStatsTask = cache.getStats()
        async let storageStatsTask = persistenceManager.getStorageStats()
        
        let (newCacheStats, newStorageStats) = await (cacheStatsTask, storageStatsTask)
        
        _cacheStats = newCacheStats
        _storageStats = newStorageStats
    }
    
    func getCacheStats() async -> CacheStats? {
        return _cacheStats
    }
    
    func getStorageStats() async -> HistoricalDataStorageStats? {
        return _storageStats
    }
    
    func getLastError() async -> HistoricalDataError? {
        return lastError
    }
    
    func isCurrentlyProcessing() async -> Bool {
        return isProcessing
    }
    
    func performHealthCheck() async -> ComprehensiveHealthReport {
        async let apiHealthTask = apiManager.performHealthCheck()
        async let cacheStatsTask = cache.getStats()
        async let storageStatsTask = persistenceManager.getStorageStats()
        
        let (apiHealthReport, cacheStats, storageStats) = await (apiHealthTask, cacheStatsTask, storageStatsTask)
        
        let overallHealth = apiHealthReport.overallHealthy
        
        return ComprehensiveHealthReport(
            overallHealthy: overallHealth,
            apiHealth: apiHealthReport,
            cacheStats: cacheStats,
            storageStats: storageStats,
            timestamp: Date()
        )
    }
    
    // MARK: - Provider Information
    
    func getProviderStatus() async -> [(name: String, available: Bool, priority: String, stats: Any?)] {
        return await apiManager.getProviderStatus()
    }
    
    func getUsageStats() async -> [String: ProviderUsageStats] {
        return await apiManager.getUsageStats()
    }
    
    func getEstimatedCost(symbols: [String], period: HistoricalPrice.TimePeriod) async -> Decimal {
        return await apiManager.getEstimatedCost(symbols: symbols, period: period)
    }
}
