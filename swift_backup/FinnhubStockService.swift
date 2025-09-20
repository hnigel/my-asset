import Foundation

/**
 * Finnhub Stock Service
 * 
 * Provides real-time stock price data from Finnhub API.
 * Finnhub offers high-quality financial data with good rate limits.
 */
class FinnhubStockService: StockPriceProvider {
    
    // MARK: - Properties
    
    let providerName = "Finnhub"
    private let apiKeyManager = APIKeyManager.shared
    var isAvailable: Bool { 
        apiKeyManager.getAPIKey(for: .finnhub) != nil
    }
    
    var name: String { "Finnhub" }
    var priority: Int { 4 } // Lower priority - paid API, use as backup
    
    private let baseURL = "https://finnhub.io/api/v1"
    private let session = URLSession.shared
    
    // Rate limiting (Finnhub free tier: 60 API calls/minute)
    private var lastRequestTime = Date(timeIntervalSince1970: 0)
    private let minRequestInterval: TimeInterval = 1.0 // 1 second between requests
    
    // MARK: - Public Methods
    
    func fetchStockPrice(symbol: String) async throws -> StockQuote {
        // Rate limiting
        try await enforceRateLimit()
        
        guard let apiKey = apiKeyManager.getAPIKey(for: .finnhub) else {
            throw StockPriceService.APIError.networkError(NSError(
                domain: "FinnhubAuth", 
                code: 401, 
                userInfo: [NSLocalizedDescriptionKey: "Finnhub API key not configured"]
            ))
        }
        
        // Finnhub expects clean symbol format (no exchange suffix)
        let cleanSymbol = cleanFinnhubSymbol(symbol)
        
        // Use quote endpoint for real-time price
        guard let url = URL(string: "\(baseURL)/quote?symbol=\(cleanSymbol)&token=\(apiKey)") else {
            throw StockPriceService.APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("MyAsset/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15.0
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StockPriceService.APIError.networkError(NSError(domain: "NoHTTPResponse", code: 0))
        }
        
        switch httpResponse.statusCode {
        case 200:
            return try await parseFinnhubQuoteResponse(data: data, symbol: cleanSymbol)
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
    
    private func parseFinnhubQuoteResponse(data: Data, symbol: String) async throws -> StockQuote {
        do {
            let quoteResponse = try JSONDecoder().decode(FinnhubQuoteResponse.self, from: data)
            
            // Check if we got valid price data
            guard quoteResponse.c > 0 else {
                throw StockPriceService.APIError.noData
            }
            
            // Get company name from profile endpoint if needed
            let companyName = await fetchCompanyName(symbol: symbol) ?? "\(symbol) Corporation"
            
            let quote = StockQuote(
                symbol: symbol,
                price: quoteResponse.c, // Current price
                companyName: companyName,
                lastUpdated: Date(timeIntervalSince1970: TimeInterval(quoteResponse.t))
            )
            
            return quote
            
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
    
    private func fetchCompanyName(symbol: String) async -> String? {
        guard let apiKey = apiKeyManager.getAPIKey(for: .finnhub),
              let url = URL(string: "\(baseURL)/stock/profile2?symbol=\(symbol)&token=\(apiKey)") else {
            return nil
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            let profile = try JSONDecoder().decode(FinnhubCompanyProfile.self, from: data)
            return profile.name
            
        } catch {
            return nil
        }
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

// MARK: - Finnhub Response Models

public struct FinnhubQuoteResponse: Codable {
    let c: Double  // Current price
    let d: Double? // Change
    let dp: Double? // Percent change
    let h: Double  // High price of the day
    let l: Double  // Low price of the day
    let o: Double  // Open price of the day
    let pc: Double // Previous close price
    let t: Int     // Timestamp
}

public struct FinnhubCompanyProfile: Codable {
    let name: String
    let ticker: String?
    let exchange: String?
    let ipo: String?
    let marketCapitalization: Double?
    let shareOutstanding: Double?
    let logo: String?
    let phone: String?
    let weburl: String?
    let finnhubIndustry: String?
}