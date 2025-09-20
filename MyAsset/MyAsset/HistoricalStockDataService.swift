import Foundation

/**
 * Historical Stock Data Service Protocol
 * 
 * Unified protocol for historical stock price data providers,
 * following the existing architecture patterns while providing
 * historical-specific functionality.
 */
protocol HistoricalStockDataService {
    var providerName: String { get }
    var isAvailable: Bool { get }
    var supportedTimePeriods: [HistoricalPrice.TimePeriod] { get }
    var dailyRequestLimit: Int { get }
    var costPerRequest: Decimal { get }
    
    /// Fetch historical prices for a symbol within a date range
    func fetchHistoricalPrices(
        symbol: String,
        startDate: Date,
        endDate: Date
    ) async throws -> [HistoricalPrice]
    
    /// Fetch historical prices for a predefined time period
    func fetchHistoricalPrices(
        symbol: String,
        period: HistoricalPrice.TimePeriod
    ) async throws -> [HistoricalPrice]
    
    /// Get the latest available price for a symbol
    func fetchLatestPrice(symbol: String) async throws -> HistoricalPrice
    
    /// Check if data is available for a symbol and date range
    func isDataAvailable(
        symbol: String,
        startDate: Date,
        endDate: Date
    ) async -> Bool
}

// MARK: - Historical Stock Data Provider

/**
 * Enhanced provider protocol that extends the base service
 * with additional provider-specific functionality.
 */
protocol HistoricalStockDataProvider: HistoricalStockDataService {
    var priority: ProviderPriority { get }
    var requiresAPIKey: Bool { get }
    var rateLimiter: RateLimiter? { get }
    
    /// Provider-specific configuration
    func configure(apiKey: String?) async -> Bool
    
    /// Health check for the provider
    func healthCheck() async -> ProviderHealth
    
    /// Get current usage statistics
    func getUsageStats() -> ProviderUsageStats
}

// MARK: - Rate Limiting

/**
 * Rate limiting support for API providers
 */
protocol RateLimiter {
    var requestsPerSecond: Double { get }
    var requestsPerMinute: Int { get }
    var requestsPerHour: Int { get }
    var requestsPerDay: Int { get }
    
    func canMakeRequest() async -> Bool
    func recordRequest() async
    func timeUntilNextRequest() async -> TimeInterval
}

/**
 * Default rate limiter implementation
 */
actor DefaultRateLimiter: RateLimiter {
    let requestsPerSecond: Double
    let requestsPerMinute: Int
    let requestsPerHour: Int
    let requestsPerDay: Int
    
    private var requestHistory: [Date] = []
    
    init(requestsPerSecond: Double = 1.0,
         requestsPerMinute: Int = 60,
         requestsPerHour: Int = 500,
         requestsPerDay: Int = 1000) {
        self.requestsPerSecond = requestsPerSecond
        self.requestsPerMinute = requestsPerMinute
        self.requestsPerHour = requestsPerHour
        self.requestsPerDay = requestsPerDay
    }
    
    func canMakeRequest() async -> Bool {
        cleanOldRequests()
        
        let now = Date()
        let oneSecondAgo = now.addingTimeInterval(-1.0)
        let oneMinuteAgo = now.addingTimeInterval(-60.0)
        let oneHourAgo = now.addingTimeInterval(-3600.0)
        let oneDayAgo = now.addingTimeInterval(-86400.0)
        
        let recentSecond = requestHistory.filter { $0 >= oneSecondAgo }.count
        let recentMinute = requestHistory.filter { $0 >= oneMinuteAgo }.count
        let recentHour = requestHistory.filter { $0 >= oneHourAgo }.count
        let recentDay = requestHistory.filter { $0 >= oneDayAgo }.count
        
        let canMake = Double(recentSecond) < requestsPerSecond &&
                     recentMinute < requestsPerMinute &&
                     recentHour < requestsPerHour &&
                     recentDay < requestsPerDay
        
        return canMake
    }
    
    func recordRequest() async {
        requestHistory.append(Date())
    }
    
    func timeUntilNextRequest() async -> TimeInterval {
        cleanOldRequests()
        
        // Calculate based on the most restrictive limit
        let now = Date()
        let oneSecondAgo = now.addingTimeInterval(-1.0)
        
        let recentSecond = requestHistory.filter { $0 >= oneSecondAgo }.count
        
        if Double(recentSecond) >= requestsPerSecond {
            let oldestInSecond = requestHistory.filter { $0 >= oneSecondAgo }.min() ?? now
            let waitTime = 1.0 - now.timeIntervalSince(oldestInSecond)
            return max(0, waitTime)
        } else {
            return 0
        }
    }
    
    private func cleanOldRequests() {
        let oneDayAgo = Date().addingTimeInterval(-86400.0)
        requestHistory.removeAll { $0 < oneDayAgo }
    }
}

// MARK: - Provider Health and Statistics

struct ProviderHealth: Sendable {
    let isHealthy: Bool
    let responseTime: TimeInterval?
    let errorRate: Double
    let lastSuccessfulRequest: Date?
    let lastError: HistoricalDataError?
    
    var status: String {
        if isHealthy {
            return "Healthy"
        } else if let error = lastError {
            return "Unhealthy: \(error.localizedDescription)"
        } else {
            return "Unhealthy: Unknown issue"
        }
    }
}

struct ProviderUsageStats: Sendable {
    let requestsToday: Int
    let dailyLimit: Int
    let requestsThisHour: Int
    let hourlyLimit: Int
    let averageResponseTime: TimeInterval
    let successRate: Double
    let costIncurred: Decimal
    
    var remainingRequests: Int {
        return max(0, dailyLimit - requestsToday)
    }
    
    var usagePercentage: Double {
        guard dailyLimit > 0 else { return 0 }
        return Double(requestsToday) / Double(dailyLimit) * 100
    }
}

// MARK: - Caching Protocol

/**
 * Caching support for historical data
 */
protocol HistoricalDataCache {
    func get(
        symbol: String,
        startDate: Date,
        endDate: Date
    ) async -> [HistoricalPrice]?
    
    func set(
        symbol: String,
        prices: [HistoricalPrice],
        startDate: Date,
        endDate: Date
    ) async
    
    func clear(symbol: String?) async
    func clearExpired() async
}

// MARK: - Service Configuration

struct HistoricalDataServiceConfiguration: Sendable {
    let cacheDuration: TimeInterval
    let maxRetries: Int
    let retryDelay: TimeInterval
    let timeoutInterval: TimeInterval
    let enableDiskCache: Bool
    let maxCacheSize: Int
    let enableLogging: Bool
    let logLevel: LogLevel
    
    enum LogLevel: String, Sendable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
    
    static let `default` = HistoricalDataServiceConfiguration(
        cacheDuration: 300, // 5 minutes for intraday data
        maxRetries: 3,
        retryDelay: 2.0,
        timeoutInterval: 30.0,
        enableDiskCache: true,
        maxCacheSize: 1000, // 1000 symbols worth of data
        enableLogging: true,
        logLevel: .info
    )
}

// MARK: - Default Protocol Extensions

extension HistoricalStockDataService {
    /// Default implementation for predefined time periods
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
    
    /// Default availability check (optimistic)
    func isDataAvailable(
        symbol: String,
        startDate: Date,
        endDate: Date
    ) async -> Bool {
        return isAvailable && !symbol.isEmpty && startDate <= endDate
    }
}

extension HistoricalStockDataProvider {
    /// Default health check implementation
    func healthCheck() async -> ProviderHealth {
        do {
            let start = Date()
            _ = try await fetchLatestPrice(symbol: "AAPL")
            let responseTime = Date().timeIntervalSince(start)
            
            return ProviderHealth(
                isHealthy: true,
                responseTime: responseTime,
                errorRate: 0.0,
                lastSuccessfulRequest: Date(),
                lastError: nil
            )
        } catch let error as HistoricalDataError {
            return ProviderHealth(
                isHealthy: false,
                responseTime: nil,
                errorRate: 1.0,
                lastSuccessfulRequest: nil,
                lastError: error
            )
        } catch {
            return ProviderHealth(
                isHealthy: false,
                responseTime: nil,
                errorRate: 1.0,
                lastSuccessfulRequest: nil,
                lastError: .networkError(error)
            )
        }
    }
}