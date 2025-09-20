import Foundation
import CoreData
import Combine

/// Service for calculating portfolio dividend information with caching
@MainActor
class DividendCalculationService: ObservableObject {
    
    // MARK: - Properties
    
    private let dividendManager = DividendManager()
    private var cache: [String: (result: PortfolioDividendInfo, timestamp: Date)] = [:]
    private let cacheValidityInterval: TimeInterval = 600 // 10 minutes cache
    
    // MARK: - Public Methods
    
    /// Calculate annual dividend information for a portfolio
    func calculateAnnualDividends(for holdings: [Holding]) async -> PortfolioDividendInfo {
        let portfolioKey = generatePortfolioKey(from: holdings)
        
        // Check cache first
        if let cachedData = cache[portfolioKey],
           Date().timeIntervalSince(cachedData.timestamp) < cacheValidityInterval {
            return cachedData.result
        }
        
        // Calculate dividend information
        let dividendInfo = await performDividendCalculations(for: holdings)
        
        // Cache the result
        cache[portfolioKey] = (result: dividendInfo, timestamp: Date())
        
        return dividendInfo
    }
    
    /// Force refresh dividend calculations, bypassing cache
    func refreshDividendCalculations(for holdings: [Holding]) async -> PortfolioDividendInfo {
        let portfolioKey = generatePortfolioKey(from: holdings)
        
        // Clear cache for this portfolio
        cache.removeValue(forKey: portfolioKey)
        
        // Calculate fresh dividend information
        let dividendInfo = await performDividendCalculations(for: holdings)
        
        // Cache the new result
        cache[portfolioKey] = (result: dividendInfo, timestamp: Date())
        
        return dividendInfo
    }
    
    /// Clear the dividend calculation cache
    func clearCache() {
        cache.removeAll()
    }
    
    /// Force refresh all dividend data, bypassing both cache and daily limits
    func forceRefreshAllDividends(for holdings: [Holding]) async -> PortfolioDividendInfo {
        print("🔄 [DIVIDEND FORCE REFRESH] Force refreshing all dividend data...")
        
        // Clear local cache
        cache.removeAll()
        
        // Clear dividend manager cache and daily limits
        dividendManager.clearCache()
        
        // Force refresh dividend calculations
        return await performDividendCalculations(for: holdings)
    }
    
    // MARK: - Private Methods
    
    private func performDividendCalculations(for holdings: [Holding]) async -> PortfolioDividendInfo {
        var totalAnnualDividends: Decimal = 0
        var dividendPayingStocks = 0
        var totalPortfolioValue: Decimal = 0
        
        for holding in holdings {
            guard let stock = holding.stock else { continue }
            
            let quantity = Decimal(holding.quantity)
            let currentPrice = stock.effectiveCurrentPrice ?? 0
            let holdingValue = currentPrice * quantity
            totalPortfolioValue += holdingValue
            
            // Get the latest dividend information for this stock
            let annualDividendPerShare = await getAnnualDividendPerShare(for: stock)
            
            if annualDividendPerShare > 0 {
                let holdingAnnualDividends = annualDividendPerShare * quantity
                totalAnnualDividends += holdingAnnualDividends
                dividendPayingStocks += 1
                
                print("📈 [DIVIDEND CALC] \(stock.symbol ?? "Unknown"): \(quantity) shares × $\(annualDividendPerShare) = $\(holdingAnnualDividends)")
            }
        }
        
        // Calculate portfolio dividend yield
        let portfolioYield = totalPortfolioValue > 0 ? (totalAnnualDividends / totalPortfolioValue) * 100 : 0
        
        print("📊 [DIVIDEND CALC] Portfolio Summary:")
        print("📊 [DIVIDEND CALC] Total Annual Dividends: $\(totalAnnualDividends)")
        print("📊 [DIVIDEND CALC] Total Portfolio Value: $\(totalPortfolioValue)")
        print("📊 [DIVIDEND CALC] Portfolio Yield: \(portfolioYield)%")
        print("📊 [DIVIDEND CALC] Dividend-Paying Stocks: \(dividendPayingStocks)/\(holdings.count)")
        
        return PortfolioDividendInfo(
            totalAnnualDividends: totalAnnualDividends,
            portfolioYieldPercent: portfolioYield,
            dividendPayingStocks: dividendPayingStocks,
            totalStocks: holdings.count
        )
    }
    
    private func getAnnualDividendPerShare(for stock: Stock) async -> Decimal {
        guard let symbol = stock.symbol else { 
            print("⚠️ [DIVIDEND CALC] Stock has no symbol, skipping dividend calculation")
            return 0 
        }
        
        print("🔍 [DIVIDEND CALC] Getting annual dividend for \(symbol)...")
        
        // First check if we have dividend data in Core Data
        let dividends = dividendManager.getDividends(for: stock)
        
        if let latestDividend = dividends.first,
           let annualizedAmount = latestDividend.annualizedAmount as Decimal?,
           annualizedAmount > 0 {
            print("✅ [DIVIDEND CALC] Found dividend in Core Data for \(symbol): $\(annualizedAmount)")
            return annualizedAmount
        }
        
        print("📊 [DIVIDEND CALC] No Core Data dividend for \(symbol), fetching from API...")
        
        // If no Core Data dividend, try to fetch from API
        let distributionInfo = await dividendManager.fetchDistributionInfo(symbol: symbol)
        
        if let annualRate = distributionInfo.distributionRate,
           annualRate > 0 {
            print("✅ [DIVIDEND CALC] API returned dividend for \(symbol): $\(annualRate)")
            // Save to Core Data for future use
            await dividendManager.saveDividendToCore(distributionInfo: distributionInfo, for: stock)
            return Decimal(annualRate)
        } else {
            print("❌ [DIVIDEND CALC] No dividend data found for \(symbol) (API returned: rate=\(distributionInfo.distributionRate ?? 0))")
        }
        
        return 0
    }
    
    private func generatePortfolioKey(from holdings: [Holding]) -> String {
        let sortedHoldings = holdings.sorted { ($0.stock?.symbol ?? "") < ($1.stock?.symbol ?? "") }
        let keyComponents = sortedHoldings.compactMap { holding -> String? in
            guard let symbol = holding.stock?.symbol else { return nil }
            return "\(symbol):\(holding.quantity)"
        }
        return keyComponents.joined(separator: ",")
    }
}

// MARK: - Supporting Types

/// Portfolio dividend calculation results
struct PortfolioDividendInfo {
    let totalAnnualDividends: Decimal
    let portfolioYieldPercent: Decimal
    let dividendPayingStocks: Int
    let totalStocks: Int
    
    var hasDividends: Bool {
        return totalAnnualDividends > 0
    }
    
    var dividendCoverage: String {
        if totalStocks == 0 { return "0/0" }
        return "\(dividendPayingStocks)/\(totalStocks)"
    }
}