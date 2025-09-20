import Foundation

/**
 * Finnhub Dividend Service
 * 
 * Provides dividend data from Finnhub API.
 * Finnhub offers comprehensive dividend information with good historical data.
 */
class FinnhubDividendService: DividendProvider {
    
    // MARK: - Properties
    
    let providerName = "Finnhub"
    private let apiKeyManager = APIKeyManager.shared
    var isAvailable: Bool { 
        apiKeyManager.getAPIKey(for: .finnhub) != nil
    }
    
    var name: String { "Finnhub" }
    var priority: Int { 5 } // Lower priority - paid API, use as backup
    
    private let baseURL = "https://finnhub.io/api/v1"
    private let session = URLSession.shared
    
    // Rate limiting (Finnhub free tier: 60 API calls/minute)
    private var lastRequestTime = Date(timeIntervalSince1970: 0)
    private let minRequestInterval: TimeInterval = 1.0 // 1 second between requests
    
    // MARK: - Public Methods
    
    func fetchDividendInfo(symbol: String) async throws -> DistributionInfo {
        // Rate limiting
        try await enforceRateLimit()
        
        guard let apiKey = apiKeyManager.getAPIKey(for: .finnhub) else {
            throw StockPriceService.APIError.networkError(NSError(
                domain: "FinnhubAuth", 
                code: 401, 
                userInfo: [NSLocalizedDescriptionKey: "Finnhub API key not configured"]
            ))
        }
        
        // Clean symbol for Finnhub
        let cleanSymbol = cleanFinnhubSymbol(symbol)
        
        // Get dividend data from Finnhub dividends endpoint
        let fromDate = dateFormatter().string(from: Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date())
        let toDate = dateFormatter().string(from: Date())
        
        guard let url = URL(string: "\(baseURL)/stock/dividend?symbol=\(cleanSymbol)&from=\(fromDate)&to=\(toDate)&token=\(apiKey)") else {
            throw StockPriceService.APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("MyAsset/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20.0
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StockPriceService.APIError.networkError(NSError(domain: "NoHTTPResponse", code: 0))
        }
        
        switch httpResponse.statusCode {
        case 200:
            return try parseFinnhubDividendResponse(data: data, symbol: cleanSymbol)
        case 401:
            throw StockPriceService.APIError.networkError(NSError(
                domain: "FinnhubAuth", 
                code: 401, 
                userInfo: [NSLocalizedDescriptionKey: "Finnhub API key invalid or expired"]
            ))
        case 403:
            throw StockPriceService.APIError.networkError(NSError(
                domain: "FinnhubAuth", 
                code: 403, 
                userInfo: [NSLocalizedDescriptionKey: "Finnhub API access forbidden"]
            ))
        case 429:
            throw StockPriceService.APIError.networkError(NSError(
                domain: "FinnhubRateLimit", 
                code: 429, 
                userInfo: [NSLocalizedDescriptionKey: "Finnhub rate limit exceeded"]
            ))
        default:
            throw StockPriceService.APIError.networkError(NSError(
                domain: "FinnhubError", 
                code: httpResponse.statusCode, 
                userInfo: [NSLocalizedDescriptionKey: "Finnhub API error: \(httpResponse.statusCode)"]
            ))
        }
    }
    
    // MARK: - Private Methods
    
    private func cleanFinnhubSymbol(_ symbol: String) -> String {
        // Remove common exchange suffixes that Finnhub doesn't use
        let cleanSymbol = symbol.uppercased()
            .replacingOccurrences(of: ".US", with: "")
            .replacingOccurrences(of: ".NYSE", with: "")
            .replacingOccurrences(of: ".NASDAQ", with: "")
        
        return cleanSymbol
    }
    
    private func parseFinnhubDividendResponse(data: Data, symbol: String) throws -> DistributionInfo {
        do {
            let dividends = try JSONDecoder().decode([FinnhubDividendEntry].self, from: data)
            
            // Sort dividends by date (most recent first)
            let sortedDividends = dividends.sorted { $0.date > $1.date }
            
            var annualDividendRate: Double = 0
            var lastExDate: Date? = nil
            var frequency: String? = nil
            
            if !sortedDividends.isEmpty {
                // Get the most recent dividend
                let mostRecent = sortedDividends.first!
                lastExDate = mostRecent.date
                
                // Calculate annual dividend rate from the last 12 months
                let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
                let recentDividends = sortedDividends.filter { $0.date >= oneYearAgo }
                annualDividendRate = recentDividends.reduce(0) { $0 + $1.amount }
                
                // Determine frequency based on number of dividends in recent year
                frequency = determineDividendFrequency(count: recentDividends.count)
            }
            
            return DistributionInfo(
                symbol: symbol.uppercased(),
                distributionRate: annualDividendRate > 0 ? annualDividendRate : nil,
                distributionYieldPercent: nil, // We don't have stock price to calculate yield
                distributionFrequency: frequency,
                lastExDate: lastExDate,
                lastPaymentDate: nil, // Finnhub doesn't provide pay dates in this endpoint
                fullName: nil
            )
            
        } catch {
            // Try to parse error response
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorData["error"] as? String {
                throw StockPriceService.APIError.networkError(NSError(
                    domain: "FinnhubError", 
                    code: 400, 
                    userInfo: [NSLocalizedDescriptionKey: "Finnhub Error: \(errorMessage)"]
                ))
            }
            
            throw StockPriceService.APIError.noData
        }
    }
    
    private func determineDividendFrequency(count: Int) -> String {
        switch count {
        case 1:
            return "Annual"
        case 2:
            return "Semi-Annual"
        case 4:
            return "Quarterly"
        case 12:
            return "Monthly"
        default:
            if count > 0 {
                return "Variable"
            } else {
                return "None"
            }
        }
    }
    
    private func dateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }
    
    private func enforceRateLimit() async throws {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        
        if timeSinceLastRequest < minRequestInterval {
            let sleepTime = minRequestInterval - timeSinceLastRequest
            try await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
        }
        
        lastRequestTime = Date()
    }
    
    // MARK: - Usage Information
    
    func getUsageInfo() -> (requestsUsed: Int, perSecondLimit: Int, windowResetsAt: Date) {
        // Finnhub doesn't provide detailed usage info via API in free tier
        // We'll provide estimated info based on our rate limiting
        let requestsUsed = lastRequestTime > Date(timeIntervalSince1970: 0) ? 1 : 0
        let perSecondLimit = 1 // 1 request per second based on our rate limiting
        let windowResetsAt = Date().addingTimeInterval(60) // Next minute
        
        return (requestsUsed: requestsUsed, perSecondLimit: perSecondLimit, windowResetsAt: windowResetsAt)
    }
}

// MARK: - Finnhub Dividend Response Models

struct FinnhubDividendEntry: Codable {
    let amount: Double
    let date: Date
    let currency: String?
    let adjustedAmount: Double?
    let payDate: String?
    let recordDate: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        amount = try container.decode(Double.self, forKey: .amount)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        adjustedAmount = try container.decodeIfPresent(Double.self, forKey: .adjustedAmount)
        payDate = try container.decodeIfPresent(String.self, forKey: .payDate)
        recordDate = try container.decodeIfPresent(String.self, forKey: .recordDate)
        
        // Parse date from string
        let dateString = try container.decode(String.self, forKey: .date)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        guard let parsedDate = formatter.date(from: dateString) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid date format: \(dateString)"
                )
            )
        }
        
        date = parsedDate
    }
    
    private enum CodingKeys: String, CodingKey {
        case amount, date, currency, adjustedAmount, payDate, recordDate
    }
}