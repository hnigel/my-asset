import Foundation

// MARK: - Price History Structure
struct PriceHistory {
    let symbol: String
    let prices: [HistoricalPrice]
    let lastUpdated: Date
    
    init(symbol: String, prices: [HistoricalPrice] = [], lastUpdated: Date = Date()) {
        self.symbol = symbol
        self.prices = prices
        self.lastUpdated = lastUpdated
    }
}