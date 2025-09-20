import Foundation

class NasdaqStockService: StockPriceProvider {
    let providerName = "Nasdaq"
    let isAvailable = true
    
    private let baseURL = "https://api.nasdaq.com/api/quote"
    private let session = URLSession.shared
    
    func fetchStockPrice(symbol: String) async throws -> StockQuote {
        guard let url = URL(string: "\(baseURL)/\(symbol)/info?assetclass=stocks") else {
            throw ProviderError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://www.nasdaq.com", forHTTPHeaderField: "Referer")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.timeoutInterval = 10.0
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProviderError.networkError(NSError(domain: "NoHTTPResponse", code: 0))
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
            
            let nasdaqResponse = try JSONDecoder().decode(NasdaqQuoteResponse.self, from: data)
            
            guard nasdaqResponse.status.rCode == 200 else {
                throw ProviderError.invalidSymbol(symbol)
            }
            
            // Parse price from Nasdaq format (e.g., "$177.33")
            let priceString = nasdaqResponse.data.primaryData.lastSalePrice
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: ",", with: "")
            
            guard let currentPrice = Double(priceString), currentPrice > 0 else {
                throw ProviderError.invalidSymbol(symbol)
            }
            
            return StockQuote(
                symbol: symbol,
                price: currentPrice,
                companyName: nasdaqResponse.data.companyName.replacingOccurrences(of: " Common Stock", with: ""),
                lastUpdated: Date()
            )
            
        } catch let error as ProviderError {
            throw error
        } catch {
            throw ProviderError.networkError(error)
        }
    }
}