import Foundation
import CoreData
import SwiftUI

@MainActor
class TextExportManager: ObservableObject {
    private let portfolioManager = PortfolioManager()
    private let dividendCalculationService = DividendCalculationService()
    
    // MARK: - Public Methods
    
    /// Generate a formatted text summary of the portfolio
    func generatePortfolioTextSummary(_ portfolio: Portfolio) async -> String {
        guard let holdings = portfolio.holdings as? Set<Holding> else {
            return generateEmptyPortfolioSummary(portfolio)
        }
        
        let holdingsArray = Array(holdings).sorted { 
            ($0.stock?.symbol ?? "") < ($1.stock?.symbol ?? "") 
        }
        
        // Get dividend information
        let dividendInfo = await dividendCalculationService.calculateAnnualDividends(for: holdingsArray)
        
        // Build the text summary
        var summary = ""
        
        // Header
        summary += generateHeader(portfolio)
        summary += "\n\n"
        
        // Portfolio Overview
        summary += generatePortfolioOverview(portfolio, holdings: holdingsArray, dividendInfo: dividendInfo)
        summary += "\n\n"
        
        // Individual Holdings
        if !holdingsArray.isEmpty {
            summary += generateHoldingsSection(holdingsArray)
            summary += "\n\n"
        }
        
        // Dividend Summary
        if dividendInfo.hasDividends {
            summary += generateDividendSummary(dividendInfo)
            summary += "\n\n"
        }
        
        // Footer
        summary += generateFooter()
        
        return summary
    }
    
    // MARK: - Private Methods
    
    private func generateHeader(_ portfolio: Portfolio) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        
        var header = "📊 PORTFOLIO SUMMARY\n"
        header += "═══════════════════════════════════════\n"
        header += "Portfolio: \(portfolio.name ?? "Unnamed Portfolio")\n"
        header += "Generated: \(formatter.string(from: Date()))\n"
        
        if let createdDate = portfolio.createdDate {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            header += "Created: \(formatter.string(from: createdDate))"
        }
        
        return header
    }
    
    private func generatePortfolioOverview(_ portfolio: Portfolio, holdings: [Holding], dividendInfo: PortfolioDividendInfo) -> String {
        let totalValue = portfolioManager.calculatePortfolioValue(portfolio)
        let holdingsCount = holdings.count
        
        // Calculate total portfolio gain/loss and percentage
        let totalPurchaseValue = holdings.reduce(Decimal(0)) { total, holding in
            let purchasePrice = holding.pricePerShare?.decimalValue ?? 0
            let quantity = Decimal(holding.quantity)
            return total + (purchasePrice * quantity)
        }
        
        let totalGainLoss = totalValue - totalPurchaseValue
        let totalGainLossPercentage = totalPurchaseValue > 0 ? ((totalGainLoss / totalPurchaseValue) * 100) : 0
        
        var overview = "💼 PORTFOLIO OVERVIEW\n"
        overview += "───────────────────────────────────────\n"
        overview += "Total Value: \(formatCurrency(totalValue))\n"
        overview += "Total Purchase Value: \(formatCurrency(totalPurchaseValue))\n"
        
        let gainLossSymbol = totalGainLoss >= 0 ? "📈" : "📉"
        let gainLossPrefix = totalGainLoss >= 0 ? "+" : ""
        overview += "\(gainLossSymbol) Total Gain/Loss: \(gainLossPrefix)\(formatCurrency(totalGainLoss)) (\(gainLossPrefix)\(formatPercentage(totalGainLossPercentage)))\n"
        
        overview += "Total Holdings: \(holdingsCount) position\(holdingsCount == 1 ? "" : "s")\n"
        
        if dividendInfo.hasDividends {
            overview += "Annual Dividends: \(formatCurrency(dividendInfo.totalAnnualDividends))\n"
            overview += "Portfolio Yield: \(formatPercentage(dividendInfo.portfolioYieldPercent))\n"
            overview += "Dividend Coverage: \(dividendInfo.dividendCoverage) stocks"
        } else {
            overview += "Annual Dividends: No dividend data available"
        }
        
        return overview
    }
    
    private func generateHoldingsSection(_ holdings: [Holding]) -> String {
        var section = "📈 INDIVIDUAL HOLDINGS\n"
        section += "───────────────────────────────────────\n"
        
        for (index, holding) in holdings.enumerated() {
            section += generateHoldingDetail(holding, index: index + 1)
            if index < holdings.count - 1 {
                section += "\n"
            }
        }
        
        return section
    }
    
    private func generateHoldingDetail(_ holding: Holding, index: Int) -> String {
        guard let stock = holding.stock else {
            return "\(index). Unknown Stock - Invalid data"
        }
        
        let symbol = stock.symbol ?? "UNKNOWN"
        let companyName = stock.name ?? "Unknown Company"
        let quantity = holding.quantity
        let currentPrice = stock.effectiveCurrentPrice ?? 0
        let purchasePrice = holding.pricePerShare?.decimalValue ?? 0
        let currentValue = currentPrice * Decimal(quantity)
        
        // Use the same calculation utility as UI for consistency
        let totalGainLoss = HoldingGainLossCalculator.calculateGainLoss(for: holding, context: "EXPORT")
        
        // Also calculate with raw values to compare
        let rawGainLoss = HoldingGainLossCalculator.calculateGainLossWithRawValues(
            currentPrice: currentPrice,
            purchasePrice: purchasePrice, 
            quantity: Int32(quantity),
            symbol: symbol,
            context: "EXPORT-RAW"
        )
        let gainLossPercent = purchasePrice > 0 ? ((currentPrice - purchasePrice) / purchasePrice) * 100 : 0
        
        var detail = "\(index). \(symbol)"
        if !companyName.isEmpty && companyName != "Unknown Company" {
            detail += " - \(companyName)"
        }
        detail += "\n"
        
        detail += "   Quantity: \(formatQuantity(Int32(quantity))) shares\n"
        detail += "   Current Price: \(formatCurrency(currentPrice))\n"
        detail += "   Purchase Price: \(formatCurrency(purchasePrice))\n"
        detail += "   Current Value: \(formatCurrency(currentValue))\n"
        
        let gainLossSymbol = totalGainLoss >= 0 ? "📈" : "📉"
        let gainLossPrefix = totalGainLoss >= 0 ? "+" : ""
        detail += "   \(gainLossSymbol) Gain/Loss: \(gainLossPrefix)\(formatCurrency(totalGainLoss)) (\(gainLossPrefix)\(formatPercentage(gainLossPercent)))\n"
        
        if let purchaseDate = holding.purchaseDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            detail += "   Purchase Date: \(formatter.string(from: purchaseDate))"
        }
        
        return detail
    }
    
    private func generateDividendSummary(_ dividendInfo: PortfolioDividendInfo) -> String {
        var summary = "💰 DIVIDEND SUMMARY\n"
        summary += "───────────────────────────────────────\n"
        summary += "Total Annual Dividends: \(formatCurrency(dividendInfo.totalAnnualDividends))\n"
        summary += "Portfolio Dividend Yield: \(formatPercentage(dividendInfo.portfolioYieldPercent))\n"
        summary += "Dividend-Paying Stocks: \(dividendInfo.dividendCoverage)\n"
        
        let monthlyDividends = dividendInfo.totalAnnualDividends / 12
        let quarterlyDividends = dividendInfo.totalAnnualDividends / 4
        
        summary += "\nProjected Income:\n"
        summary += "• Monthly: \(formatCurrency(monthlyDividends))\n"
        summary += "• Quarterly: \(formatCurrency(quarterlyDividends))\n"
        summary += "• Annual: \(formatCurrency(dividendInfo.totalAnnualDividends))"
        
        return summary
    }
    
    private func generateFooter() -> String {
        return """
        ═══════════════════════════════════════
        
        📱 Generated by My Asset Portfolio App
        💡 This summary is for informational purposes only
        📊 Market data may be delayed or estimated
        
        Note: All calculations are based on current market
        prices and available dividend information. Past
        performance does not guarantee future results.
        """
    }
    
    private func generateEmptyPortfolioSummary(_ portfolio: Portfolio) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        
        return """
        📊 PORTFOLIO SUMMARY
        ═══════════════════════════════════════
        Portfolio: \(portfolio.name ?? "Unnamed Portfolio")
        Generated: \(formatter.string(from: Date()))
        
        💼 PORTFOLIO OVERVIEW
        ───────────────────────────────────────
        Total Value: \(formatCurrency(0))
        Total Holdings: 0 positions
        Annual Dividends: No holdings
        
        📈 INDIVIDUAL HOLDINGS
        ───────────────────────────────────────
        No holdings in this portfolio.
        
        Add some stocks to see detailed information here!
        
        ═══════════════════════════════════════
        
        📱 Generated by My Asset Portfolio App
        """
    }
    
    // MARK: - Formatting Helpers
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = 0  // No decimal places as requested
        formatter.minimumFractionDigits = 0
        
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0"
    }
    
    private func formatPercentage(_ percentage: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        
        let percentValue = NSDecimalNumber(decimal: percentage / 100)
        return formatter.string(from: percentValue) ?? "0.00%"
    }
    
    private func formatQuantity(_ quantity: Int32) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        
        return formatter.string(from: NSNumber(value: quantity)) ?? "0"
    }
}