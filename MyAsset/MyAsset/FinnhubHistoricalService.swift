import Foundation

/**
 * Finnhub Historical Stock Data Service
 * 
 * Provides historical stock price data using Finnhub API.
 * Offers good data quality with reasonable rate limits for free tier.
 */
class FinnhubHistoricalService: HistoricalStockDataProvider {
    
    // MARK: - Protocol Properties
    
    let providerName = "Finnhub Historical"
    var isAvailable: Bool { 
        return APIKeyManager.shared.hasAPIKey(for: .finnhub) 
    }
    
    let supportedTimePeriods: [HistoricalPrice.TimePeriod] = [
        .oneWeek, .oneMonth, .threeMonths, .sixMonths, .oneYear, .twoYears, .fiveYears
    ]
    let dailyRequestLimit = 60 // Free tier limit
    let costPerRequest: Decimal = 0.0 // Free for basic historical data
    let priority: ProviderPriority = .tertiary
    let requiresAPIKey = true
    
    // MARK: - Private Properties
    
    private let baseURL = "https://finnhub.io/api/v1"
    private let session = URLSession.shared
    private let apiKeyManager = APIKeyManager.shared
    private let _rateLimiter: DefaultRateLimiter
    private let configuration: HistoricalDataServiceConfiguration
    
    private var requestCount = 0
    private var lastRequestTime: Date?
    private var errorCount = 0
    private var totalRequests = 0
    
    // MARK: - Initialization
    
    init(configuration: HistoricalDataServiceConfiguration = .default) {
        self.configuration = configuration
        self._rateLimiter = DefaultRateLimiter(
            requestsPerSecond: 0.5, // Conservative for free tier
            requestsPerMinute: 30,
            requestsPerHour: 60,
            requestsPerDay: dailyRequestLimit
        )
    }
    
    // MARK: - Configuration
    
    func configure(apiKey: String?) async -> Bool {
        guard let apiKey = apiKey else { return false }
        return await apiKeyManager.validateAPIKey(apiKey, for: .finnhub)
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
        
        guard let apiKey = apiKeyManager.getAPIKey(for: .finnhub) else {
            throw HistoricalDataError.apiKeyMissing(providerName)
        }
        
        // Check rate limiting
        guard await _rateLimiter.canMakeRequest() else {
            let waitTime = await _rateLimiter.timeUntilNextRequest()
            throw HistoricalDataError.rateLimitExceeded(retryAfter: waitTime)
        }
        
        // Finnhub uses Unix timestamps
        let startTimestamp = Int(startDate.timeIntervalSince1970)
        let endTimestamp = Int(endDate.timeIntervalSince1970)
        
        // Finnhub stock candles endpoint
        guard let url = URL(string: "\(baseURL)/stock/candle?symbol=\(symbol.uppercased())&resolution=D&from=\(startTimestamp)&to=\(endTimestamp)&token=\(apiKey)") else {
            throw HistoricalDataError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = configuration.timeoutInterval
        
        do {
            await _rateLimiter.recordRequest()
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
            case 401:
                errorCount += 1
                throw HistoricalDataError.apiKeyMissing(providerName)
            case 403:
                errorCount += 1
                throw HistoricalDataError.quotaExceeded(providerName)
            case 422:
                errorCount += 1
                throw HistoricalDataError.invalidSymbol(symbol)
            case 429:
                errorCount += 1
                // Finnhub provides retry-after header
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                let waitTime = TimeInterval(retryAfter ?? "60") ?? 60.0
                throw HistoricalDataError.rateLimitExceeded(retryAfter: waitTime)
            default:
                errorCount += 1
                throw HistoricalDataError.networkError(NSError(domain: "HTTPError", code: httpResponse.statusCode))
            }
            
            return try parseFinnhubResponse(data, symbol: symbol)
            
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
        guard let apiKey = apiKeyManager.getAPIKey(for: .finnhub) else {
            throw HistoricalDataError.apiKeyMissing(providerName)
        }
        
        // Use quote endpoint for latest price
        guard let url = URL(string: "\(baseURL)/quote?symbol=\(symbol.uppercased())&token=\(apiKey)") else {
            throw HistoricalDataError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = configuration.timeoutInterval
        
        do {
            await _rateLimiter.recordRequest()
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw HistoricalDataError.networkError(NSError(domain: "HTTPError", code: (response as? HTTPURLResponse)?.statusCode ?? 0))
            }
            
            let decoder = JSONDecoder()
            let quoteResponse = try decoder.decode(FinnhubQuoteResponse.self, from: data)
            
            return HistoricalPrice(
                date: Date(),
                openPrice: Decimal(quoteResponse.o),
                highPrice: Decimal(quoteResponse.h),
                lowPrice: Decimal(quoteResponse.l),
                closePrice: Decimal(quoteResponse.c),
                volume: 0, // Not available in quote endpoint
                symbol: symbol,
                dataSource: providerName
            )
            
        } catch let error as HistoricalDataError {
            throw error
        } catch {
            throw HistoricalDataError.networkError(error)
        }
    }
    
    // MARK: - Finnhub Response Parsing
    
    private func parseFinnhubResponse(_ data: Data, symbol: String) throws -> [HistoricalPrice] {
        do {
            let decoder = JSONDecoder()
            let finnhubResponse = try decoder.decode(FinnhubCandleResponse.self, from: data)
            
            // Finnhub returns "no_data" status for invalid symbols/date ranges
            if finnhubResponse.s == "no_data" {
                throw HistoricalDataError.noData
            }
            
            guard finnhubResponse.s == "ok",
                  let timestamps = finnhubResponse.t,
                  let opens = finnhubResponse.o,
                  let highs = finnhubResponse.h,
                  let lows = finnhubResponse.l,
                  let closes = finnhubResponse.c,
                  let volumes = finnhubResponse.v else {
                throw HistoricalDataError.decodingError("Invalid response format from Finnhub")
            }
            
            guard timestamps.count == opens.count &&
                  timestamps.count == highs.count &&
                  timestamps.count == lows.count &&
                  timestamps.count == closes.count &&
                  timestamps.count == volumes.count else {
                throw HistoricalDataError.dataQualityError("Mismatched array lengths in Finnhub response")
            }
            
            var historicalPrices: [HistoricalPrice] = []
            
            for i in 0..<timestamps.count {
                let date = Date(timeIntervalSince1970: timestamps[i])
                let open = opens[i]
                let high = highs[i]
                let low = lows[i]
                let close = closes[i]
                let volume = volumes[i]
                
                // Validate data point
                guard open > 0, high > 0, low > 0, close > 0, volume >= 0 else {
                    if configuration.enableLogging && configuration.logLevel == .warning {
                        print("[\(providerName)] Warning: Invalid price data for \(symbol) on \(date)")
                    }
                    continue
                }
                
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
                
                // Additional validation
                if price.isValid {
                    historicalPrices.append(price)
                } else if configuration.enableLogging && configuration.logLevel == .warning {
                    print("[\(providerName)] Warning: Price validation failed for \(symbol) on \(date)")
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
            throw HistoricalDataError.decodingError("Finnhub parsing error: \(decodingError.localizedDescription)")
        }
    }
    
    // MARK: - Provider Statistics and Health
    
    var rateLimiter: RateLimiter? {
        return self._rateLimiter as RateLimiter
    }
    
    func getUsageStats() -> ProviderUsageStats {
        let successRate = totalRequests > 0 ? 1.0 - (Double(errorCount) / Double(totalRequests)) : 1.0
        
        return ProviderUsageStats(
            requestsToday: requestCount,
            dailyLimit: dailyRequestLimit,
            requestsThisHour: requestCount, // Simplified for now
            hourlyLimit: 60,
            averageResponseTime: 1.2, // Finnhub is reasonably fast
            successRate: successRate,
            costIncurred: 0.0 // Free tier
        )
    }
    
    
    // MARK: - Extended Date Range Support
    
    func isDataAvailable(
        symbol: String,
        startDate: Date,
        endDate: Date
    ) async -> Bool {
        // Finnhub has some limitations on historical data depth for free tier
        let maxHistoryDays = 365 * 2 // 2 years for free tier
        let oldestSupportedDate = Date().addingTimeInterval(-TimeInterval(maxHistoryDays * 24 * 60 * 60))
        
        return isAvailable && 
               !symbol.isEmpty && 
               startDate <= endDate && 
               startDate >= oldestSupportedDate
    }
}

// MARK: - Finnhub Response Models

private struct FinnhubCandleResponse: Codable {
    let c: [Double]? // Close prices
    let h: [Double]? // High prices
    let l: [Double]? // Low prices
    let o: [Double]? // Open prices
    let s: String    // Status: "ok", "no_data"
    let t: [TimeInterval]? // Timestamps
    let v: [Int64]? // Volumes
}

