import Foundation

/**
 * Yahoo Finance Historical Stock Data Service
 * 
 * Provides historical stock price data using Yahoo Finance API.
 * This service is free but may have rate limits and availability constraints.
 */
class YahooFinanceHistoricalService: HistoricalStockDataProvider {
    
    // MARK: - Protocol Properties
    
    let providerName = "Yahoo Finance Historical"
    var isAvailable: Bool { 
        // Yahoo Finance doesn't require API key but may be blocked
        return true 
    }
    
    let supportedTimePeriods: [HistoricalPrice.TimePeriod] = HistoricalPrice.TimePeriod.allCases
    let dailyRequestLimit = 2000 // Conservative estimate
    let costPerRequest: Decimal = 0.0 // Free service
    let priority: ProviderPriority = .primary
    let requiresAPIKey = false
    
    // MARK: - Private Properties
    
    private let baseURL = "https://query1.finance.yahoo.com/v8/finance/chart"
    private let session = URLSession.shared
    private let defaultRateLimiter: DefaultRateLimiter
    private let configuration: HistoricalDataServiceConfiguration
    
    private var requestCount = 0
    private var lastRequestTime: Date?
    private var errorCount = 0
    private var totalRequests = 0
    
    // MARK: - Initialization
    
    init(configuration: HistoricalDataServiceConfiguration = .default) {
        self.configuration = configuration
        self.defaultRateLimiter = DefaultRateLimiter(
            requestsPerSecond: 2.0,
            requestsPerMinute: 60,
            requestsPerHour: 500,
            requestsPerDay: dailyRequestLimit
        )
    }
    
    // MARK: - Configuration
    
    func configure(apiKey: String?) async -> Bool {
        // Yahoo Finance doesn't require API key
        return true
    }
    
    // MARK: - Core Historical Data Methods
    
    func fetchHistoricalPrices(
        symbol: String,
        startDate: Date,
        endDate: Date
    ) async throws -> [HistoricalPrice] {
        
        guard !symbol.isEmpty else {
            throw HistoricalDataError.invalidSymbol("Empty symbol")
        }
        
        guard startDate <= endDate else {
            throw HistoricalDataError.invalidDateRange("Start date must be before end date")
        }
        
        // Check rate limiting
        guard await defaultRateLimiter.canMakeRequest() else {
            let waitTime = await defaultRateLimiter.timeUntilNextRequest()
            throw HistoricalDataError.rateLimitExceeded(retryAfter: waitTime)
        }
        
        let startTimestamp = Int(startDate.timeIntervalSince1970)
        let endTimestamp = Int(endDate.timeIntervalSince1970)
        
        guard let url = URL(string: "\(baseURL)/\(symbol.uppercased())?period1=\(startTimestamp)&period2=\(endTimestamp)&interval=1d") else {
            throw HistoricalDataError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://finance.yahoo.com", forHTTPHeaderField: "Referer")
        request.timeoutInterval = configuration.timeoutInterval
        
        do {
            await defaultRateLimiter.recordRequest()
            totalRequests += 1
            
            let startTime = Date()
            let (data, response) = try await session.data(for: request)
            let responseTime = Date().timeIntervalSince(startTime)
            lastRequestTime = Date()
            
            if configuration.enableLogging && configuration.logLevel == .debug {
                print("[\(providerName)] Response time: \(responseTime)s for \(symbol)")
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                errorCount += 1
                throw HistoricalDataError.networkError(NSError(domain: "NoHTTPResponse", code: 0, userInfo: nil))
            }
            
            switch httpResponse.statusCode {
            case 200:
                break
            case 404:
                errorCount += 1
                throw HistoricalDataError.invalidSymbol(symbol)
            case 429:
                errorCount += 1
                throw HistoricalDataError.rateLimitExceeded(retryAfter: 60.0)
            default:
                errorCount += 1
                throw HistoricalDataError.networkError(NSError(domain: "HTTPError", code: httpResponse.statusCode))
            }
            
            return try parseYahooHistoricalResponse(data, symbol: symbol)
            
        } catch let error as HistoricalDataError {
            errorCount += 1
            if configuration.enableLogging {
                print("[\(providerName)] Error: \(error.logMessage)")
            }
            throw error
        } catch {
            errorCount += 1
            throw HistoricalDataError.networkError(error)
        }
    }
    
    func fetchLatestPrice(symbol: String) async throws -> HistoricalPrice {
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
    
    // MARK: - Yahoo Finance Response Parsing
    
    private func parseYahooHistoricalResponse(_ data: Data, symbol: String) throws -> [HistoricalPrice] {
        do {
            let decoder = JSONDecoder()
            let yahooResponse = try decoder.decode(YahooHistoricalResponse.self, from: data)
            
            guard let result = yahooResponse.chart.result?.first else {
                if let error = yahooResponse.chart.error {
                    throw HistoricalDataError.invalidSymbol("\(symbol): \(error.description)")
                }
                throw HistoricalDataError.noData
            }
            
            guard let timestamps = result.timestamp,
                  let quotes = result.indicators?.quote?.first,
                  let opens = quotes.open,
                  let highs = quotes.high,
                  let lows = quotes.low,
                  let closes = quotes.close,
                  let volumes = quotes.volume else {
                throw HistoricalDataError.decodingError("Missing required price data")
            }
            
            var historicalPrices: [HistoricalPrice] = []
            
            for i in 0..<timestamps.count {
                guard i < opens.count,
                      i < highs.count,
                      i < lows.count,
                      i < closes.count,
                      i < volumes.count else {
                    continue
                }
                
                // Skip entries with null values
                guard let open = opens[i],
                      let high = highs[i],
                      let low = lows[i],
                      let close = closes[i],
                      let volume = volumes[i] else {
                    continue
                }
                
                let date = Date(timeIntervalSince1970: timestamps[i])
                
                let price = HistoricalPrice(
                    date: date,
                    openPrice: Decimal(open),
                    highPrice: Decimal(high),
                    lowPrice: Decimal(low),
                    closePrice: Decimal(close),
                    volume: Int64(volume),
                    symbol: symbol,
                    dataSource: providerName
                )
                
                // Validate data quality
                if price.isValid {
                    historicalPrices.append(price)
                } else if configuration.enableLogging && configuration.logLevel == .warning {
                    print("[\(providerName)] Warning: Invalid price data for \(symbol) on \(date)")
                }
            }
            
            if historicalPrices.isEmpty {
                throw HistoricalDataError.noData
            }
            
            // Sort by date ascending
            historicalPrices.sort { $0.date < $1.date }
            
            if configuration.enableLogging && configuration.logLevel == .info {
                print("[\(providerName)] Successfully fetched \(historicalPrices.count) price points for \(symbol)")
            }
            
            return historicalPrices
            
        } catch let decodingError as DecodingError {
            throw HistoricalDataError.decodingError("Yahoo Finance parsing error: \(decodingError.localizedDescription)")
        }
    }
    
    // MARK: - Provider Statistics and Health
    
    func getUsageStats() -> ProviderUsageStats {
        let successRate = totalRequests > 0 ? 1.0 - (Double(errorCount) / Double(totalRequests)) : 1.0
        
        return ProviderUsageStats(
            requestsToday: requestCount,
            dailyLimit: dailyRequestLimit,
            requestsThisHour: requestCount, // Simplified for now
            hourlyLimit: 500,
            averageResponseTime: 1.5, // Estimated
            successRate: successRate,
            costIncurred: 0.0
        )
    }
    
    var rateLimiter: RateLimiter? {
        return defaultRateLimiter as RateLimiter
    }
}

// MARK: - Yahoo Finance Historical Response Models

private struct YahooHistoricalResponse: Codable {
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
        let instrumentType: String?
        let firstTradeDate: TimeInterval?
        let regularMarketTime: TimeInterval?
        let gmtoffset: Int?
        let timezone: String?
        let exchangeTimezoneName: String?
        let regularMarketPrice: Double?
        let chartPreviousClose: Double?
        let currency: String?
        let exchangeName: String?
        let longName: String?
        let shortName: String?
    }
    
    struct Indicators: Codable {
        let quote: [Quote]?
        let adjclose: [AdjClose]?
    }
    
    struct Quote: Codable {
        let open: [Double?]?
        let high: [Double?]?
        let low: [Double?]?
        let close: [Double?]?
        let volume: [Int64?]?
    }
    
    struct AdjClose: Codable {
        let adjclose: [Double?]?
    }
    
    struct ErrorInfo: Codable {
        let code: String
        let description: String
    }
}