import Foundation

class AlphaVantageStockService: StockPriceProvider {
    let providerName = "Alpha Vantage"
    
    private let baseURL = "https://www.alphavantage.co/query"
    private let session = URLSession.shared
    private let apiKeyManager = APIKeyManager.shared
    
    // Rate limiting for Alpha Vantage (25 requests per day for free tier)
    private var requestCount = 0
    private var lastResetDate = Date()
    private let maxRequestsPerDay = 25
    
    var isAvailable: Bool {
        return apiKeyManager.hasAPIKey(for: .alphaVantage)
    }
    
    func fetchStockPrice(symbol: String) async throws -> StockQuote {
        // Check rate limits
        try checkRateLimit()
        
        guard let apiKey = apiKeyManager.getAPIKey(for: .alphaVantage) else {
            throw ProviderError.apiKeyMissing
        }
        
        guard let url = URL(string: "\(baseURL)?function=GLOBAL_QUOTE&symbol=\(symbol)&apikey=\(apiKey)") else {
            throw ProviderError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30.0 // Alpha Vantage can be slower
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProviderError.networkError(NSError(domain: "NoHTTPResponse", code: 0, userInfo: nil))
            }
            
            switch httpResponse.statusCode {
            case 200:
                break
            case 400, 401, 403:
                throw ProviderError.apiKeyMissing
            case 429:
                throw ProviderError.rateLimitExceeded
            default:
                throw ProviderError.networkError(NSError(domain: "HTTPError", code: httpResponse.statusCode))
            }
            
            // Increment rate limit counter
            incrementRequestCount()
            
            let alphaVantageResponse = try JSONDecoder().decode(AlphaVantageQuoteResponse.self, from: data)
            
            // Parse Alpha Vantage price format
            guard let currentPrice = Double(alphaVantageResponse.globalQuote.price), currentPrice > 0 else {
                throw ProviderError.invalidSymbol(symbol)
            }
            
            return StockQuote(
                symbol: symbol,
                price: currentPrice,
                companyName: "\(symbol) Corporation", // Alpha Vantage GLOBAL_QUOTE doesn't include company name
                lastUpdated: Date()
            )
            
        } catch let error as ProviderError {
            throw error
        } catch {
            throw ProviderError.networkError(error)
        }
    }
    
    // MARK: - Rate Limiting
    
    private func checkRateLimit() throws {
        let calendar = Calendar.current
        let currentDate = Date()
        
        // Reset counter if it's a new day
        if !calendar.isDate(lastResetDate, inSameDayAs: currentDate) {
            requestCount = 0
            lastResetDate = currentDate
        }
        
        // Check if we've exceeded the daily limit
        if requestCount >= maxRequestsPerDay {
            throw ProviderError.rateLimitExceeded
        }
    }
    
    private func incrementRequestCount() {
        requestCount += 1
    }
    
    // Get usage info for monitoring
    func getUsageInfo() -> (requestsUsed: Int, dailyLimit: Int, resetsAt: Date) {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: lastResetDate) ?? Date()
        return (requestCount, maxRequestsPerDay, tomorrow)
    }
}