import Foundation

class YahooFinanceStockService: StockPriceProvider {
    let providerName = "Yahoo Finance"
    let isAvailable = true
    
    private let baseURL = "https://query1.finance.yahoo.com/v8/finance/chart"
    private let session = URLSession.shared
    
    func fetchStockPrice(symbol: String) async throws -> StockQuote {
        guard let url = URL(string: "\(baseURL)/\(symbol)") else {
            throw ProviderError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://finance.yahoo.com", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 15.0
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProviderError.networkError(NSError(domain: "NoHTTPResponse", code: 0, userInfo: nil))
            }
            
            switch httpResponse.statusCode {
            case 200:
                break
            case 404:
                throw ProviderError.invalidSymbol(symbol)
            case 429:
                throw ProviderError.rateLimitExceeded
            default:
                throw ProviderError.networkError(NSError(domain: "HTTPError", code: httpResponse.statusCode))
            }
            
            let yahooResponse = try JSONDecoder().decode(YahooFinanceResponse.self, from: data)
            
            guard let result = yahooResponse.chart.result?.first else {
                if let error = yahooResponse.chart.error {
                    throw ProviderError.invalidSymbol("\(symbol): \(error.description)")
                }
                throw ProviderError.noData
            }
            
            let meta = result.meta
            guard let currentPrice = meta.regularMarketPrice, currentPrice > 0 else {
                throw ProviderError.invalidSymbol(symbol)
            }
            
            return StockQuote(
                symbol: symbol,
                price: currentPrice,
                companyName: meta.longName ?? "\(symbol) Corporation",
                lastUpdated: Date()
            )
            
        } catch let error as ProviderError {
            throw error
        } catch {
            throw ProviderError.networkError(error)
        }
    }
}