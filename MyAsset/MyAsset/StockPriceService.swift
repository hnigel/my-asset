import Foundation

// MARK: - Distribution Models
struct DistributionInfo {
    let symbol: String
    let distributionRate: Double?          // annualized dividend per share (currency)
    let distributionYieldPercent: Double?  // dividend yield percentage
    let distributionFrequency: String?     // Quarterly/Monthly/Annual
    let lastExDate: Date?
    let lastPaymentDate: Date?
    let fullName: String?                  // longName/complete fund name
}

// Yahoo Finance API Response structure
struct YahooFinanceResponse: Codable {
    let chart: Chart
    
    struct Chart: Codable {
        let result: [Result]?
        let error: ErrorInfo?
    }
    
    struct Result: Codable {
        let meta: Meta
        let timestamp: [TimeInterval]?
        let indicators: Indicators?
    }
    
    struct Meta: Codable {
        let symbol: String
        let regularMarketPrice: Double?
        let longName: String?
        let regularMarketTime: TimeInterval?
    }
    
    struct Indicators: Codable {
        let quote: [Quote]?
    }
    
    struct Quote: Codable {
        let close: [Double?]?
    }
    
    struct ErrorInfo: Codable {
        let code: String
        let description: String
    }
}

// MARK: - Alpha Vantage API Response Structures
struct AlphaVantageQuoteResponse: Codable {
    let globalQuote: AlphaVantageGlobalQuote
    
    private enum CodingKeys: String, CodingKey {
        case globalQuote = "Global Quote"
    }
    
    struct AlphaVantageGlobalQuote: Codable {
        let symbol: String
        let open: String
        let high: String
        let low: String
        let price: String
        let volume: String
        let latestTradingDay: String
        let previousClose: String
        let change: String
        let changePercent: String
        
        private enum CodingKeys: String, CodingKey {
            case symbol = "01. Symbol"
            case open = "02. Open"
            case high = "03. High"
            case low = "04. Low"
            case price = "05. Price"
            case volume = "06. Volume"
            case latestTradingDay = "07. Latest Trading Day"
            case previousClose = "08. Previous Close"
            case change = "09. Change"
            case changePercent = "10. Change Percent"
        }
    }
}

struct AlphaVantageDividendResponse: Codable {
    let data: [AlphaVantageDividend]
    
    private enum CodingKeys: String, CodingKey {
        case data
    }
    
    struct AlphaVantageDividend: Codable {
        let exDividendDate: String
        let dividendAmount: String
        let recordDate: String?
        let paymentDate: String?
        
        private enum CodingKeys: String, CodingKey {
            case exDividendDate = "ex_dividend_date"
            case dividendAmount = "dividend_amount"
            case recordDate = "record_date"
            case paymentDate = "payment_date"
        }
    }
}

// MARK: - Nasdaq API Response Structures
struct NasdaqQuoteResponse: Codable {
    let data: NasdaqData
    let message: String?
    let status: NasdaqStatus
    
    struct NasdaqData: Codable {
        let symbol: String
        let companyName: String
        let primaryData: NasdaqPrimaryData
        
        struct NasdaqPrimaryData: Codable {
            let lastSalePrice: String
            let netChange: String
            let percentageChange: String
            let volume: String
        }
    }
    
    struct NasdaqStatus: Codable {
        let rCode: Int
    }
}

struct NasdaqDividendResponse: Codable {
    let data: NasdaqDividendData
    let message: String?
    let status: NasdaqStatus
    
    struct NasdaqDividendData: Codable {
        let dividendHeaderValues: [NasdaqDividendHeader]
        let exDividendDate: String?
        let dividendPaymentDate: String?
        let yield: String?
        let annualizedDividend: String?
        
        struct NasdaqDividendHeader: Codable {
            let label: String
            let value: String
        }
    }
    
    struct NasdaqStatus: Codable {
        let rCode: Int
    }
}

@MainActor
class StockPriceService: ObservableObject {
    
    // MARK: - Modular Architecture
    // Use the new modular service while maintaining backward compatibility
    private var modularService: ModularStockPriceService?
    
    // MARK: - Legacy API Support
    // Keep existing properties for any direct access (though not recommended)
    private let apiKeyManager = APIKeyManager.shared
    
    // MARK: - Service Initialization Helper
    
    @MainActor
    private func ensureServiceInitialized() async -> ModularStockPriceService {
        if let service = modularService {
            return service
        }
        let service = ModularStockPriceService()
        self.modularService = service
        return service
    }
    
    // MARK: - Initialization
    
    init() {
        // Initialize ModularStockPriceService asynchronously to avoid concurrency issues
        Task { @MainActor in
            self.modularService = ModularStockPriceService()
        }
    }
    
    // MARK: - Legacy Error Support
    // Keep existing APIError for backward compatibility
    enum APIError: Error, LocalizedError {
        case invalidURL
        case noData
        case decodingError(String)
        case rateLimitExceeded
        case networkError(Error)
        case invalidSymbol(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL for stock data request"
            case .noData:
                return "No data received from stock service"
            case .decodingError(let details):
                return "Failed to parse stock data: \(details)"
            case .rateLimitExceeded:
                return "Too many requests. Please try again later."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidSymbol(let symbol):
                return "Invalid or unknown stock symbol: \(symbol)"
            }
        }
        
        // Convert from ProviderError to maintain compatibility
        static func from(_ providerError: ProviderError) -> APIError {
            switch providerError {
            case .invalidURL:
                return .invalidURL
            case .noData:
                return .noData
            case .decodingError(let details):
                return .decodingError(details)
            case .rateLimitExceeded:
                return .rateLimitExceeded
            case .networkError(let error):
                return .networkError(error)
            case .invalidSymbol(let symbol):
                return .invalidSymbol(symbol)
            case .providerUnavailable:
                return .noData
            case .apiKeyMissing:
                return .networkError(NSError(domain: "APIKey", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key missing"]))
            }
        }
    }
    
    func fetchStockPrice(symbol: String) async throws -> StockQuote {
        let service = await ensureServiceInitialized()
        
        do {
            return try await service.fetchStockPrice(symbol: symbol)
        } catch let providerError as ProviderError {
            throw APIError.from(providerError)
        } catch {
            throw error
        }
    }
    
    
    
    func fetchMultipleStockPrices(symbols: [String]) async -> [String: StockQuote] {
        let service = await ensureServiceInitialized()
        return await service.fetchMultipleStockPrices(symbols: symbols)
    }
    
    // MARK: - Demo/Test Methods
    
    func fetchDemoStockPrice(symbol: String) async -> StockQuote {
        let cleanSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Provide demo data for testing
        let demoPrice: Double
        switch cleanSymbol {
        case "AAPL":
            demoPrice = 175.50
        case "GOOGL", "GOOG":
            demoPrice = 140.25
        case "MSFT":
            demoPrice = 415.75
        case "TSLA":
            demoPrice = 245.00
        case "AMZN":
            demoPrice = 155.80
        case "META":
            demoPrice = 485.20
        case "NVDA":
            demoPrice = 890.15
        case "NFLX":
            demoPrice = 630.45
        default:
            demoPrice = Double.random(in: 50...500)
        }
        
        return StockQuote(
            symbol: cleanSymbol,
            price: demoPrice,
            companyName: "\(cleanSymbol) Corporation",
            lastUpdated: Date()
        )
    }
    
    // MARK: - Legacy Implementation Removed
    // All API calls are now handled by the modular architecture
    // Individual service implementations can be found in separate files:
    // - YahooFinanceStockService.swift
    // - NasdaqStockService.swift  
    // - AlphaVantageStockService.swift
    // - YahooFinanceDividendService.swift
    // - NasdaqDividendService.swift
    // - AlphaVantageDividendService.swift
    
    // MARK: - Distribution API
    func fetchDistributionInfo(symbol: String) async -> DistributionInfo {
        let service = await ensureServiceInitialized()
        return await service.fetchDistributionInfo(symbol: symbol)
    }
    
    // MARK: - Cache Management (Delegated to Modular Service)
    func clearCache() {
        Task {
            let service = await ensureServiceInitialized()
            await MainActor.run {
                service.clearCache()
            }
        }
    }
    
    func isCached(symbol: String) -> Bool {
        guard let service = modularService else { return false }
        return service.isCached(symbol: symbol)
    }
    
    func isDistributionCached(symbol: String) -> Bool {
        guard let service = modularService else { return false }
        return service.isDistributionCached(symbol: symbol)
    }
    
    // MARK: - Alpha Vantage Rate Limiting (Delegated to Modular Service)
    
    // Get Alpha Vantage API usage info for monitoring
    func getAlphaVantageUsage() -> (requestsUsed: Int, dailyLimit: Int, resetsAt: Date) {
        guard let service = modularService else {
            return (0, 25, Date())
        }
        return service.getAlphaVantageUsage()
    }
    
    // MARK: - API Configuration Management (Delegated to Modular Service)
    
    func updateAPIKey(_ key: String, for provider: APIKeyManager.APIProvider) async -> Bool {
        let service = await ensureServiceInitialized()
        return await service.updateAPIKey(key, for: provider)
    }
    
    func hasValidAPIKey(for provider: APIKeyManager.APIProvider) -> Bool {
        guard let service = modularService else { return false }
        return service.hasValidAPIKey(for: provider)
    }
    
    func getAPIProviderStatus() -> [(provider: APIKeyManager.APIProvider, hasKey: Bool, isConfigured: Bool)] {
        guard let service = modularService else { return [] }
        return service.getAPIProviderStatus()
    }
    
}

// Extension for StockQuote utility methods
extension StockQuote {
    // Validate if the stock quote has valid data
    var isValid: Bool {
        return !symbol.isEmpty && price > 0
    }
    
    // Format price for display
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: price)) ?? "$0.00"
    }
}

// MARK: - StockPriceService Test Helpers (Delegated to Modular Service)
extension StockPriceService {
    // For testing - inject mock cache
    func setCachedPrice(symbol: String, quote: StockQuote) {
        Task {
            let service = await ensureServiceInitialized()
            await MainActor.run {
                service.setCachedPrice(symbol: symbol, quote: quote)
            }
        }
    }
    
    // For testing - check cache size
    var cacheSize: Int {
        guard let service = modularService else { return 0 }
        return service.cacheSize
    }
    
    // For testing - check distribution cache size
    var distributionCacheSize: Int {
        guard let service = modularService else { return 0 }
        return service.distributionCacheSize
    }
    
    // For testing - inject mock distribution cache
    func setCachedDistribution(symbol: String, info: DistributionInfo) {
        Task {
            let service = await ensureServiceInitialized()
            await MainActor.run {
                service.setCachedDistribution(symbol: symbol, info: info)
            }
        }
    }
    
    // MARK: - New Modular Architecture Features
    
    func getStockProviderStatus() -> [(name: String, available: Bool, priority: String)] {
        guard let service = modularService else { return [] }
        return service.getStockProviderStatus()
    }
    
    func getDividendProviderStatus() -> [(name: String, available: Bool, priority: String)] {
        guard let service = modularService else { return [] }
        return service.getDividendProviderStatus()
    }
    
    func performHealthCheck() async -> SystemHealthReport {
        let service = await ensureServiceInitialized()
        return await service.performHealthCheck()
    }
    
    // MARK: - Historical Data Methods (New)
    
    func fetchHistoricalPrices(symbol: String, period: HistoricalPrice.TimePeriod) async throws -> [HistoricalPrice] {
        let service = await ensureServiceInitialized()
        return try await service.fetchHistoricalPrices(symbol: symbol, period: period)
    }
    
    func fetchHistoricalPrices(symbol: String, startDate: Date, endDate: Date) async throws -> [HistoricalPrice] {
        let service = await ensureServiceInitialized()
        return try await service.fetchHistoricalPrices(symbol: symbol, startDate: startDate, endDate: endDate)
    }
    
    func fetchMultipleHistoricalPrices(symbols: [String], period: HistoricalPrice.TimePeriod) async -> [String: [HistoricalPrice]] {
        let service = await ensureServiceInitialized()
        return await service.fetchMultipleHistoricalPrices(symbols: symbols, period: period)
    }
    
    func clearHistoricalCache() async {
        let service = await ensureServiceInitialized()
        await service.clearHistoricalCache()
    }
    
    func getHistoricalDataStats() async -> ComprehensiveHealthReport {
        let service = await ensureServiceInitialized()
        return await service.getHistoricalDataStats()
    }
}