import Foundation

/**
 * Historical Price Data Model
 * 
 * Unified data model for historical stock price data that's compatible
 * with the Core Data PriceHistory entity and provides a consistent
 * interface across different API providers.
 * 
 * Sendable-compliant for Swift 6.0 concurrency safety.
 */
struct HistoricalPrice: Codable, Equatable, Sendable {
    let date: Date
    let openPrice: Decimal
    let highPrice: Decimal  
    let lowPrice: Decimal
    let closePrice: Decimal
    let volume: Int64
    let symbol: String
    
    // Additional metadata for tracking and debugging
    let dataSource: String
    let lastUpdated: Date
    
    init(date: Date, 
         openPrice: Decimal, 
         highPrice: Decimal, 
         lowPrice: Decimal, 
         closePrice: Decimal, 
         volume: Int64, 
         symbol: String, 
         dataSource: String) {
        self.date = date
        self.openPrice = openPrice
        self.highPrice = highPrice
        self.lowPrice = lowPrice
        self.closePrice = closePrice
        self.volume = volume
        self.symbol = symbol.uppercased()
        self.dataSource = dataSource
        self.lastUpdated = Date()
    }
}

// MARK: - Validation Extensions

extension HistoricalPrice {
    /// Validates if the historical price data is valid
    var isValid: Bool {
        return !symbol.isEmpty &&
               openPrice > 0 &&
               highPrice > 0 &&
               lowPrice > 0 &&
               closePrice > 0 &&
               volume >= 0 &&
               highPrice >= lowPrice &&
               (openPrice >= lowPrice && openPrice <= highPrice) &&
               (closePrice >= lowPrice && closePrice <= highPrice)
    }
    
    /// Formatted price strings for display
    var formattedOpenPrice: String {
        return formatPrice(openPrice)
    }
    
    var formattedHighPrice: String {
        return formatPrice(highPrice)
    }
    
    var formattedLowPrice: String {
        return formatPrice(lowPrice)
    }
    
    var formattedClosePrice: String {
        return formatPrice(closePrice)
    }
    
    var formattedVolume: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: volume)) ?? "0"
    }
    
    private func formatPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: price as NSDecimalNumber) ?? "$0.00"
    }
}

// MARK: - Core Data Compatibility

extension HistoricalPrice {
    /// Converts to Core Data PriceHistory entity attributes
    func toCoreDataDictionary() -> [String: Any] {
        return [
            "date": date,
            "openPrice": openPrice,
            "highPrice": highPrice,
            "lowPrice": lowPrice,
            "closePrice": closePrice,
            "volume": volume,
            "priceHistoryID": UUID()
        ]
    }
    
    /// Creates HistoricalPrice from Core Data PriceHistory entity
    init?(from priceHistory: NSManagedObject, symbol: String, dataSource: String = "CoreData") {
        guard let date = priceHistory.value(forKey: "date") as? Date,
              let openPriceNS = priceHistory.value(forKey: "openPrice") as? NSDecimalNumber,
              let highPriceNS = priceHistory.value(forKey: "highPrice") as? NSDecimalNumber,
              let lowPriceNS = priceHistory.value(forKey: "lowPrice") as? NSDecimalNumber,
              let closePriceNS = priceHistory.value(forKey: "closePrice") as? NSDecimalNumber,
              let volume = priceHistory.value(forKey: "volume") as? Int64 else {
            return nil
        }
        
        let openPrice = openPriceNS.decimalValue
        let highPrice = highPriceNS.decimalValue
        let lowPrice = lowPriceNS.decimalValue
        let closePrice = closePriceNS.decimalValue
        
        self.init(
            date: date,
            openPrice: openPrice,
            highPrice: highPrice,
            lowPrice: lowPrice,
            closePrice: closePrice,
            volume: volume,
            symbol: symbol,
            dataSource: dataSource
        )
    }
}

// MARK: - Date Range Queries

extension HistoricalPrice {
    static func dateRange(from startDate: Date, to endDate: Date) -> ClosedRange<Date> {
        return startDate...endDate
    }
    
    func isInDateRange(_ range: ClosedRange<Date>) -> Bool {
        return range.contains(date)
    }
}

// MARK: - Common Time Periods

extension HistoricalPrice {
    enum TimePeriod: String, CaseIterable, Sendable {
        case oneWeek = "7d"
        case oneMonth = "1mo"
        case threeMonths = "3mo"
        case sixMonths = "6mo" 
        case oneYear = "1y"
        case twoYears = "2y"
        case fiveYears = "5y"
        case tenYears = "10y"
        case max = "max"
        
        var description: String {
            switch self {
            case .oneWeek: return "1 Week"
            case .oneMonth: return "1 Month"
            case .threeMonths: return "3 Months"
            case .sixMonths: return "6 Months"
            case .oneYear: return "1 Year"
            case .twoYears: return "2 Years"
            case .fiveYears: return "5 Years"
            case .tenYears: return "10 Years"
            case .max: return "All Time"
            }
        }
        
        var startDate: Date {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .oneWeek:
                return calendar.date(byAdding: .day, value: -7, to: now) ?? now
            case .oneMonth:
                return calendar.date(byAdding: .month, value: -1, to: now) ?? now
            case .threeMonths:
                return calendar.date(byAdding: .month, value: -3, to: now) ?? now
            case .sixMonths:
                return calendar.date(byAdding: .month, value: -6, to: now) ?? now
            case .oneYear:
                return calendar.date(byAdding: .year, value: -1, to: now) ?? now
            case .twoYears:
                return calendar.date(byAdding: .year, value: -2, to: now) ?? now
            case .fiveYears:
                return calendar.date(byAdding: .year, value: -5, to: now) ?? now
            case .tenYears:
                return calendar.date(byAdding: .year, value: -10, to: now) ?? now
            case .max:
                return calendar.date(byAdding: .year, value: -50, to: now) ?? now
            }
        }
        
        var endDate: Date {
            return Date()
        }
    }
}

import CoreData