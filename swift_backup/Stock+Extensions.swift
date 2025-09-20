import Foundation
import CoreData

extension Stock {
    
    // MARK: - Computed Properties for Current Data
    
    /// Returns the current effective price from API data
    var effectiveCurrentPrice: Decimal? {
        return currentPrice?.decimalValue
    }
    
    /// Returns the current effective dividend rate from API data
    var effectiveDividendRate: Decimal? {
        // Get the latest dividend's annualized amount
        guard let dividends = dividends as? Set<Dividend>,
              let latestDividend = dividends.sorted(by: { 
                  ($0.lastUpdated ?? Date.distantPast) > ($1.lastUpdated ?? Date.distantPast) 
              }).first,
              let annualizedAmount = latestDividend.annualizedAmount as Decimal? else {
            return nil
        }
        return annualizedAmount
    }
    
    /// Returns the current effective dividend yield from API data
    var effectiveDividendYield: Decimal? {
        // Get the latest dividend's yield
        guard let dividends = dividends as? Set<Dividend>,
              let latestDividend = dividends.sorted(by: { 
                  ($0.lastUpdated ?? Date.distantPast) > ($1.lastUpdated ?? Date.distantPast) 
              }).first,
              let yieldValue = latestDividend.yield as Decimal? else {
            return nil
        }
        return yieldValue * 100 // Convert to percentage
    }
    
    // MARK: - Data Source Indicators
    
    /// Returns true if the current price is available (from either API or user)
    var hasPriceData: Bool {
        return effectiveCurrentPrice != nil && effectiveCurrentPrice! > 0
    }
    
    /// Returns true if dividend data is available (from either API or user)
    var hasDividendData: Bool {
        guard let dividends = dividends as? Set<Dividend> else { return false }
        return !dividends.isEmpty && dividends.contains { dividend in
            (dividend.annualizedAmount as Decimal? ?? 0) > 0
        }
    }
    
    /// Returns true if any dividend data is user-provided
    var isDividendUserProvided: Bool {
        guard let dividends = dividends as? Set<Dividend> else { return false }
        return dividends.contains { $0.isUserProvided }
    }
    
    /// Returns a description of the price data source
    var priceDataSource: String {
        if let price = currentPrice?.decimalValue, price > 0 {
            return "API"
        } else {
            return "N/A"
        }
    }
    
    /// Returns a description of the dividend data source  
    var dividendDataSource: String {
        // Check if we have dividend records from API
        if let dividends = dividends as? Set<Dividend>, !dividends.isEmpty {
            return "API"
        } else {
            return "N/A"
        }
    }
    
    // MARK: - Manual Data Setting Methods
    
    
    // MARK: - Display Helpers
    
    /// Returns formatted price string with data source indicator
    var formattedPriceWithSource: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        
        if let price = effectiveCurrentPrice {
            let priceString = formatter.string(from: NSDecimalNumber(decimal: price)) ?? "$0.00"
            return priceString
        } else {
            return "N/A"
        }
    }
    
    /// Returns formatted dividend rate string with data source indicator
    var formattedDividendRateWithSource: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        
        if let rate = effectiveDividendRate {
            let rateString = formatter.string(from: NSDecimalNumber(decimal: rate)) ?? "$0.00"
            return rateString
        } else {
            return "N/A"
        }
    }
    
    /// Returns formatted dividend yield string with data source indicator
    var formattedDividendYieldWithSource: String {
        if let yield = effectiveDividendYield {
            let percentage = NSDecimalNumber(decimal: yield).doubleValue
            let sourceIndicator = isDividendUserProvided ? " (Manual)" : ""
            return String(format: "%.2f%%\(sourceIndicator)", percentage)
        } else {
            return "N/A"
        }
    }
    
}