import Foundation

/**
 * EODHD Dividend Service
 * 
 * Provides dividend data from EODHD (End Of Day Historical Data) API.
 * EODHD offers comprehensive dividend data for stocks worldwide.
 */
class EODHDDividendService: DividendProvider {
    
    // MARK: - Properties
    
    let providerName = "EODHD"
    private let apiKeyManager = APIKeyManager.shared
    var isAvailable: Bool { 
        apiKeyManager.getAPIKey(for: .eodhd) != nil
    }
    
    private let baseURL = "https://eodhistoricaldata.com/api"
    private let session = URLSession.shared
    
    // Rate limiting (EODHD allows 20 requests per second)
    private var lastRequestTime = Date(timeIntervalSince1970: 0)
    private let minRequestInterval: TimeInterval = 0.05 // 50ms between requests
    
    // MARK: - Public Methods
    
    func fetchDividendInfo(symbol: String) async throws -> DistributionInfo {
        // Rate limiting
        try await enforceRateLimit()
        
        guard let apiKey = apiKeyManager.getAPIKey(for: .eodhd) else {
            throw ProviderError.apiKeyMissing
        }
        
        // EODHD expects US symbols with .US suffix for US stocks
        let formattedSymbol = formatSymbolForEODHD(symbol)
        
        // Fetch dividend data from EODHD
        guard let url = URL(string: "\(baseURL)/div/\(formattedSymbol)?api_token=\(apiKey)&fmt=json") else {
            throw ProviderError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("MyAsset/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30.0
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.networkError(NSError(domain: "NoHTTPResponse", code: 0, userInfo: nil))
        }
        
        switch httpResponse.statusCode {
        case 200:
            return try parseEODHDDividendResponse(data: data, symbol: symbol)
        case 401:
            throw ProviderError.networkError(NSError(
                domain: "EODHDAuth", 
                code: 401, 
                userInfo: [NSLocalizedDescriptionKey: "EODHD API key invalid or expired"]
            ))
        case 404:
            throw ProviderError.noData
        case 429:
            throw ProviderError.rateLimitExceeded
        default:
            throw ProviderError.networkError(NSError(
                domain: "EODHDError", 
                code: httpResponse.statusCode, 
                userInfo: [NSLocalizedDescriptionKey: "EODHD API error: \(httpResponse.statusCode)"]
            ))
        }
    }
    
    // MARK: - Private Methods
    
    private func formatSymbolForEODHD(_ symbol: String) -> String {
        let cleanSymbol = symbol.uppercased()
        
        // Add .US suffix for US stocks if not already present
        if !cleanSymbol.contains(".") {
            return "\(cleanSymbol).US"
        }
        
        return cleanSymbol
    }
    
    private func parseEODHDDividendResponse(data: Data, symbol: String) throws -> DistributionInfo {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(eodhDateFormatter())
        
        do {
            let dividends = try decoder.decode([EODHDDividendEntry].self, from: data)
            
            // Calculate metrics from historical dividend data
            let recentDividends = dividends.prefix(12) // Last 12 dividends (up to 3 years for quarterly)
            
            var annualDividendRate: Double = 0
            var lastExDate: Date? = nil
            var frequency: String? = nil
            
            if !recentDividends.isEmpty {
                // Get the most recent ex-dividend date
                lastExDate = recentDividends.first?.date
                
                // Calculate annual dividend rate
                let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
                let recentYearDividends = recentDividends.filter { $0.date >= oneYearAgo }
                annualDividendRate = recentYearDividends.reduce(0) { $0 + $1.value }
                
                // Determine frequency based on number of dividends in recent year
                let dividendCount = recentYearDividends.count
                frequency = determineDividendFrequency(count: dividendCount)
            }
            
            return DistributionInfo(
                symbol: symbol.uppercased(),
                distributionRate: annualDividendRate > 0 ? annualDividendRate : nil,
                distributionYieldPercent: nil, // We don't have stock price to calculate yield
                distributionFrequency: frequency,
                lastExDate: lastExDate,
                lastPaymentDate: nil, // EODHD doesn't provide pay dates in this endpoint
                fullName: nil
            )
        } catch {
            // Try to parse as error response
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorResponse["message"] as? String {
                throw ProviderError.decodingError("EODHD Error: \(message)")
            }
            
            throw ProviderError.noData
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
            return "Variable"
        }
    }
    
    private func eodhDateFormatter() -> DateFormatter {
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
}

// MARK: - EODHD Response Models

struct EODHDDividendEntry: Codable {
    let date: Date
    let value: Double
    let unadjusted_value: Double?
    let currency: String?
    let declaration_date: String?
    let record_date: String?
    let payment_date: String?
    
    private enum CodingKeys: String, CodingKey {
        case date, value, unadjusted_value, currency, declaration_date, record_date, payment_date
    }
}

