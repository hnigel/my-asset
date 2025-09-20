import Foundation

/**
 * EODHD Historical Stock Data Service
 * 
 * Provides historical stock price data using EODHD (End of Day Historical Data) API.
 * This is a premium service with high data quality and comprehensive coverage.
 */
class EODHDHistoricalService: HistoricalStockDataProvider {
    
    // MARK: - Protocol Properties
    
    let providerName = "EODHD Historical"
    var isAvailable: Bool { 
        return APIKeyManager.shared.hasAPIKey(for: .eodhd) 
    }
    
    let supportedTimePeriods: [HistoricalPrice.TimePeriod] = HistoricalPrice.TimePeriod.allCases
    let dailyRequestLimit = 100000 // EODHD has high limits
    let costPerRequest: Decimal = 0.001 // Approximate cost per request
    let priority: ProviderPriority = .secondary
    let requiresAPIKey = true
    
    // MARK: - Private Properties
    
    private let baseURL = "https://eodhistoricaldata.com/api/eod"
    private let session = URLSession.shared
    private let apiKeyManager = APIKeyManager.shared
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
            requestsPerSecond: 10.0, // EODHD allows higher rates
            requestsPerMinute: 600,
            requestsPerHour: 10000,
            requestsPerDay: dailyRequestLimit
        )
    }
    
    // MARK: - Configuration
    
    func configure(apiKey: String?) async -> Bool {
        guard let apiKey = apiKey else { return false }
        return await apiKeyManager.validateAPIKey(apiKey, for: .eodhd)
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
        
        guard let apiKey = apiKeyManager.getAPIKey(for: .eodhd) else {
            throw HistoricalDataError.apiKeyMissing(providerName)
        }
        
        // Check rate limiting
        guard await defaultRateLimiter.canMakeRequest() else {
            let waitTime = await defaultRateLimiter.timeUntilNextRequest()
            throw HistoricalDataError.rateLimitExceeded(retryAfter: waitTime)
        }
        
        // Format dates for EODHD API
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fromDate = dateFormatter.string(from: startDate)
        let toDate = dateFormatter.string(from: endDate)
        
        // EODHD expects format: SYMBOL.EXCHANGE
        let formattedSymbol = formatSymbolForEODHD(symbol)
        
        guard let url = URL(string: "\(baseURL)/\(formattedSymbol)?api_token=\(apiKey)&period=d&fmt=json&from=\(fromDate)&to=\(toDate)") else {
            throw HistoricalDataError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
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
            case 400:
                errorCount += 1
                throw HistoricalDataError.invalidSymbol(symbol)
            case 401:
                errorCount += 1
                throw HistoricalDataError.apiKeyMissing(providerName)
            case 403:
                errorCount += 1
                throw HistoricalDataError.quotaExceeded(providerName)
            case 429:
                errorCount += 1
                throw HistoricalDataError.rateLimitExceeded(retryAfter: 60.0)
            default:
                errorCount += 1
                throw HistoricalDataError.networkError(NSError(domain: "HTTPError", code: httpResponse.statusCode))
            }
            
            return try parseEODHDResponse(data, symbol: symbol)
            
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
        let startDate = Calendar.current.date(byAdding: .day, value: -5, to: endDate) ?? endDate
        
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
    
    func isDataAvailable(
        symbol: String,
        startDate: Date,
        endDate: Date
    ) async -> Bool {
        guard isAvailable else { return false }
        
        do {
            let prices = try await fetchHistoricalPrices(
                symbol: symbol,
                startDate: startDate,
                endDate: endDate
            )
            return !prices.isEmpty
        } catch {
            return false
        }
    }
    
    func healthCheck() async -> ProviderHealth {
        do {
            let start = Date()
            _ = try await fetchLatestPrice(symbol: "AAPL")
            let responseTime = Date().timeIntervalSince(start)
            
            return ProviderHealth(
                isHealthy: true,
                responseTime: responseTime,
                errorRate: totalRequests > 0 ? Double(errorCount) / Double(totalRequests) : 0.0,
                lastSuccessfulRequest: Date(),
                lastError: nil
            )
        } catch let error as HistoricalDataError {
            return ProviderHealth(
                isHealthy: false,
                responseTime: nil,
                errorRate: totalRequests > 0 ? Double(errorCount) / Double(totalRequests) : 1.0,
                lastSuccessfulRequest: lastRequestTime,
                lastError: error
            )
        } catch {
            return ProviderHealth(
                isHealthy: false,
                responseTime: nil,
                errorRate: totalRequests > 0 ? Double(errorCount) / Double(totalRequests) : 1.0,
                lastSuccessfulRequest: lastRequestTime,
                lastError: .networkError(error)
            )
        }
    }
    
    // MARK: - Symbol Formatting
    
    private func formatSymbolForEODHD(_ symbol: String) -> String {
        let cleanSymbol = symbol.uppercased()
        
        // EODHD requires exchange suffix for most symbols
        // Default to US exchange if not specified
        if !cleanSymbol.contains(".") {
            return "\(cleanSymbol).US"
        }
        
        return cleanSymbol
    }
    
    // MARK: - EODHD Response Parsing
    
    private func parseEODHDResponse(_ data: Data, symbol: String) throws -> [HistoricalPrice] {
        do {
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            
            let eodhdResponse = try decoder.decode([EODHDHistoricalData].self, from: data)
            
            if eodhdResponse.isEmpty {
                throw HistoricalDataError.noData
            }
            
            var historicalPrices: [HistoricalPrice] = []
            
            for dataPoint in eodhdResponse {
                // Validate data point
                guard dataPoint.open > 0,
                      dataPoint.high > 0,
                      dataPoint.low > 0,
                      dataPoint.close > 0,
                      dataPoint.volume >= 0 else {
                    if configuration.enableLogging && configuration.logLevel == .warning {
                        print("[\(providerName)] Warning: Invalid price data for \(symbol) on \(dataPoint.date)")
                    }
                    continue
                }
                
                let price = HistoricalPrice(
                    date: dataPoint.date,
                    openPrice: Decimal(dataPoint.open),
                    highPrice: Decimal(dataPoint.high),
                    lowPrice: Decimal(dataPoint.low),
                    closePrice: dataPoint.adjustedClose != nil ? Decimal(dataPoint.adjustedClose!) : Decimal(dataPoint.close),
                    volume: Int64(dataPoint.volume),
                    symbol: symbol,
                    dataSource: providerName
                )
                
                // Additional validation
                if price.isValid {
                    historicalPrices.append(price)
                } else if configuration.enableLogging && configuration.logLevel == .warning {
                    print("[\(providerName)] Warning: Price validation failed for \(symbol) on \(dataPoint.date)")
                }
            }
            
            if historicalPrices.isEmpty {
                throw HistoricalDataError.dataQualityError("All data points failed validation")
            }
            
            // Sort by date ascending
            historicalPrices.sort { $0.date < $1.date }
            
            if configuration.enableLogging && configuration.logLevel == .info {
                print("[\(providerName)] Successfully fetched \(historicalPrices.count) price points for \(symbol)")
            }
            
            return historicalPrices
            
        } catch let decodingError as DecodingError {
            throw HistoricalDataError.decodingError("EODHD parsing error: \(decodingError.localizedDescription)")
        }
    }
    
    // MARK: - Provider Statistics and Health
    
    func getUsageStats() -> ProviderUsageStats {
        let successRate = totalRequests > 0 ? 1.0 - (Double(errorCount) / Double(totalRequests)) : 1.0
        
        return ProviderUsageStats(
            requestsToday: requestCount,
            dailyLimit: dailyRequestLimit,
            requestsThisHour: requestCount, // Simplified for now
            hourlyLimit: 10000,
            averageResponseTime: 0.8, // EODHD is typically fast
            successRate: successRate,
            costIncurred: Decimal(totalRequests) * costPerRequest
        )
    }
    
    var rateLimiter: RateLimiter? {
        return defaultRateLimiter as RateLimiter
    }
    
    // MARK: - Enhanced Features
    
    /// Fetch historical data with specific intervals
    func fetchHistoricalPrices(
        symbol: String,
        startDate: Date,
        endDate: Date,
        interval: EODHDInterval = .daily
    ) async throws -> [HistoricalPrice] {
        
        // For now, we only support daily interval
        // This could be extended for intraday data
        return try await fetchHistoricalPrices(
            symbol: symbol,
            startDate: startDate,
            endDate: endDate
        )
    }
}

// MARK: - EODHD Specific Models

private struct EODHDHistoricalData: Codable {
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let adjustedClose: Double?
    let volume: Int64
    
    private enum CodingKeys: String, CodingKey {
        case date
        case open
        case high
        case low
        case close
        case adjustedClose = "adjusted_close"
        case volume
    }
}

enum EODHDInterval: String {
    case daily = "d"
    case weekly = "w"
    case monthly = "m"
}