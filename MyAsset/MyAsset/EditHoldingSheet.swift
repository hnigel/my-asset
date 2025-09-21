import SwiftUI
import CoreData

struct EditHoldingSheet: View {
    let holding: Holding
    let onHoldingUpdated: () -> Void
    
    @StateObject private var portfolioManager = PortfolioManager()
    @StateObject private var dividendManager = DividendManager()
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    @State private var quantity: String
    @State private var pricePerShare: String
    @State private var datePurchased: Date
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSaving = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var isUpdatingDividend = false
    
    init(holding: Holding, onHoldingUpdated: @escaping () -> Void) {
        // Diagnostic logging for EditHoldingSheet initialization
        let symbol = holding.stock?.symbol ?? "Unknown"
        print("🏗️ [EDIT HOLDING INIT] Initializing EditHoldingSheet for: \(symbol)")
        print("🏗️ [EDIT HOLDING INIT] Holding ObjectID: \(holding.objectID)")
        print("🏗️ [EDIT HOLDING INIT] Holding context: \(holding.managedObjectContext != nil ? "Valid" : "Nil")")
        print("🏗️ [EDIT HOLDING INIT] Holding deleted: \(holding.isDeleted)")
        print("🏗️ [EDIT HOLDING INIT] Stock relationship: \(holding.stock != nil ? "Valid" : "Nil")")
        
        self.holding = holding
        self.onHoldingUpdated = onHoldingUpdated
        
        // Initialize state with current holding values - with safe fallbacks
        let safeQuantity = max(holding.quantity, 0) // Ensure non-negative
        let safePrice = holding.pricePerShare ?? NSDecimalNumber(value: 0.00)
        let safeDate = holding.purchaseDate ?? Date()
        
        print("🏗️ [EDIT HOLDING INIT] Safe quantity: \(safeQuantity)")
        print("🏗️ [EDIT HOLDING INIT] Safe price: \(safePrice)")
        print("🏗️ [EDIT HOLDING INIT] Safe date: \(safeDate)")
        
        _quantity = State(initialValue: String(safeQuantity))
        _pricePerShare = State(initialValue: NumberFormatter.decimal.string(from: safePrice) ?? "0.00")
        _datePurchased = State(initialValue: safeDate)
        
        print("🏗️ [EDIT HOLDING INIT] EditHoldingSheet initialization completed for: \(symbol)")
    }
    
    private var latestValidDividend: Dividend? {
        // 1. Try to get dividend data, return nil if none exists
        guard let dividends = holding.stock?.dividends as? Set<Dividend>, !dividends.isEmpty else {
            return nil
        }

        // 2. Filter valid dividends (e.g., amount > 0)
        let validDividends = dividends.filter { dividend in
            let hasAmount = (dividend.amount?.decimalValue ?? 0) > 0
            let hasYield = (dividend.yield?.decimalValue ?? 0) > 0
            let hasFrequency = dividend.frequency != nil
            return hasAmount || hasYield || hasFrequency
        }

        // 3. Return nil if no valid dividends
        guard !validDividends.isEmpty else {
            return nil
        }

        // 4. Sort valid dividends by date
        let sortedDividends = validDividends.sorted { dividend1, dividend2 in
            let date1 = dividend1.paymentDate ?? dividend1.exDividendDate ?? Date.distantPast
            let date2 = dividend2.paymentDate ?? dividend2.exDividendDate ?? Date.distantPast
            return date1 > date2
        }

        // 5. Return the latest dividend
        return sortedDividends.first
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isHoldingValid {
                    Form {
                        Section(header: Text("Stock Information")) {
                            HStack {
                                Text("Symbol:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(holding.stock?.symbol ?? "Unknown")
                                    .fontWeight(.semibold)
                            }
                            
                            if let companyName = holding.stock?.name, !companyName.isEmpty {
                                HStack {
                                    Text("Company:")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(companyName)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            HStack {
                                Text("Current Price:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(currentPrice, format: .currency(code: "USD"))
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Section(header: Text("Edit Holding Details")) {
                            HStack {
                                Text("Quantity:")
                                TextField("Quantity", text: $quantity)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .onChange(of: quantity) { _, newValue in
                                        // Filter out non-numeric characters
                                        let filtered = newValue.filter { $0.isNumber }
                                        if filtered != newValue {
                                            quantity = filtered
                                        }
                                    }
                            }
                            .foregroundColor(isQuantityValid ? .primary : .red)
                            
                            HStack {
                                Text("Price per Share:")
                                TextField("Price", text: $pricePerShare)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .onChange(of: pricePerShare) { _, newValue in
                                        // Allow numbers and one decimal point
                                        let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                        let decimalCount = filtered.filter { $0 == "." }.count
                                        if decimalCount <= 1 && filtered != newValue {
                                            pricePerShare = filtered
                                        } else if decimalCount > 1 {
                                            pricePerShare = String(filtered.dropLast())
                                        }
                                    }
                            }
                            .foregroundColor(isPriceValid ? .primary : .red)
                            
                            DatePicker("Date Purchased", selection: $datePurchased, in: ...Date(), displayedComponents: .date)
                        }

                        Section(header: 
                            HStack {
                                Text("Distribution")
                                    .textCase(.uppercase)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(action: {
                                    updateDividendInfo()
                                }) {
                                    HStack(spacing: 4) {
                                        if isUpdatingDividend {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                        } else {
                                            Image(systemName: "arrow.clockwise.circle")
                                                .font(.caption)
                                                .symbolRenderingMode(.hierarchical)
                                        }
                                        Text(isUpdatingDividend ? "Updating..." : "Update")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(isUpdatingDividend ? .secondary : .blue)
                                }
                                .disabled(isUpdatingDividend)
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        ) {
                            let dividendsSet = holding.stock?.dividends as? Set<Dividend>
                            let dividendCount = dividendsSet?.count ?? 0
                            
                            if let latestDividend = latestValidDividend {
                                // Annual Dividend - 核心資訊
                                HStack {
                                    Text("Annual Dividend:")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Spacer()
                                            if let annualizedAmount = latestDividend.annualizedAmount?.decimalValue, annualizedAmount > 0 {
                                                Text(annualizedAmount, format: .currency(code: "USD"))
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.green)
                                                    .font(.headline)
                                            } else {
                                                Text("–")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.vertical, 2)
                                        
                                        // Distribution Yield %
                                        HStack {
                                            Text("Distribution Yield:")
                                                .fontWeight(.medium)
                                            Spacer()
                                            if let yield = latestDividend.yield?.decimalValue, yield > 0 {
                                                Text("\(yield * 100, format: .number.precision(.fractionLength(2)))%")
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.blue)
                                            } else {
                                                Text("–")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        // Distribution Frequency
                                        HStack {
                                            Text("Distribution Frequency:")
                                                .fontWeight(.medium)
                                            Spacer()
                                            if let frequency = latestDividend.frequency, !frequency.isEmpty {
                                                Text(frequency.capitalized)
                                                    .fontWeight(.medium)
                                            } else {
                                                Text("–")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        // Last Ex-Date
                                        HStack {
                                            Text("Last Ex-Date:")
                                                .fontWeight(.medium)
                                            Spacer()
                                            if let exDate = latestDividend.exDividendDate {
                                                Text(exDate, style: .date)
                                                    .fontWeight(.medium)
                                            } else {
                                                Text("–")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        // Full Name (from stock)
                                        if let stock = latestDividend.stock, let fullName = stock.name, !fullName.isEmpty {
                                            HStack {
                                                Text("Full Name:")
                                                    .fontWeight(.medium)
                                                Spacer()
                                                Text(fullName)
                                                    .fontWeight(.medium)
                                                    .multilineTextAlignment(.trailing)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                        
                                        // Data Source
                                        HStack {
                                            Text("Data Source:")
                                                .fontWeight(.medium)
                                            Spacer()
                                            Text(latestDividend.dataSource ?? "API")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                        }
                                } else {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("No valid distribution data available")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                        Text("Found \(dividendCount) dividend record(s) but none contain valid data")
                                            .foregroundColor(.secondary)
                                            .font(.caption2)
                                    }
                                }
                        }
                        
                        Section {
                            Button(action: saveChanges) {
                                HStack {
                                    if isSaving {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Saving...")
                                    } else {
                                        Text("Save Changes")
                                    }
                                }
                            }
                            .disabled(!isFormValid || isSaving || isDeleting)
                        }
                        
                        Section {
                            Button(action: confirmDelete) {
                                HStack {
                                    if isDeleting {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Deleting...")
                                    } else {
                                        Image(systemName: "trash")
                                        Text("Delete Holding")
                                    }
                                }
                                .foregroundColor(.red)
                            }
                            .disabled(isSaving || isDeleting)
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Unable to Load Holding")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("This holding may have been deleted or is no longer available.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Close") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            }
            .navigationTitle(isHoldingValid ? "Edit Holding" : "Error")
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
            .confirmationDialog("Delete Holding", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    deleteHolding()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this holding for \(holding.stock?.symbol ?? "Unknown")? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Helpers
    
    // MARK: - Computed Properties
    
    private var isHoldingValid: Bool {
        // Thread-safe validation using the view context
        print("🔄 [EDIT HOLDING VALIDATION] isHoldingValid computed property called")
        
        let result: Bool = viewContext.performAndWait {
            let holdingID = holding.objectID
            let originalSymbol = holding.stock?.symbol ?? "Unknown"
            
            // Detailed diagnostic logging for EditHoldingSheet
            print("🔍 [EDIT HOLDING VALIDATION] Starting validation for holding with symbol: \(originalSymbol)")
            print("🔍 [EDIT HOLDING VALIDATION] Holding ObjectID: \(holdingID)")
            
            // Check managed object context first
            guard holding.managedObjectContext != nil else {
                print("❌ [EDIT HOLDING VALIDATION] FAILED: Holding has no managed object context")
                print("❌ [EDIT HOLDING VALIDATION] This may indicate the holding has been deallocated")
                return false
            }
            print("✅ [EDIT HOLDING VALIDATION] Holding has managed object context")
            
            // Check if holding is deleted
            guard !holding.isDeleted else {
                print("❌ [EDIT HOLDING VALIDATION] FAILED: Holding is marked as deleted")
                print("❌ [EDIT HOLDING VALIDATION] The holding may have been deleted by another process")
                return false
            }
            print("✅ [EDIT HOLDING VALIDATION] Holding is not deleted")
            
            // Check stock relationship
            guard holding.stock != nil else {
                print("❌ [EDIT HOLDING VALIDATION] FAILED: Holding has no stock relationship")
                print("❌ [EDIT HOLDING VALIDATION] Stock relationship is nil - this indicates a broken relationship")
                return false
            }
            
            let stockSymbol = holding.stock?.symbol ?? "No Symbol"
            print("✅ [EDIT HOLDING VALIDATION] Holding has valid stock relationship (Symbol: \(stockSymbol))")
            
            // Check if we can access basic properties
            let quantity = holding.quantity
            let pricePerShare = holding.pricePerShare
            let datePurchased = holding.purchaseDate
            
            print("ℹ️ [EDIT HOLDING VALIDATION] Holding quantity: \(quantity)")
            print("ℹ️ [EDIT HOLDING VALIDATION] Holding price per share: \(pricePerShare?.stringValue ?? "nil")")
            print("ℹ️ [EDIT HOLDING VALIDATION] Holding date purchased: \(datePurchased?.description ?? "nil")")
            
            // Additional stock validation
            if let stock = holding.stock {
                print("ℹ️ [EDIT HOLDING VALIDATION] Stock ID: \(stock.objectID)")
                print("ℹ️ [EDIT HOLDING VALIDATION] Stock context: \(stock.managedObjectContext != nil ? "Valid" : "Nil")")
                print("ℹ️ [EDIT HOLDING VALIDATION] Stock deleted: \(stock.isDeleted)")
            }
            
            print("✅ [EDIT HOLDING VALIDATION] All validation checks passed")
            return true
        }
        
        print("🏁 [EDIT HOLDING VALIDATION] Final result: \(result)")
        return result
    }
    
    private var currentPrice: Decimal {
        holding.stock?.currentPrice?.decimalValue ?? 0
    }
    
    private var isQuantityValid: Bool {
        guard let quantityInt = Int32(quantity) else { return false }
        return quantityInt > 0
    }
    
    private var isPriceValid: Bool {
        guard let priceDecimal = Decimal(string: pricePerShare) else { return false }
        return priceDecimal > 0
    }
    
    private var isFormValid: Bool {
        return isQuantityValid && isPriceValid
    }
    
    // MARK: - Actions
    
    private func saveChanges() {
        guard !isSaving else { return }
        
        // Validate holding is still valid before saving
        guard isHoldingValid else {
            alertMessage = "This holding is no longer available for editing."
            showingAlert = true
            return
        }
        
        guard let quantityInt = Int32(quantity),
              let priceDecimal = Decimal(string: pricePerShare) else {
            alertMessage = "Please enter valid quantity and price values."
            showingAlert = true
            return
        }
        
        guard quantityInt > 0 else {
            alertMessage = "Quantity must be greater than zero."
            showingAlert = true
            return
        }
        
        guard priceDecimal > 0 else {
            alertMessage = "Price per share must be greater than zero."
            showingAlert = true
            return
        }
        
        guard datePurchased <= Date() else {
            alertMessage = "Purchase date cannot be in the future."
            showingAlert = true
            return
        }
        
        isSaving = true
        
        // Perform the update in a thread-safe way
        viewContext.performAndWait {
            // Re-validate the holding in the current context
            guard !holding.isDeleted && holding.managedObjectContext != nil else {
                DispatchQueue.main.async {
                    self.alertMessage = "This holding has been deleted."
                    self.showingAlert = true
                    self.isSaving = false
                }
                return
            }
            
            // Update the holding with all changes
            Task { @MainActor in
                portfolioManager.updateHolding(holding, quantity: quantityInt, pricePerShare: priceDecimal, datePurchased: datePurchased)
            }
            
            DispatchQueue.main.async {
                self.onHoldingUpdated()
                
                // Successful update - dismiss the sheet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isSaving = false
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    private func confirmDelete() {
        showingDeleteConfirmation = true
    }
    
    private func deleteHolding() {
        guard !isDeleting else { return }
        
        // Validate holding is still valid before deleting
        guard isHoldingValid else {
            alertMessage = "This holding is no longer available for deletion."
            showingAlert = true
            return
        }
        
        isDeleting = true
        
        // Perform the deletion in a thread-safe way
        viewContext.performAndWait {
            // Re-validate the holding in the current context
            guard !holding.isDeleted && holding.managedObjectContext != nil else {
                DispatchQueue.main.async {
                    self.alertMessage = "This holding has already been deleted."
                    self.showingAlert = true
                    self.isDeleting = false
                }
                return
            }
            
            Task { @MainActor in
                portfolioManager.deleteHolding(holding)
            }
            
            DispatchQueue.main.async {
                self.onHoldingUpdated()
                
                // Successful deletion - dismiss the sheet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isDeleting = false
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    /// Update dividend information for the current stock
    private func updateDividendInfo() {
        guard let stock = holding.stock, let symbol = stock.symbol else {
            print("❌ [DIVIDEND UPDATE] No stock or symbol found")
            print("❌ [DIVIDEND UPDATE] Holding stock: \(holding.stock?.description ?? "nil")")
            print("❌ [DIVIDEND UPDATE] Stock symbol: \(holding.stock?.symbol ?? "nil")")
            return
        }
        
        print("🔄 [DIVIDEND UPDATE] ========== UPDATE STARTED ==========")
        print("🔄 [DIVIDEND UPDATE] Starting dividend update for: \(symbol)")
        print("🔄 [DIVIDEND UPDATE] Holding ID: \(holding.objectID)")
        print("🔄 [DIVIDEND UPDATE] Stock ID: \(stock.objectID)")
        print("🔄 [DIVIDEND UPDATE] Current dividend count: \((stock.dividends?.count ?? 0))")
        print("🔄 [DIVIDEND UPDATE] Holding is valid: \(!holding.isDeleted)")
        print("🔄 [DIVIDEND UPDATE] Stock is valid: \(!stock.isDeleted)")
        print("🔄 [DIVIDEND UPDATE] Sheet is currently updating dividends: \(isUpdatingDividend)")
        print("🔄 [DIVIDEND UPDATE] ==============================")
        
        print("🔄 [DIVIDEND UPDATE] Setting isUpdatingDividend to true")
        isUpdatingDividend = true
        
        print("🔄 [DIVIDEND UPDATE] Starting async Task for API call")
        Task {
            // Show available dividend providers debug info
            let availableProviders = dividendManager.getAvailableProviders()
            let providerStatus = dividendManager.getProviderStatus()
            print("🔍 [DIVIDEND API] Available providers: \(availableProviders.count)")
            for status in providerStatus {
                print("🔍 [DIVIDEND API] Provider: \(status.name) - \(status.priority) - Available: \(status.available)")
            }
            
            // Show rate limiting info
            if let alphaVantageUsage = dividendManager.getAlphaVantageUsage() {
                print("🔍 [DIVIDEND API] Alpha Vantage Usage: \(alphaVantageUsage.requestsUsed)/\(alphaVantageUsage.dailyLimit) (resets: \(alphaVantageUsage.resetsAt))")
            }
            
            if let finnhubUsage = dividendManager.getFinnhubUsage() {
                print("🔍 [DIVIDEND API] Finnhub Usage: \(finnhubUsage.requestsUsed)/\(finnhubUsage.perSecondLimit) per second (window resets: \(finnhubUsage.windowResetsAt))")
            }
            
            // Force fetch distribution info with detailed debug output
            print("🔍 [DIVIDEND API] Calling forceUpdateDistributionInfo for \(symbol)...")
            let startTime = Date()
            let distributionInfo = await dividendManager.forceUpdateDistributionInfo(symbol: symbol)
            let endTime = Date()
            let fetchDuration = endTime.timeIntervalSince(startTime)
            print("🔍 [DIVIDEND API] Force update completed in \(String(format: "%.2f", fetchDuration)) seconds")
            
            // Debug output of API response
            print("📊 [DIVIDEND API RESPONSE] ========== START ===========")
            print("📊 [DIVIDEND API RESPONSE] Symbol: \(distributionInfo.symbol)")
            
            // API directly provides Annual Dividend, no calculation needed
            print("📊 [DIVIDEND API RESPONSE] **Annual Dividend**: \(distributionInfo.distributionRate?.description ?? "nil")")
            print("📊 [DIVIDEND API RESPONSE] Distribution Yield %: \(distributionInfo.distributionYieldPercent?.description ?? "nil")")
            print("📊 [DIVIDEND API RESPONSE] Distribution Frequency: \(distributionInfo.distributionFrequency ?? "nil")")
            print("📊 [DIVIDEND API RESPONSE] Last Ex-Date: \(distributionInfo.lastExDate?.description ?? "nil")")
            print("📊 [DIVIDEND API RESPONSE] Last Payment Date: \(distributionInfo.lastPaymentDate?.description ?? "nil")")
            print("📊 [DIVIDEND API RESPONSE] Full Name: \(distributionInfo.fullName ?? "nil")")
            print("📊 [DIVIDEND API RESPONSE] =========== END ===========")
            
            // Force save to Core Data with debug output
            print("💾 [DIVIDEND SAVE] Force saving dividend data to Core Data...")
            let saveStartTime = Date()
            await dividendManager.forceUpdateDividendToCore(distributionInfo: distributionInfo, for: stock, context: viewContext)
            let saveEndTime = Date()
            let saveDuration = saveEndTime.timeIntervalSince(saveStartTime)
            print("✅ [DIVIDEND SAVE] Dividend data force saved successfully in \(String(format: "%.3f", saveDuration)) seconds")
            
            // Check updated dividend count
            await MainActor.run {
                let updatedCount = stock.dividends?.count ?? 0
                print("📊 [DIVIDEND SAVE] Updated dividend count for \(symbol): \(updatedCount)")
                
                // Show latest dividend info if available  
                if let latestDividend = latestValidDividend {
                    print("📊 [DIVIDEND SAVE] Latest dividend: Annual Dividend=\(latestDividend.annualizedAmount?.decimalValue.description ?? "nil"), Yield=\(latestDividend.yield?.decimalValue.description ?? "nil"), Frequency=\(latestDividend.frequency ?? "nil")")
                }
            }
            
            await MainActor.run {
                isUpdatingDividend = false
                print("🔄 [DIVIDEND UPDATE] ========== UPDATE COMPLETED ==========")
                print("🔄 [DIVIDEND UPDATE] Update completed for \(symbol)")
                print("🔄 [DIVIDEND UPDATE] Holding is still valid: \(!holding.isDeleted)")
                print("🔄 [DIVIDEND UPDATE] Stock is still valid: \(!stock.isDeleted)")
                print("🔄 [DIVIDEND UPDATE] NOT calling onHoldingUpdated to avoid clearing holdingToEdit")
                print("🔄 [DIVIDEND UPDATE] Sheet should remain open and functional")
                print("🔄 [DIVIDEND UPDATE] =====================================\n")
                
                // Do NOT call onHoldingUpdated() as it will clear holdingToEdit and cause sheet to show error
                // The dividend data is already saved to Core Data and will be visible in the UI
                // onHoldingUpdated()
            }
        }
    }
    
    /// Get annual multiplier based on dividend frequency
    private func getAnnualMultiplier(for frequency: String) -> Int {
        let freq = frequency.lowercased()
        if freq.contains("monthly") {
            return 12
        } else if freq.contains("quarter") {
            return 4
        } else if freq.contains("semi") || freq.contains("half") {
            return 2
        } else if freq.contains("annual") || freq.contains("year") {
            return 1
        } else {
            // Default to quarterly if unknown
            return 4
        }
    }
}

// MARK: - NumberFormatter Extension
extension NumberFormatter {
    static let decimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}

struct EditHoldingSheet_Previews: PreviewProvider {
    static var previews: some View {
        let context = DataManager.shared.context
        
        // Create sample data for preview
        let portfolio = Portfolio(context: context)
        portfolio.name = "Sample Portfolio"
        portfolio.portfolioID = UUID()
        portfolio.createdDate = Date()
        
        let stock = Stock(context: context)
        stock.stockID = UUID()
        stock.symbol = "AAPL"
        stock.name = "Apple Inc."
        stock.currentPrice = NSDecimalNumber(value: 150.0)
        stock.lastUpdated = Date()
        
        let holding = Holding(context: context)
        holding.id = UUID()
        holding.quantity = 10
        holding.pricePerShare = NSDecimalNumber(value: 120.0)
        holding.purchaseDate = Date()
        holding.stock = stock
        holding.portfolio = portfolio
        
        return EditHoldingSheet(holding: holding, onHoldingUpdated: {})
            .environment(\.managedObjectContext, context)
    }
}