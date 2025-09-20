import Foundation

/**
 * Historical Stock Data Manager
 * 
 * Comprehensive manager that coordinates multiple historical data providers,
 * implements fallback mechanisms, caching, retry logic, and cost optimization.
 * Follows the established project patterns and integrates seamlessly.
 */
actor HistoricalStockDataManager {
    
    // MARK: - Properties
    
    private var isLoading = false
    private var lastError: HistoricalDataError?
    
    private let providers: [HistoricalStockDataProvider]
    private let cache: HistoricalDataCacheManager
    private let configuration: HistoricalDataServiceConfiguration
    private let apiKeyManager = APIKeyManager.shared
    
    // Statistics tracking
    private var requestStats: [String: ProviderStats] = [:]
    
    // MARK: - Initialization
    
    init(configuration: HistoricalDataServiceConfiguration = .default) async {
        self.configuration = configuration
        
        // Initialize providers in priority order
        self.providers = [
            YahooFinanceHistoricalService(configuration: configuration),
            EODHDHistoricalService(configuration: configuration),
            FinnhubHistoricalService(configuration: configuration)
        ].sorted { $0.priority.rawValue < $1.priority.rawValue }
        
        // Initialize cache manager
        self.cache = HistoricalDataCacheManager(configuration: configuration)
        
        // Initialize statistics
        initializeProviderStats()
        
        if configuration.enableLogging {
            print("[HistoricalDataManager] Initialized with \(providers.count) providers")
        }
    }
    
    // MARK: - Public API
    
    /// Fetch historical prices with automatic fallback and caching
    func fetchHistoricalPrices(
        symbol: String,
        startDate: Date,
        endDate: Date
    ) async throws -> [HistoricalPrice] {
        
        let cleanSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        guard !cleanSymbol.isEmpty else {
            throw HistoricalDataError.invalidSymbol("Empty symbol")
        }
        
        guard startDate <= endDate else {
            throw HistoricalDataError.invalidDateRange("Start date must be before end date")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Check cache first
        if let cachedData = await cache.get(symbol: cleanSymbol, startDate: startDate, endDate: endDate) {
            if configuration.enableLogging && configuration.logLevel == .debug {
                print("[HistoricalDataManager] Cache hit for \(cleanSymbol): \(cachedData.count) points")
            }
            return cachedData
        }
        
        // Try providers with fallback
        var lastError: HistoricalDataError?
        
        for provider in getAvailableProviders() {
            do {
                let prices = try await fetchFromProvider(
                    provider: provider,
                    symbol: cleanSymbol,
                    startDate: startDate,
                    endDate: endDate
                )
                
                // Cache successful results
                await cache.set(symbol: cleanSymbol, prices: prices, startDate: startDate, endDate: endDate)
                
                // Update success statistics
                await updateProviderStats(provider.providerName, success: true, responseTime: 0)
                
                if configuration.enableLogging {
                    print("[HistoricalDataManager] Successfully fetched \(prices.count) prices for \(cleanSymbol) from \(provider.providerName)")
                }
                
                lastError = nil
                return prices
                
            } catch let error as HistoricalDataError {
                lastError = error
                await updateProviderStats(provider.providerName, success: false, responseTime: 0)
                
                if configuration.enableLogging {
                    print("[HistoricalDataManager] Provider \(provider.providerName) failed: \(error.localizedDescription)")
                }
                
                // Check if we should retry or skip this provider
                switch error.recoveryStrategy {
                case .retry(let delay):
                    if await shouldRetryProvider(provider.providerName) {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        // Retry will happen on next loop iteration
                    }
                case .fallbackProvider:
                    continue // Move to next provider
                case .useCache:
                    // Try to get any cached data, even if stale
                    if let staleData = await cache.getStale(symbol: cleanSymbol) {
                        if configuration.enableLogging {
                            print("[HistoricalDataManager] Using stale cache data for \(cleanSymbol)")
                        }
                        return staleData
                    }
                default:
                    continue
                }
            } catch {
                lastError = HistoricalDataError.networkError(error)
                await updateProviderStats(provider.providerName, success: false, responseTime: 0)
                continue
            }
        }
        
        // All providers failed
        let finalError = lastError ?? HistoricalDataError.providerUnavailable("All providers")
        lastError = finalError
        throw finalError
    }
    
    /// Fetch historical prices for a specific time period
    func fetchHistoricalPrices(
        symbol: String,
        period: HistoricalPrice.TimePeriod
    ) async throws -> [HistoricalPrice] {
        
        return try await fetchHistoricalPrices(
            symbol: symbol,
            startDate: period.startDate,
            endDate: period.endDate
        )
    }
    
    /// Fetch multiple symbols concurrently
    func fetchMultipleHistoricalPrices(
        symbols: [String],
        period: HistoricalPrice.TimePeriod
    ) async -> [String: [HistoricalPrice]] {
        
        return await withTaskGroup(of: (String, [HistoricalPrice]?).self) { group in
            for symbol in symbols {
                group.addTask {
                    do {
                        let prices = try await self.fetchHistoricalPrices(symbol: symbol, period: period)
                        return (symbol, prices)
                    } catch {
                        if await self.shouldLog() {
                            print("[HistoricalDataManager] Failed to fetch \(symbol): \(error)")
                        }
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
    
    // MARK: - Provider Management
    
    private func getAvailableProviders() -> [HistoricalStockDataProvider] {
        return providers.filter { provider in
            provider.isAvailable && !isProviderBlocked(provider.providerName)
        }
    }
    
    private func fetchFromProvider(
        provider: HistoricalStockDataProvider,
        symbol: String,
        startDate: Date,
        endDate: Date
    ) async throws -> [HistoricalPrice] {
        
        let startTime = Date()
        
        // Implement retry logic with exponential backoff
        var attempt = 0
        let maxRetries = configuration.maxRetries
        
        while attempt < maxRetries {
            do {
                let prices = try await provider.fetchHistoricalPrices(
                    symbol: symbol,
                    startDate: startDate,
                    endDate: endDate
                )
                
                let responseTime = Date().timeIntervalSince(startTime)
                await updateProviderStats(provider.providerName, success: true, responseTime: responseTime)
                
                return prices
                
            } catch let error as HistoricalDataError {
                attempt += 1
                
                // Check if error is retryable
                switch error {
                case .rateLimitExceeded(let retryAfter):
                    if attempt < maxRetries {
                        let delay = retryAfter ?? (configuration.retryDelay * Double(attempt))
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                case .networkError:
                    if attempt < maxRetries {
                        let delay = configuration.retryDelay * Double(attempt) // Exponential backoff
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                default:
                    // Non-retryable errors
                    throw error
                }
                
                if attempt >= maxRetries {
                    throw error
                }
            }
        }
        
        throw HistoricalDataError.providerUnavailable(provider.providerName)
    }
    
    // MARK: - Statistics and Health Monitoring
    
    private func initializeProviderStats() {
        for provider in providers {
            requestStats[provider.providerName] = ProviderStats()
        }
    }
    
    private func updateProviderStats(_ providerName: String, success: Bool, responseTime: TimeInterval) async {
        var stats = requestStats[providerName] ?? ProviderStats()
        stats.totalRequests += 1
        
        if success {
            stats.successfulRequests += 1
            stats.totalResponseTime += responseTime
            stats.lastSuccessTime = Date()
        } else {
            stats.failedRequests += 1
            stats.lastFailureTime = Date()
        }
        
        requestStats[providerName] = stats
    }
    
    private func shouldRetryProvider(_ providerName: String) async -> Bool {
        guard let stats = requestStats[providerName] else {
            return true
        }
        
        // Don't retry if provider has high failure rate recently
        let recentFailureRate = stats.recentFailureRate
        return recentFailureRate < 0.8 // 80% failure threshold
    }
    
    private func isProviderBlocked(_ providerName: String) -> Bool {
        guard let stats = requestStats[providerName] else { return false }
        
        // Block provider if it has consistently failed recently
        return stats.recentFailureRate > 0.9 && stats.totalRequests > 5
    }
    
    // MARK: - Cache Management
    
    func clearCache() async {
        await cache.clear(symbol: nil)
        
        if configuration.enableLogging {
            print("[HistoricalDataManager] Cache cleared")
        }
    }
    
    func clearCache(for symbol: String) async {
        await cache.clear(symbol: symbol)
    }
    
    func getCacheStats() async -> CacheStats {
        return await cache.getStats()
    }
    
    // MARK: - Health Check
    
    func performHealthCheck() async -> HistoricalDataHealthReport {
        var providerHealth: [String: ProviderHealth] = [:]
        
        // Test each provider
        for provider in providers {
            providerHealth[provider.providerName] = await provider.healthCheck()
        }
        
        let cacheStats = await cache.getStats()
        let overallHealth = providerHealth.values.contains { $0.isHealthy }
        
        return HistoricalDataHealthReport(
            overallHealthy: overallHealth,
            providerHealth: providerHealth,
            cacheStats: cacheStats,
            timestamp: Date()
        )
    }
    
    // MARK: - Provider Information
    
    func getProviderStatus() async -> [(name: String, available: Bool, priority: String, stats: ProviderStats?)] {
        return providers.map { provider in
            (
                name: provider.providerName,
                available: provider.isAvailable,
                priority: provider.priority.description,
                stats: requestStats[provider.providerName]
            )
        }
    }
    
    func getUsageStats() async -> [String: ProviderUsageStats] {
        var stats: [String: ProviderUsageStats] = [:]
        
        for provider in providers {
            stats[provider.providerName] = provider.getUsageStats()
        }
        
        return stats
    }
    
    // MARK: - Cost Optimization
    
    func getEstimatedCost(symbols: [String], period: HistoricalPrice.TimePeriod) async -> Decimal {
        // Calculate estimated cost based on provider usage patterns and costs
        var totalCost: Decimal = 0
        
        for provider in providers {
            if provider.isAvailable {
                let requestsNeeded = Decimal(symbols.count)
                totalCost += requestsNeeded * provider.costPerRequest
                break // Only count the primary provider that would be used
            }
        }
        
        return totalCost
    }
    
    // MARK: - Helper Methods
    
    private func shouldLog() async -> Bool {
        return configuration.enableLogging
    }
    
    func getLoadingState() async -> Bool {
        return isLoading
    }
    
    func getLastError() async -> HistoricalDataError? {
        return lastError
    }
}

// MARK: - Supporting Data Structures

struct ProviderStats: Sendable {
    var totalRequests: Int = 0
    var successfulRequests: Int = 0
    var failedRequests: Int = 0
    var totalResponseTime: TimeInterval = 0
    var lastSuccessTime: Date?
    var lastFailureTime: Date?
    
    var successRate: Double {
        guard totalRequests > 0 else { return 1.0 }
        return Double(successfulRequests) / Double(totalRequests)
    }
    
    var averageResponseTime: TimeInterval {
        guard successfulRequests > 0 else { return 0 }
        return totalResponseTime / Double(successfulRequests)
    }
    
    var recentFailureRate: Double {
        // Simple implementation - could be enhanced with time-based windows
        guard totalRequests > 0 else { return 0 }
        
        // Give more weight to recent failures
        let recentWeight = min(10, totalRequests)
        let recentFailures = min(failedRequests, recentWeight)
        return Double(recentFailures) / Double(recentWeight)
    }
}

struct CacheStats: Sendable {
    let entriesCount: Int
    let totalSizeBytes: Int64
    let hitRate: Double
    let oldestEntry: Date?
    let newestEntry: Date?
}

struct HistoricalDataHealthReport: Sendable {
    let overallHealthy: Bool
    let providerHealth: [String: ProviderHealth]
    let cacheStats: CacheStats
    let timestamp: Date
    
    var summary: String {
        let healthyProviders = providerHealth.values.filter { $0.isHealthy }.count
        let totalProviders = providerHealth.count
        return "Historical Data System: \(overallHealthy ? "✓" : "✗") | Providers: \(healthyProviders)/\(totalProviders) | Cache: \(cacheStats.entriesCount) entries"
    }
}