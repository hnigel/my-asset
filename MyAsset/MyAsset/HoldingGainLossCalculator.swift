import Foundation
import CoreData

/// Utility class to ensure consistent gain/loss calculations across UI and export
class HoldingGainLossCalculator {
    
    static func calculateGainLoss(for holding: Holding, context: String) -> Decimal {
        let currentPrice = holding.stock?.effectiveCurrentPrice ?? 0
        let purchasePrice = holding.pricePerShare?.decimalValue ?? 0
        let quantity = Decimal(holding.quantity)
        
        let currentValue = currentPrice * quantity
        let purchaseValue = purchasePrice * quantity
        let gainLoss = currentValue - purchaseValue
        
        return gainLoss
    }
    
    static func calculateGainLossWithRawValues(
        currentPrice: Decimal,
        purchasePrice: Decimal,
        quantity: Int32,
        symbol: String,
        context: String
    ) -> Decimal {
        let quantityDecimal = Decimal(quantity)
        let currentValue = currentPrice * quantityDecimal
        let purchaseValue = purchasePrice * quantityDecimal
        let gainLoss = currentValue - purchaseValue
        
        return gainLoss
    }
    
    // MARK: - Formatting Test Methods
    
    private static func formatAsUIDisplay(_ amount: Decimal) -> String {
        // Simulate SwiftUI's .currency(code: "USD") formatting
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
    
    private static func formatAsExportDisplay(_ amount: Decimal) -> String {
        // Simulate TextExportManager's formatCurrency method
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0"
    }
}