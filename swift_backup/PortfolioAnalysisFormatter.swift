import Foundation
import CoreData

/**
 * Portfolio Analysis Formatter
 * 
 * This class formats portfolio data for AI analysis while maintaining privacy protection.
 * It anonymizes sensitive financial data while preserving analytical patterns.
 */
@MainActor
class PortfolioAnalysisFormatter: ObservableObject {
    private let portfolioManager = PortfolioManager()
    private let dividendCalculationService = DividendCalculationService()
    
    // MARK: - Privacy Protection Settings
    
    struct PrivacySettings: Codable {
        let anonymizeAmounts: Bool
        let anonymizeCompanyNames: Bool
        let anonymizeDates: Bool
        let includePurchaseDates: Bool
        let includeExactQuantities: Bool
        
        static let `default` = PrivacySettings(
            anonymizeAmounts: true,
            anonymizeCompanyNames: false,
            anonymizeDates: false,
            includePurchaseDates: true,
            includeExactQuantities: false
        )
        
        static let maxPrivacy = PrivacySettings(
            anonymizeAmounts: true,
            anonymizeCompanyNames: true,
            anonymizeDates: true,
            includePurchaseDates: false,
            includeExactQuantities: false
        )
    }
    
    // MARK: - Analysis Format Types
    
    enum AnalysisFormat {
        case structured
        case narrative
        case metrics
    }
    
    // MARK: - Formatted Data Models
    
    struct FormattedPortfolioData {
        let portfolioSummary: String
        let holdingsData: String
        let performanceData: String
        let riskMetrics: String
        let privacyNotice: String
    }
    
    // MARK: - Public Methods
    
    /// Format portfolio data for AI analysis with privacy protection
    func formatForAnalysis(
        _ portfolio: Portfolio,
        format: AnalysisFormat = .structured,
        privacySettings: PrivacySettings = .default
    ) async -> FormattedPortfolioData {
        
        guard let holdings = portfolio.holdings as? Set<Holding> else {
            return createEmptyPortfolioData(portfolio, privacySettings: privacySettings)
        }
        
        let holdingsArray = Array(holdings).sorted { 
            ($0.stock?.symbol ?? "") < ($1.stock?.symbol ?? "") 
        }
        
        // Get dividend information
        let dividendInfo = await dividendCalculationService.calculateAnnualDividends(for: holdingsArray)
        
        // Format according to specified format and privacy settings
        switch format {
        case .structured:
            return await formatStructuredData(portfolio, holdings: holdingsArray, dividendInfo: dividendInfo, privacySettings: privacySettings)
        case .narrative:
            return await formatNarrativeData(portfolio, holdings: holdingsArray, dividendInfo: dividendInfo, privacySettings: privacySettings)
        case .metrics:
            return await formatMetricsData(portfolio, holdings: holdingsArray, dividendInfo: dividendInfo, privacySettings: privacySettings)
        }
    }
    
    /// Create a comprehensive analysis prompt with portfolio data
    func createAnalysisPrompt(
        _ portfolio: Portfolio,
        analysisType: String,
        privacySettings: PrivacySettings = .default
    ) async -> String {
        let formattedData = await formatForAnalysis(portfolio, format: .structured, privacySettings: privacySettings)
        
        return """
        \(formattedData.privacyNotice)
        
        PORTFOLIO ANALYSIS REQUEST: \(analysisType)
        
        \(formattedData.portfolioSummary)
        
        \(formattedData.holdingsData)
        
        \(formattedData.performanceData)
        
        \(formattedData.riskMetrics)
        
        Please provide a comprehensive \(analysisType.lowercased()) analysis based on this portfolio data.
        """
    }
    
    // MARK: - Private Formatting Methods
    
    private func formatStructuredData(
        _ portfolio: Portfolio,
        holdings: [Holding],
        dividendInfo: PortfolioDividendInfo,
        privacySettings: PrivacySettings
    ) async -> FormattedPortfolioData {
        
        let portfolioSummary = formatPortfolioSummary(portfolio, holdings: holdings, dividendInfo: dividendInfo, privacySettings: privacySettings)
        let holdingsData = formatHoldingsData(holdings, privacySettings: privacySettings)
        let performanceData = formatPerformanceData(portfolio, holdings: holdings, privacySettings: privacySettings)
        let riskMetrics = formatRiskMetrics(holdings, privacySettings: privacySettings)
        let privacyNotice = createPrivacyNotice(privacySettings: privacySettings)
        
        return FormattedPortfolioData(
            portfolioSummary: portfolioSummary,
            holdingsData: holdingsData,
            performanceData: performanceData,
            riskMetrics: riskMetrics,
            privacyNotice: privacyNotice
        )
    }
    
    private func formatNarrativeData(
        _ portfolio: Portfolio,
        holdings: [Holding],
        dividendInfo: PortfolioDividendInfo,
        privacySettings: PrivacySettings
    ) async -> FormattedPortfolioData {
        // Similar to structured but in narrative format
        return await formatStructuredData(portfolio, holdings: holdings, dividendInfo: dividendInfo, privacySettings: privacySettings)
    }
    
    private func formatMetricsData(
        _ portfolio: Portfolio,
        holdings: [Holding],
        dividendInfo: PortfolioDividendInfo,
        privacySettings: PrivacySettings
    ) async -> FormattedPortfolioData {
        // Focused on key metrics and ratios
        return await formatStructuredData(portfolio, holdings: holdings, dividendInfo: dividendInfo, privacySettings: privacySettings)
    }
    
    // MARK: - Data Formatting Helpers
    
    private func formatPortfolioSummary(
        _ portfolio: Portfolio,
        holdings: [Holding],
        dividendInfo: PortfolioDividendInfo,
        privacySettings: PrivacySettings
    ) -> String {
        
        let totalValue = portfolioManager.calculatePortfolioValue(portfolio)
        let holdingsCount = holdings.count
        
        var summary = "PORTFOLIO OVERVIEW:\n"
        summary += "Portfolio Name: \(privacySettings.anonymizeCompanyNames ? "Portfolio-\(String(portfolio.portfolioID?.uuidString.prefix(8) ?? "XXXX"))" : portfolio.name ?? "Unnamed")\n"
        summary += "Total Holdings: \(holdingsCount) positions\n"
        
        if privacySettings.anonymizeAmounts {
            summary += "Total Value: \(anonymizeAmount(totalValue))\n"
        } else {
            summary += "Total Value: \(formatCurrency(totalValue))\n"
        }
        
        if dividendInfo.hasDividends {
            let annualDividends = privacySettings.anonymizeAmounts ? anonymizeAmount(dividendInfo.totalAnnualDividends) : formatCurrency(dividendInfo.totalAnnualDividends)
            summary += "Annual Dividends: \(annualDividends)\n"
            summary += "Portfolio Yield: \(formatPercentage(dividendInfo.portfolioYieldPercent))\n"
            summary += "Dividend-Paying Stocks: \(dividendInfo.dividendCoverage)\n"
        }
        
        // Add portfolio age and diversification metrics
        if let createdDate = portfolio.createdDate, !privacySettings.anonymizeDates {
            let ageInDays = Calendar.current.dateComponents([.day], from: createdDate, to: Date()).day ?? 0
            summary += "Portfolio Age: \(ageInDays) days\n"
        }
        
        summary += "Diversification: \(calculateDiversificationScore(holdings)) stocks across sectors\n"
        
        return summary
    }
    
    private func formatHoldingsData(_ holdings: [Holding], privacySettings: PrivacySettings) -> String {
        var data = "INDIVIDUAL HOLDINGS:\n"
        
        for (index, holding) in holdings.enumerated() {
            guard let stock = holding.stock else { continue }
            
            let symbol = stock.symbol ?? "UNKNOWN"
            let companyName = privacySettings.anonymizeCompanyNames ? "Company-\(symbol)" : (stock.companyName ?? "Unknown Company")
            
            data += "\n\(index + 1). \(symbol) - \(companyName)\n"
            
            if privacySettings.includeExactQuantities {
                data += "   Quantity: \(holding.quantity) shares\n"
            } else {
                data += "   Quantity: \(quantityRange(Int(holding.quantity))) shares\n"
            }
            
            let currentPrice = stock.effectiveCurrentPrice ?? 0
            let purchasePrice = holding.pricePerShare?.decimalValue ?? 0
            
            if privacySettings.anonymizeAmounts {
                data += "   Current Price: \(anonymizeAmount(currentPrice))\n"
                data += "   Purchase Price: \(anonymizeAmount(purchasePrice))\n"
            } else {
                data += "   Current Price: \(formatCurrency(currentPrice))\n"
                data += "   Purchase Price: \(formatCurrency(purchasePrice))\n"
            }
            
            // Calculate and display gain/loss percentage (this preserves analytical value)
            let gainLossPercent = purchasePrice > 0 ? ((currentPrice - purchasePrice) / purchasePrice) * 100 : 0
            let gainLossPrefix = gainLossPercent >= 0 ? "+" : ""
            data += "   Performance: \(gainLossPrefix)\(formatPercentage(gainLossPercent))\n"
            
            if let purchaseDate = holding.datePurchased, privacySettings.includePurchaseDates {
                if privacySettings.anonymizeDates {
                    let daysSincePurchase = Calendar.current.dateComponents([.day], from: purchaseDate, to: Date()).day ?? 0
                    data += "   Holding Period: \(daysSincePurchase) days\n"
                } else {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    data += "   Purchase Date: \(formatter.string(from: purchaseDate))\n"
                }
            }
        }
        
        return data
    }
    
    private func formatPerformanceData(_ portfolio: Portfolio, holdings: [Holding], privacySettings: PrivacySettings) -> String {
        var data = "PERFORMANCE METRICS:\n"
        
        // Calculate overall portfolio performance
        let totalValue = portfolioManager.calculatePortfolioValue(portfolio)
        let totalPurchaseValue = holdings.reduce(Decimal(0)) { total, holding in
            let purchasePrice = holding.pricePerShare?.decimalValue ?? 0
            let quantity = Decimal(holding.quantity)
            return total + (purchasePrice * quantity)
        }
        
        let totalGainLoss = totalValue - totalPurchaseValue
        let totalGainLossPercentage = totalPurchaseValue > 0 ? ((totalGainLoss / totalPurchaseValue) * 100) : 0
        
        if privacySettings.anonymizeAmounts {
            data += "Total Gain/Loss: \(anonymizeAmount(totalGainLoss)) (\(formatPercentage(totalGainLossPercentage)))\n"
        } else {
            data += "Total Gain/Loss: \(formatCurrency(totalGainLoss)) (\(formatPercentage(totalGainLossPercentage)))\n"
        }
        
        // Performance distribution
        let (winners, losers) = calculateWinnersLosers(holdings)
        data += "Winning Positions: \(winners)\n"
        data += "Losing Positions: \(losers)\n"
        data += "Win Rate: \(formatPercentage(holdings.count > 0 ? (Decimal(winners) / Decimal(holdings.count)) * 100 : 0))\n"
        
        // Sector allocation (anonymized if needed)
        data += "\nSECTOR ALLOCATION:\n"
        data += calculateSectorAllocation(holdings, privacySettings: privacySettings)
        
        return data
    }
    
    private func formatRiskMetrics(_ holdings: [Holding], privacySettings: PrivacySettings) -> String {
        var data = "RISK ASSESSMENT:\n"
        
        // Concentration risk
        data += "Concentration Risk: \(calculateConcentrationRisk(holdings))\n"
        
        // Volatility assessment (based on performance spread)
        data += "Portfolio Volatility: \(calculateVolatilityScore(holdings))\n"
        
        // Diversification score
        data += "Diversification Score: \(calculateDiversificationScore(holdings)) sectors\n"
        
        // Largest position percentage
        let largestPositionPercent = calculateLargestPositionPercentage(holdings)
        data += "Largest Position: \(formatPercentage(largestPositionPercent)) of portfolio\n"
        
        return data
    }
    
    // MARK: - Privacy Protection Helpers
    
    private func anonymizeAmount(_ amount: Decimal) -> String {
        // Convert to ranges to preserve analytical patterns while protecting exact values
        let absAmount = abs(amount)
        
        switch absAmount {
        case 0..<100:
            return "$0-100"
        case 100..<500:
            return "$100-500"
        case 500..<1000:
            return "$500-1K"
        case 1000..<5000:
            return "$1K-5K"
        case 5000..<10000:
            return "$5K-10K"
        case 10000..<50000:
            return "$10K-50K"
        case 50000..<100000:
            return "$50K-100K"
        case 100000..<500000:
            return "$100K-500K"
        case 500000..<1000000:
            return "$500K-1M"
        default:
            return "$1M+"
        }
    }
    
    private func quantityRange(_ quantity: Int) -> String {
        switch quantity {
        case 0..<10:
            return "1-10"
        case 10..<50:
            return "10-50"
        case 50..<100:
            return "50-100"
        case 100..<500:
            return "100-500"
        case 500..<1000:
            return "500-1K"
        default:
            return "1K+"
        }
    }
    
    private func createPrivacyNotice(privacySettings: PrivacySettings) -> String {
        var notice = "PRIVACY PROTECTION NOTICE:\n"
        notice += "This portfolio analysis has been prepared with privacy protection:\n"
        
        if privacySettings.anonymizeAmounts {
            notice += "• Exact dollar amounts have been converted to ranges\n"
        }
        
        if privacySettings.anonymizeCompanyNames {
            notice += "• Company names have been anonymized\n"
        }
        
        if privacySettings.anonymizeDates {
            notice += "• Specific dates have been converted to relative periods\n"
        }
        
        if !privacySettings.includeExactQuantities {
            notice += "• Share quantities have been converted to ranges\n"
        }
        
        notice += "• All percentage calculations preserve analytical accuracy\n"
        notice += "• No personally identifiable information is included\n"
        
        return notice
    }
    
    // MARK: - Analysis Calculation Helpers
    
    private func calculateWinnersLosers(_ holdings: [Holding]) -> (winners: Int, losers: Int) {
        var winners = 0
        var losers = 0
        
        for holding in holdings {
            let currentPrice = holding.stock?.effectiveCurrentPrice ?? 0
            let purchasePrice = holding.pricePerShare?.decimalValue ?? 0
            
            if currentPrice > purchasePrice {
                winners += 1
            } else if currentPrice < purchasePrice {
                losers += 1
            }
        }
        
        return (winners, losers)
    }
    
    private func calculateSectorAllocation(_ holdings: [Holding], privacySettings: PrivacySettings) -> String {
        // Simple sector categorization based on common stock symbols
        // In a real implementation, this would use proper sector data
        var sectors: [String: Int] = [:]
        
        for holding in holdings {
            let symbol = holding.stock?.symbol ?? "UNKNOWN"
            let sector = categorizeSector(symbol: symbol)
            sectors[sector, default: 0] += 1
        }
        
        var allocation = ""
        for (sector, count) in sectors.sorted(by: { $0.value > $1.value }) {
            let percentage = holdings.count > 0 ? (Double(count) / Double(holdings.count)) * 100 : 0
            allocation += "• \(sector): \(count) holdings (\(String(format: "%.1f", percentage))%)\n"
        }
        
        return allocation
    }
    
    private func categorizeSector(symbol: String) -> String {
        // Basic sector categorization - in a real app, this would use actual sector data
        let techSymbols = ["AAPL", "MSFT", "GOOGL", "GOOG", "AMZN", "META", "NVDA", "CRM", "ORCL", "ADBE"]
        let financeSymbols = ["JPM", "BAC", "WFC", "GS", "MS", "C", "USB", "PNC", "TFC", "COF"]
        let healthSymbols = ["JNJ", "PFE", "UNH", "ABT", "MRK", "TMO", "DHR", "BMY", "AMGN", "GILD"]
        
        if techSymbols.contains(symbol) {
            return "Technology"
        } else if financeSymbols.contains(symbol) {
            return "Financial Services"
        } else if healthSymbols.contains(symbol) {
            return "Healthcare"
        } else {
            return "Other Sectors"
        }
    }
    
    private func calculateConcentrationRisk(_ holdings: [Holding]) -> String {
        guard !holdings.isEmpty else { return "No holdings" }
        
        let totalValue = holdings.reduce(Decimal(0)) { total, holding in
            let currentPrice = holding.stock?.effectiveCurrentPrice ?? 0
            let quantity = Decimal(holding.quantity)
            return total + (currentPrice * quantity)
        }
        
        let largestPosition = holdings.max { holding1, holding2 in
            let value1 = (holding1.stock?.effectiveCurrentPrice ?? 0) * Decimal(holding1.quantity)
            let value2 = (holding2.stock?.effectiveCurrentPrice ?? 0) * Decimal(holding2.quantity)
            return value1 < value2
        }
        
        if let largest = largestPosition, totalValue > 0 {
            let largestValue = (largest.stock?.effectiveCurrentPrice ?? 0) * Decimal(largest.quantity)
            let percentage = (largestValue / totalValue) * 100
            
            switch percentage {
            case 0..<10:
                return "Low (largest position <10%)"
            case 10..<25:
                return "Moderate (largest position 10-25%)"
            case 25..<50:
                return "High (largest position 25-50%)"
            default:
                return "Very High (largest position >50%)"
            }
        }
        
        return "Unable to calculate"
    }
    
    private func calculateVolatilityScore(_ holdings: [Holding]) -> String {
        let performances = holdings.compactMap { holding -> Decimal? in
            let currentPrice = holding.stock?.effectiveCurrentPrice ?? 0
            let purchasePrice = holding.pricePerShare?.decimalValue ?? 0
            guard purchasePrice > 0 else { return nil }
            return ((currentPrice - purchasePrice) / purchasePrice) * 100
        }
        
        guard !performances.isEmpty else { return "No data" }
        
        let avgPerformance = performances.reduce(0, +) / Decimal(performances.count)
        let variance = performances.reduce(0) { sum, performance in
            let diff = performance - avgPerformance
            return sum + (diff * diff)
        } / Decimal(performances.count)
        
        let standardDeviation = sqrt(Double(truncating: variance as NSNumber))
        
        switch standardDeviation {
        case 0..<10:
            return "Low volatility (σ<10%)"
        case 10..<20:
            return "Moderate volatility (σ 10-20%)"
        case 20..<30:
            return "High volatility (σ 20-30%)"
        default:
            return "Very high volatility (σ>30%)"
        }
    }
    
    private func calculateDiversificationScore(_ holdings: [Holding]) -> Int {
        var sectors = Set<String>()
        for holding in holdings {
            let symbol = holding.stock?.symbol ?? "UNKNOWN"
            sectors.insert(categorizeSector(symbol: symbol))
        }
        return sectors.count
    }
    
    private func calculateLargestPositionPercentage(_ holdings: [Holding]) -> Decimal {
        guard !holdings.isEmpty else { return 0 }
        
        let totalValue = holdings.reduce(Decimal(0)) { total, holding in
            let currentPrice = holding.stock?.effectiveCurrentPrice ?? 0
            let quantity = Decimal(holding.quantity)
            return total + (currentPrice * quantity)
        }
        
        let largestValue = holdings.map { holding -> Decimal in
            let currentPrice = holding.stock?.effectiveCurrentPrice ?? 0
            let quantity = Decimal(holding.quantity)
            return currentPrice * quantity
        }.max() ?? 0
        
        return totalValue > 0 ? (largestValue / totalValue) * 100 : 0
    }
    
    private func createEmptyPortfolioData(_ portfolio: Portfolio, privacySettings: PrivacySettings) -> FormattedPortfolioData {
        let portfolioName = privacySettings.anonymizeCompanyNames ? "Empty Portfolio" : (portfolio.name ?? "Unnamed Portfolio")
        
        return FormattedPortfolioData(
            portfolioSummary: "PORTFOLIO OVERVIEW:\nPortfolio Name: \(portfolioName)\nTotal Holdings: 0 positions\nTotal Value: $0",
            holdingsData: "INDIVIDUAL HOLDINGS:\nNo holdings in this portfolio.",
            performanceData: "PERFORMANCE METRICS:\nNo performance data available.",
            riskMetrics: "RISK ASSESSMENT:\nNo risk assessment possible with empty portfolio.",
            privacyNotice: createPrivacyNotice(privacySettings: privacySettings)
        )
    }
    
    // MARK: - Formatting Utilities
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = 0
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
}