import Foundation

/**
 * Modular Stock Price Service
 * 
 * This class provides a unified interface to the modular stock price architecture
 * while maintaining backward compatibility with the original StockPriceService API.
 * 
 * Architecture:
 * - Individual API services handle specific data sources
 * - Manager classes orchestrate fallback logic and caching
 * - This facade provides a clean, unified interface
 */
@MainActor
class ModularStockPriceService: ObservableObject {
    
    // MARK: - Managers
    
    private let stockPriceManager = StockPriceManager()
    private let dividendManager = DividendManager()
    private let historicalDataManager = ComprehensiveHistoricalDataManager()
    private let apiKeyManager = APIKeyManager.shared
    
    // MARK: - Initialization
    
    init() {
        // Set up default API keys on first run
        apiKeyManager.setupDefaultKeys()
    }
    
    // MARK: - Stock Price Methods (Backward Compatible)
    
    func fetchStockPrice(symbol: String) async throws -> StockQuote {
        return try await stockPriceManager.fetchStockPrice(symbol: symbol)
    }
    
    func fetchMultipleStockPrices(symbols: [String]) async -> [String: StockQuote] {
        return await stockPriceManager.fetchMultipleStockPrices(symbols: symbols)
    }
    
    // MARK: - Distribution/Dividend Methods (Backward Compatible)
    
    func fetchDistributionInfo(symbol: String) async -> DistributionInfo {
        return await dividendManager.fetchDistributionInfo(symbol: symbol)
    }
    
    func fetchMultipleDistributionInfo(symbols: [String]) async -> [String: DistributionInfo] {
        return await dividendManager.fetchMultipleDistributionInfo(symbols: symbols)
    }
    
    // MARK: - Historical Data Methods (New)
    
    func fetchHistoricalPrices(symbol: String, period: HistoricalPrice.TimePeriod) async throws -> [HistoricalPrice] {
        return try await historicalDataManager.fetchHistoricalPrices(symbol: symbol, period: period)
    }
    
    func fetchHistoricalPrices(symbol: String, startDate: Date, endDate: Date) async throws -> [HistoricalPrice] {
        return try await historicalDataManager.fetchHistoricalPrices(symbol: symbol, startDate: startDate, endDate: endDate)
    }
    
    func fetchMultipleHistoricalPrices(symbols: [String], period: HistoricalPrice.TimePeriod) async -> [String: [HistoricalPrice]] {
        return await historicalDataManager.fetchMultipleHistoricalPrices(symbols: symbols, period: period)
    }
    
    // MARK: - Cache Management (Backward Compatible)
    
    func clearCache() {
        stockPriceManager.clearCache()
        dividendManager.clearCache()
    }
    
    func isCached(symbol: String) -> Bool {
        return stockPriceManager.isCached(symbol: symbol)
    }
    
    func isDistributionCached(symbol: String) -> Bool {
        return dividendManager.isDistributionCached(symbol: symbol)
    }
    
    var cacheSize: Int {
        return stockPriceManager.cacheSize
    }
    
    var distributionCacheSize: Int {
        return dividendManager.cacheSize
    }
    
    // MARK: - Testing Support (Backward Compatible)
    
    func setCachedPrice(symbol: String, quote: StockQuote) {
        stockPriceManager.setCachedPrice(symbol: symbol, quote: quote)
    }
    
    func setCachedDistribution(symbol: String, info: DistributionInfo) {
        dividendManager.setCachedDistribution(symbol: symbol, info: info)
    }
    
    // MARK: - API Configuration (Backward Compatible)
    
    func updateAPIKey(_ key: String, for provider: APIKeyManager.APIProvider) async -> Bool {
        // Validate the key first
        let isValid = await apiKeyManager.validateAPIKey(key, for: provider)
        
        if isValid {
            return apiKeyManager.setAPIKey(key, for: provider)
        }
        
        return false
    }
    
    func hasValidAPIKey(for provider: APIKeyManager.APIProvider) -> Bool {
        return apiKeyManager.hasAPIKey(for: provider)
    }
    
    func getAPIProviderStatus() -> [(provider: APIKeyManager.APIProvider, hasKey: Bool, isConfigured: Bool)] {
        let providers: [APIKeyManager.APIProvider] = [.alphaVantage, .finnhub]
        
        return providers.map { provider in
            let hasKey = apiKeyManager.hasAPIKey(for: provider)
            return (provider: provider, hasKey: hasKey, isConfigured: hasKey)
        }
    }
    
    // MARK: - Alpha Vantage Rate Limiting (Backward Compatible)
    
    func getAlphaVantageUsage() -> (requestsUsed: Int, dailyLimit: Int, resetsAt: Date) {
        if let stockUsage = stockPriceManager.getAlphaVantageUsage() {
            return stockUsage
        }
        if let dividendUsage = dividendManager.getAlphaVantageUsage() {
            return dividendUsage
        }
        // Fallback if no Alpha Vantage services are available
        return (0, 25, Date())
    }
    
    // MARK: - New Modular Architecture Features
    
    func getStockProviderStatus() -> [(name: String, available: Bool, priority: String)] {
        return stockPriceManager.getProviderStatus()
    }
    
    func getDividendProviderStatus() -> [(name: String, available: Bool, priority: String)] {
        return dividendManager.getProviderStatus()
    }
    
    func getAvailableStockProviders() -> [StockPriceProvider] {
        return stockPriceManager.getAvailableProviders()
    }
    
    func getAvailableDividendProviders() -> [DividendProvider] {
        return dividendManager.getAvailableProviders()
    }
    
    // MARK: - System Health Check
    
    func performHealthCheck() async -> SystemHealthReport {
        let stockProviders = getStockProviderStatus()
        let dividendProviders = getDividendProviderStatus()
        let apiKeyStatus = getAPIProviderStatus()
        
        // Test a simple stock quote to verify system functionality
        var systemWorking = false
        do {
            _ = try await fetchStockPrice(symbol: "AAPL")
            systemWorking = true
        } catch {
            systemWorking = false
        }
        
        return SystemHealthReport(
            systemWorking: systemWorking,
            stockProviders: stockProviders,
            dividendProviders: dividendProviders,
            apiKeyStatus: apiKeyStatus,
            stockCacheSize: stockPriceManager.cacheSize,
            dividendCacheSize: dividendManager.cacheSize,
            timestamp: Date()
        )
    }
    
    // MARK: - Historical Data Management
    
    func clearHistoricalCache() async {
        await historicalDataManager.clearAllCache()
    }
    
    func getHistoricalDataStats() async -> ComprehensiveHealthReport {
        return await historicalDataManager.performHealthCheck()
    }
    
    func cleanupOldHistoricalData(retentionDays: Int = 365) async {
        await historicalDataManager.cleanupOldData(retentionDays: retentionDays)
    }
}

// MARK: - System Health Report

struct SystemHealthReport {
    let systemWorking: Bool
    let stockProviders: [(name: String, available: Bool, priority: String)]
    let dividendProviders: [(name: String, available: Bool, priority: String)]
    let apiKeyStatus: [(provider: APIKeyManager.APIProvider, hasKey: Bool, isConfigured: Bool)]
    let stockCacheSize: Int
    let dividendCacheSize: Int
    let timestamp: Date
    
    var summary: String {
        let workingProviders = stockProviders.filter { $0.available }.count
        let totalProviders = stockProviders.count
        return "System: \(systemWorking ? "✓" : "✗") | Providers: \(workingProviders)/\(totalProviders) | Cache: \(stockCacheSize) stocks, \(dividendCacheSize) dividends"
    }
}