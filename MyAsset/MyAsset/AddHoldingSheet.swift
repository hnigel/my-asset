import SwiftUI
import CoreData

// MARK: - NumberFormatter Extension
extension NumberFormatter {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()
}

struct AddHoldingSheet: View {
    let portfolio: Portfolio
    let onHoldingAdded: () -> Void
    
    @StateObject private var portfolioManager: PortfolioManager
    @StateObject private var stockPriceService: StockPriceService
    @StateObject private var historicalDataManager: ComprehensiveHistoricalDataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var symbol = ""
    @State private var quantity = ""
    @State private var datePurchased = Date()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoadingPrice = false
    @State private var isLoadingHistoricalPrice = false
    @State private var currentStockQuote: StockQuote?
    @State private var historicalPrice: HistoricalPrice?
    @State private var priceError: String?
    @State private var historicalPriceError: String?
    @State private var isUsingHistoricalPrice = false
    
    init(portfolio: Portfolio, onHoldingAdded: @escaping () -> Void) {
        self.portfolio = portfolio
        self.onHoldingAdded = onHoldingAdded
        self._portfolioManager = StateObject(wrappedValue: PortfolioManager())
        self._stockPriceService = StateObject(wrappedValue: StockPriceService())
        self._historicalDataManager = StateObject(wrappedValue: ComprehensiveHistoricalDataManager())
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Stock Details")) {
                    HStack {
                        TextField("Symbol (e.g., AAPL)", text: $symbol)
                            .textInputAutocapitalization(.characters)
                            .onSubmit {
                                Task {
                                    await fetchStockPrice()
                                }
                            }
                            .onChange(of: symbol) { oldValue, newValue in
                                // Clear previous data when symbol changes
                                currentStockQuote = nil
                                priceError = nil
                                historicalPrice = nil
                                historicalPriceError = nil
                                
                                // Auto-fetch price after user stops typing
                                Task {
                                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                                    if symbol == newValue && !newValue.isEmpty {
                                        await fetchStockPrice()
                                        // Also check if we need historical data for current date
                                        await handleDateChange(datePurchased)
                                    }
                                }
                            }
                        
                        if isLoadingPrice {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    // Show current stock price and company name (always show when available)
                    if let quote = currentStockQuote {
                        HStack {
                            VStack(alignment: .leading) {
                                if let companyName = quote.companyName {
                                    Text(companyName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text("Current Price: \(quote.formattedPrice)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            Spacer()
                            Text("✓")
                                .foregroundColor(.green)
                                .font(.title2)
                        }
                    }
                    
                    // Show purchase price when different from current (historical data)
                    if let histPrice = historicalPrice, isUsingHistoricalPrice {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Purchase Price (\(formatDate(histPrice.date)))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Close: \(histPrice.formattedClosePrice)")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            Spacer()
                            if isLoadingHistoricalPrice {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("📊")
                                    .foregroundColor(.orange)
                                    .font(.title2)
                            }
                        }
                    }
                    
                    // Show when using current price for purchase
                    if !isUsingHistoricalPrice && currentStockQuote != nil {
                        HStack {
                            Text("Purchase Price: Same as current price")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Spacer()
                            Text("💰")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                    
                    // Show price error
                    if let error = priceError, !isUsingHistoricalPrice {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Show historical price error
                    if let error = historicalPriceError, isUsingHistoricalPrice {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Historical Price Error: \(error)")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section(header: Text("Purchase Details")) {
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                    
                    DatePicker("Date Purchased", selection: $datePurchased, displayedComponents: .date)
                        .onChange(of: datePurchased) { oldValue, newValue in
                            Task {
                                await handleDateChange(newValue)
                            }
                        }
                    
                    // Show total investment amount
                    if let quantityInt = Int32(quantity), quantityInt > 0 {
                        let totalValue = calculateTotalValue(quantityInt: quantityInt)
                        
                        if totalValue > 0 {
                            VStack(spacing: 4) {
                                HStack {
                                    Text("Total Investment:")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(NumberFormatter.currency.string(from: NSNumber(value: totalValue)) ?? "$0.00")
                                        .fontWeight(.semibold)
                                }
                                
                                // Show total gain/loss
                                let gainLossResult = calculateTotalGainLoss(quantityInt: quantityInt)
                                let gainLoss = gainLossResult.gainLoss
                                let percentage = gainLossResult.percentage
                                
                                if abs(gainLoss) > 0.01 { // Only show if meaningful gain/loss
                                    HStack {
                                        Text("Unrealized Gain/Loss:")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(NumberFormatter.currency.string(from: NSNumber(value: gainLoss)) ?? "$0.00")
                                                .fontWeight(.semibold)
                                                .foregroundColor(gainLoss >= 0 ? .green : .red)
                                            Text("(\(gainLoss >= 0 ? "+" : "")\(String(format: "%.2f", percentage))%)")
                                                .font(.caption2)
                                                .foregroundColor(gainLoss >= 0 ? .green : .red)
                                        }
                                    }
                                } else if !isUsingHistoricalPrice {
                                    HStack {
                                        Text("Unrealized Gain/Loss:")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("$0.00 (0.00%)")
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .font(.caption)
                        }
                    }
                }
                
                Section {
                    Button("Add Holding") {
                        addHolding()
                    }
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("Add Holding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var isFormValid: Bool {
        !symbol.isEmpty &&
        !quantity.isEmpty &&
        Int32(quantity) != nil &&
        (currentStockQuote?.isValid == true || (isUsingHistoricalPrice && historicalPrice?.isValid == true))
    }
    
    
    private func addHolding() {
        guard let quantityInt = Int32(quantity), quantityInt > 0 else {
            alertMessage = "Quantity must be greater than zero."
            showingAlert = true
            return
        }
        
        // Ensure we have current stock quote for the stock's current price
        guard let currentQuote = currentStockQuote, currentQuote.isValid else {
            alertMessage = "Please ensure current stock price is available."
            showingAlert = true
            return
        }
        
        let finalSymbol = currentQuote.symbol
        let purchasePriceDecimal: Decimal
        let currentPriceDecimal = Decimal(currentQuote.price)
        
        // Use historical price for purchase if available and needed, otherwise use current price
        if isUsingHistoricalPrice, let histPrice = historicalPrice, histPrice.isValid {
            purchasePriceDecimal = histPrice.closePrice
        } else {
            purchasePriceDecimal = Decimal(currentQuote.price)
        }
        
        let newHolding = portfolioManager.addHoldingWithCurrentPrice(
            to: portfolio,
            symbol: finalSymbol,
            quantity: quantityInt,
            pricePerShare: purchasePriceDecimal,
            currentPrice: currentPriceDecimal,
            datePurchased: datePurchased
        )
        
        // Ensure data is saved before triggering callback
        portfolioManager.save()
        
        // Fetch dividend information for the newly added stock
        Task {
            await fetchAndSaveDividendInfo(for: newHolding.stock!, symbol: finalSymbol)
        }
        
        // Call callback after successful save
        onHoldingAdded()
        presentationMode.wrappedValue.dismiss()
    }
    
    @MainActor
    private func fetchStockPrice() async {
        let cleanSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanSymbol.isEmpty else {
            currentStockQuote = nil
            priceError = nil
            return
        }
        
        isLoadingPrice = true
        priceError = nil
        
        do {
            let quote = try await stockPriceService.fetchStockPrice(symbol: cleanSymbol)
            currentStockQuote = quote
            symbol = quote.symbol // Update with clean symbol from API
        } catch let error as StockPriceService.APIError {
            priceError = error.errorDescription
            currentStockQuote = nil
        } catch {
            priceError = "Failed to fetch stock price: \(error.localizedDescription)"
            currentStockQuote = nil
        }
        
        isLoadingPrice = false
    }
    
    @MainActor
    private func handleDateChange(_ newDate: Date) async {
        // Clear previous historical data
        historicalPrice = nil
        historicalPriceError = nil
        
        let cleanSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanSymbol.isEmpty else {
            isUsingHistoricalPrice = false
            return
        }
        
        // Check if the selected date is today
        let calendar = Calendar.current
        let isToday = calendar.isDate(newDate, inSameDayAs: Date())
        
        if isToday {
            // Use current price for today
            isUsingHistoricalPrice = false
            return
        }
        
        // Selected date is in the past, fetch historical price
        isUsingHistoricalPrice = true
        isLoadingHistoricalPrice = true
        historicalPriceError = nil
        
        do {
            // Fetch historical prices for a small range around the selected date
            let startDate = calendar.date(byAdding: .day, value: -2, to: newDate) ?? newDate
            let endDate = calendar.date(byAdding: .day, value: 2, to: newDate) ?? newDate
            
            let historicalPrices = try await historicalDataManager.fetchHistoricalPrices(
                symbol: cleanSymbol,
                startDate: startDate,
                endDate: endDate
            )
            
            // Find the closest price to the selected date
            let sortedPrices = historicalPrices.sorted { abs($0.date.timeIntervalSince(newDate)) < abs($1.date.timeIntervalSince(newDate)) }
            
            if let closestPrice = sortedPrices.first {
                historicalPrice = closestPrice
            } else {
                historicalPriceError = "No historical price data available for this date"
            }
            
        } catch {
            historicalPriceError = "Failed to fetch historical price: \(error.localizedDescription)"
        }
        
        isLoadingHistoricalPrice = false
    }
    
    private func calculateTotalValue(quantityInt: Int32) -> Double {
        if isUsingHistoricalPrice, let histPrice = historicalPrice {
            return NSDecimalNumber(decimal: histPrice.closePrice).doubleValue * Double(quantityInt)
        } else if let quote = currentStockQuote {
            return quote.price * Double(quantityInt)
        } else {
            return 0
        }
    }
    
    private func calculateTotalGainLoss(quantityInt: Int32) -> (gainLoss: Double, percentage: Double) {
        guard let currentQuote = currentStockQuote else {
            return (0, 0)
        }
        
        let currentPrice = currentQuote.price
        let purchasePrice: Double
        
        // Determine the purchase price
        if isUsingHistoricalPrice, let histPrice = historicalPrice {
            purchasePrice = NSDecimalNumber(decimal: histPrice.closePrice).doubleValue
        } else {
            purchasePrice = currentPrice // Same day purchase
        }
        
        let quantity = Double(quantityInt)
        let totalGainLoss = (currentPrice - purchasePrice) * quantity
        
        // Calculate percentage gain/loss
        let percentageGainLoss = purchasePrice > 0 ? ((currentPrice - purchasePrice) / purchasePrice) * 100 : 0
        
        return (totalGainLoss, percentageGainLoss)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    @MainActor
    private func fetchAndSaveDividendInfo(for stock: Stock, symbol: String) async {
        print("📈 Fetching dividend information for \(symbol)...")
        
        // Fetch dividend information using the stock price service
        let distributionInfo = await stockPriceService.fetchDistributionInfo(symbol: symbol)
        
        // Save dividend info to Core Data using DividendManager
        let dividendManager = DividendManager()
        await dividendManager.saveDividendToCore(distributionInfo: distributionInfo, for: stock)
        
        print("✅ Dividend information saved for \(symbol)")
        
        // Optional: Update the UI or show success message
        if let rate = distributionInfo.distributionRate, rate > 0 {
            print("💰 Dividend Rate: \(rate)")
            if let yield = distributionInfo.distributionYieldPercent {
                print("📊 Dividend Yield: \(yield)%")
            }
        } else {
            print("📊 No dividend information found for \(symbol)")
        }
    }
    
}

struct AddHoldingSheet_Previews: PreviewProvider {
    static var previews: some View {
        let portfolio = Portfolio(context: DataManager.shared.context)
        portfolio.name = "Sample Portfolio"
        portfolio.portfolioID = UUID()
        portfolio.createdDate = Date()
        
        return AddHoldingSheet(portfolio: portfolio, onHoldingAdded: {})
            .environment(\.managedObjectContext, DataManager.shared.context)
    }
}