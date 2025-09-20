import Foundation

// MARK: - Provider Protocols

protocol StockPriceProvider {
    func fetchStockPrice(symbol: String) async throws -> StockQuote
    var providerName: String { get }
    var isAvailable: Bool { get }
}

protocol DividendProvider {
    func fetchDividendInfo(symbol: String) async throws -> DistributionInfo
    var providerName: String { get }
    var isAvailable: Bool { get }
}

// MARK: - Provider Errors

enum ProviderError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(String)
    case rateLimitExceeded
    case networkError(Error)
    case invalidSymbol(String)
    case providerUnavailable
    case apiKeyMissing
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for request"
        case .noData:
            return "No data received from provider"
        case .decodingError(let details):
            return "Failed to parse data: \(details)"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidSymbol(let symbol):
            return "Invalid or unknown symbol: \(symbol)"
        case .providerUnavailable:
            return "Provider is currently unavailable"
        case .apiKeyMissing:
            return "API key is required but not configured"
        }
    }
}

// MARK: - Provider Priority

enum ProviderPriority: Int, CaseIterable {
    case primary = 1
    case secondary = 2
    case tertiary = 3
    
    var description: String {
        switch self {
        case .primary: return "Primary"
        case .secondary: return "Secondary" 
        case .tertiary: return "Tertiary"
        }
    }
}