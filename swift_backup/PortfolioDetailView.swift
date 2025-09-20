import SwiftUI
import CoreData
import Combine

struct PortfolioDetailView: View {
    let portfolio: Portfolio
    @StateObject private var portfolioManager = PortfolioManager()
    @EnvironmentObject private var backgroundService: BackgroundUpdateService
    @StateObject private var exportManager = ExportManager()
    @StateObject private var dividendService = DividendCalculationService()
    @Environment(\.managedObjectContext) private var viewContext
    @State private var holdings: [Holding] = []
    @State private var showingAddHolding = false
    @State private var showingExportSheet = false
    @State private var showingAIAnalysis = false
    @State private var isRefreshing = false
    @State private var holdingToDelete: Holding?
    @State private var showingDeleteConfirmation = false
    @State private var holdingToEdit: Holding? {
        didSet {
            print("📝 [STATE CHANGE] holdingToEdit changed from \(oldValue?.objectID.description ?? "nil") to \(holdingToEdit?.objectID.description ?? "nil") at: \(Date())")
        }
    }
    @State private var showingEditHolding = false {
        didSet {
            print("📋 [STATE CHANGE] showingEditHolding changed from \(oldValue) to \(showingEditHolding) at: \(Date())")
        }
    }
    @State private var changeNotificationCancellable: AnyCancellable?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Portfolio Summary Card
                PortfolioSummaryCard(portfolio: portfolio, portfolioManager: portfolioManager, holdings: holdings, dividendService: dividendService)
                    .id("portfolio-summary-\(holdings.count)-\(holdings.map { $0.objectID.description }.joined())")
                
                // Holdings List
                HoldingsListView(
                    holdings: holdings,
                    portfolioManager: portfolioManager,
                    onHoldingDeleted: loadHoldings,
                    onDeleteRequested: { holding in
                        holdingToDelete = holding
                        showingDeleteConfirmation = true
                    },
                    onEditRequested: { holding in
                        // Validate holding before opening edit sheet with thread-safe check
                        let symbol = holding.stock?.symbol ?? "Unknown"
                        print("🎯 [HOLDING EDIT REQUEST] User tapped holding: \(symbol)")
                        print("🎯 [HOLDING EDIT REQUEST] Holding ObjectID: \(holding.objectID)")
                        
                        print("🔄 [HOLDING EDIT REQUEST] Starting validation for \(symbol)...")
                        
                        // First set the holding to edit immediately
                        print("📝 [HOLDING EDIT REQUEST] Setting holdingToEdit to: \(holding.objectID)")
                        holdingToEdit = holding
                        print("📝 [HOLDING EDIT REQUEST] holdingToEdit set to: \(holdingToEdit?.objectID.description ?? "nil")")
                        
                        Task { @MainActor in
                            if await isHoldingValidForEditing(holding) {
                                print("✅ [HOLDING EDIT REQUEST] Validation successful, opening edit sheet for \(symbol)")
                                print("📝 [HOLDING EDIT REQUEST] Setting showingEditHolding to true")
                                showingEditHolding = true
                                print("📝 [HOLDING EDIT REQUEST] showingEditHolding set to: \(showingEditHolding)")
                                print("📝 [HOLDING EDIT REQUEST] Final holdingToEdit: \(holdingToEdit?.objectID.description ?? "nil")")
                                
                                // Force a small delay to ensure state propagation
                                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                                print("📝 [HOLDING EDIT REQUEST] After delay - showingEditHolding: \(showingEditHolding), holdingToEdit: \(holdingToEdit?.objectID.description ?? "nil")")
                            } else {
                                print("❌ [HOLDING EDIT REQUEST] Validation failed for \(symbol)")
                                print("🔄 [HOLDING EDIT REQUEST] Clearing holdingToEdit and refreshing holdings...")
                                
                                // Clear the holding and refresh
                                holdingToEdit = nil
                                loadHoldings()
                                print("⚠️ [HOLDING EDIT REQUEST] Edit sheet will not be shown due to validation failure")
                            }
                        }
                    }
                )
                
                // Performance Chart - Coming Soon
                // if !holdings.isEmpty {
                //     PortfolioChartView(portfolio: portfolio)
                // }
                
            }
            .padding()
        }
        .navigationTitle(portfolio.name ?? "Portfolio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { showingAIAnalysis = true }) {
                    Image(systemName: "brain.head.profile")
                }
                
                Button(action: { showingExportSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
                
                Button(action: refreshPrices) {
                    Image(systemName: isRefreshing ? "arrow.clockwise" : "arrow.clockwise")
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(.linear(duration: 1).repeatWhileActive(isRefreshing), value: isRefreshing)
                }
                .disabled(isRefreshing)
                
                Button(action: { showingAddHolding = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddHolding) {
            AddHoldingSheet(portfolio: portfolio, onHoldingAdded: {
                loadHoldings()
                // Auto-refresh dividend data when new stock is added
                Task {
                    await refreshDividendData()
                }
            })
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportSheet(portfolio: portfolio, exportManager: exportManager)
        }
        .sheet(isPresented: $showingAIAnalysis) {
            AIPortfolioAnalysisView(portfolio: portfolio)
        }
        .sheet(isPresented: Binding(
            get: { 
                print("📋 [SHEET BINDING] get called - showingEditHolding: \(showingEditHolding)")
                return showingEditHolding 
            },
            set: { newValue in 
                print("📋 [SHEET BINDING] set called - changing from \(showingEditHolding) to \(newValue)")
                showingEditHolding = newValue 
            }
        )) {
            print("📋 [EDIT SHEET CLOSURE] Sheet content closure called at: \(Date())")
            print("📋 [EDIT SHEET CLOSURE] showingEditHolding: \(showingEditHolding)")
            print("📋 [EDIT SHEET CLOSURE] holdingToEdit: \(holdingToEdit?.objectID.description ?? "nil")")
            print("📋 [EDIT SHEET CLOSURE] holdingToEdit is nil: \(holdingToEdit == nil)")
            
            if let holding = holdingToEdit {
                print("📋 [EDIT SHEET CLOSURE] holdingToEdit exists - creating EditHoldingSheet")
                print("📋 [EDIT SHEET CLOSURE] Symbol: \(holding.stock?.symbol ?? "Unknown")")
                print("📋 [EDIT SHEET CLOSURE] Holding ObjectID: \(holding.objectID)")
                print("📋 [EDIT SHEET CLOSURE] Holding is valid: \(!holding.isDeleted)")
                print("📋 [EDIT SHEET CLOSURE] Holding context: \(holding.managedObjectContext != nil)")
                
                return AnyView(EditHoldingSheet(holding: holding) {
                    print("📋 [EDIT SHEET COMPLETION] EditHoldingSheet completion called")
                    print("📋 [EDIT SHEET COMPLETION] About to call loadHoldings()")
                    loadHoldings()
                    print("📋 [EDIT SHEET COMPLETION] loadHoldings() completed")
                    print("📋 [EDIT SHEET COMPLETION] About to clear holdingToEdit")
                    // Clear the holding reference after update
                    holdingToEdit = nil
                    print("📋 [EDIT SHEET COMPLETION] holdingToEdit cleared")
                })
            } else {
                print("❌ [EDIT SHEET CLOSURE] holdingToEdit is nil, showing error view")
                // Fallback view if holding becomes nil
                return AnyView(NavigationView {
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
                            showingEditHolding = false
                            holdingToEdit = nil
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .navigationTitle("Error")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") {
                                showingEditHolding = false
                                holdingToEdit = nil
                            }
                        }
                    }
                })
            }
        }
        .alert("Delete Holding", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                holdingToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let holding = holdingToDelete {
                    portfolioManager.deleteHolding(holding)
                    loadHoldings()
                }
                holdingToDelete = nil
            }
        } message: {
            if let holding = holdingToDelete {
                Text("Are you sure you want to delete your \(holding.stock?.symbol ?? "Unknown") holding? This action cannot be undone.")
            }
        }
        .onAppear {
            loadHoldings()
            setupChangeNotifications()
        }
        .onDisappear {
            changeNotificationCancellable?.cancel()
        }
    }
    
    @MainActor
    private func loadHoldings() {
        // Refresh the portfolio to get latest data (already on main actor)
        viewContext.refresh(portfolio, mergeChanges: true)
        
        // Load holdings with proper context validation
        let holdingsSet = portfolio.holdings as? Set<Holding> ?? []
        let validHoldings = holdingsSet.filter { holding in
            // Only include holdings that are valid and not deleted
            !holding.isDeleted && 
            holding.managedObjectContext != nil && 
            holding.stock != nil
        }
        
        let sortedHoldings = validHoldings
            .sorted { ($0.stock?.symbol ?? "") < ($1.stock?.symbol ?? "") }
        
        // Update directly since we're already on MainActor
        holdings = sortedHoldings
    }
    
    private func refreshPrices() {
        isRefreshing = true
        Task {
            await backgroundService.updateAllStockPrices()
            await MainActor.run {
                loadHoldings()
                isRefreshing = false
            }
        }
    }
    
    @MainActor
    private func refreshDividendData() async {
        print("🔄 [AUTO-REFRESH] Refreshing dividend data after stock addition...")
        
        // Force refresh dividend data for all holdings
        let _ = await dividendService.forceRefreshAllDividends(for: holdings)
        
        print("✅ [AUTO-REFRESH] Dividend data refreshed automatically")
    }
    
    /// Thread-safe validation of holding for editing
    @MainActor
    private func isHoldingValidForEditing(_ holding: Holding) async -> Bool {
        let holdingID = holding.objectID
        let originalSymbol = holding.stock?.symbol ?? "Unknown"
        
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                // Detailed diagnostic logging
                print("🔍 [HOLDING VALIDATION] Starting validation for holding with symbol: \(originalSymbol)")
                print("🔍 [HOLDING VALIDATION] Holding ObjectID: \(holdingID)")
                
                // Try to get the holding from context
                guard let contextHolding = try? self.viewContext.existingObject(with: holdingID) as? Holding else {
                    print("❌ [HOLDING VALIDATION] FAILED: Cannot retrieve holding from context")
                    print("❌ [HOLDING VALIDATION] Reason: existingObject(with:) failed or returned wrong type")
                    continuation.resume(returning: false)
                    return
                }
                
                print("✅ [HOLDING VALIDATION] Successfully retrieved holding from context")
                
                // Check if holding is deleted
                if contextHolding.isDeleted {
                    print("❌ [HOLDING VALIDATION] FAILED: Holding is marked as deleted")
                    continuation.resume(returning: false)
                    return
                }
                print("✅ [HOLDING VALIDATION] Holding is not deleted")
                
                // Check managed object context
                if contextHolding.managedObjectContext == nil {
                    print("❌ [HOLDING VALIDATION] FAILED: Holding has no managed object context")
                    continuation.resume(returning: false)
                    return
                }
                print("✅ [HOLDING VALIDATION] Holding has valid managed object context")
                
                // Check stock relationship
                if contextHolding.stock == nil {
                    print("❌ [HOLDING VALIDATION] FAILED: Holding has no stock relationship")
                    print("❌ [HOLDING VALIDATION] Stock is nil - this may indicate a broken relationship")
                    continuation.resume(returning: false)
                    return
                }
                
                let stockSymbol = contextHolding.stock?.symbol ?? "No Symbol"
                print("✅ [HOLDING VALIDATION] Holding has valid stock relationship (Symbol: \(stockSymbol))")
                
                // Additional diagnostic info
                print("ℹ️ [HOLDING VALIDATION] Holding quantity: \(contextHolding.quantity)")
                print("ℹ️ [HOLDING VALIDATION] Holding price per share: \(contextHolding.pricePerShare?.stringValue ?? "nil")")
                print("ℹ️ [HOLDING VALIDATION] Holding date purchased: \(contextHolding.datePurchased?.description ?? "nil")")
                
                print("✅ [HOLDING VALIDATION] All validation checks passed")
                continuation.resume(returning: true)
            }
        }
    }
    
    /// Setup Core Data change notifications with proper threading
    private func setupChangeNotifications() {
        changeNotificationCancellable = NotificationCenter.default
            .publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.global(qos: .utility))
            .compactMap { notification -> NSManagedObjectContext? in
                // Only respond to saves that might affect our portfolio
                guard let context = notification.object as? NSManagedObjectContext,
                      context !== self.viewContext else { return nil }
                return context
            }
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.global(qos: .utility))
            .receive(on: DispatchQueue.main)
            .sink { _ in
                // Reload holdings when context changes
                Task { @MainActor in
                    loadHoldings()
                }
            }
    }
}

struct PortfolioSummaryCard: View {
    let portfolio: Portfolio
    let portfolioManager: PortfolioManager
    let holdings: [Holding]
    let dividendService: DividendCalculationService
    
    @State private var dividendInfo: PortfolioDividendInfo? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            // Single Investment Overview Section
            VStack(spacing: 16) {
                // Section Header
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        
                        Text("Investment Overview")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // Refresh button for dividends
                    if let dividends = dividendInfo, dividends.totalAnnualDividends == 0 {
                        Button(action: {
                            Task {
                                await forceRefreshDividends()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12))
                                Text("Refresh")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Investment metrics with dividends integrated - Two Column Layout
                HStack(alignment: .top, spacing: 20) {
                    // Left Column: Total Value
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Total Value")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        // Create attributed string with colored percentage
                        HStack(spacing: 0) {
                            Text("$\(Int(NSDecimalNumber(decimal: currentValue).doubleValue)) ")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .minimumScaleFactor(0.8)
                            
                            Text("(\(percentageGainLoss)%)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(totalGainLoss >= 0 ? .green : .red)
                                .minimumScaleFactor(0.8)
                        }
                        .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Right Column: Annual Dividends
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Annual Dividends")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        if let dividends = dividendInfo {
                            if dividends.hasDividends {
                                HStack(spacing: 0) {
                                    Text("$\(Int(NSDecimalNumber(decimal: dividends.totalAnnualDividends).doubleValue)) ")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .minimumScaleFactor(0.8)
                                    
                                    Text("(\(NSDecimalNumber(decimal: dividends.portfolioYieldPercent).doubleValue, specifier: "%.2f")%)")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.blue)
                                        .minimumScaleFactor(0.8)
                                }
                                .lineLimit(1)
                            } else {
                                HStack(spacing: 6) {
                                    Text("$\(Int(NSDecimalNumber(decimal: dividends.totalAnnualDividends).doubleValue))")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .minimumScaleFactor(0.8)
                                        .lineLimit(1)
                                    
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    
                                    Text("No data")
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text("Calculating...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.15), radius: 8, x: 0, y: 4)
        .task {
            await loadDividendInfo()
        }
        .onChange(of: holdings) { _ in
            Task {
                await loadDividendInfo()
            }
        }
    }
    
    private func loadDividendInfo() async {
        let info = await dividendService.calculateAnnualDividends(for: holdings)
        await MainActor.run {
            dividendInfo = info
        }
    }
    
    private func forceRefreshDividends() async {
        print("🔄 [UI] Force refreshing dividend data...")
        let info = await dividendService.forceRefreshAllDividends(for: holdings)
        await MainActor.run {
            dividendInfo = info
        }
        print("✅ [UI] Dividend data refreshed")
    }
    
    private var currentValue: Decimal {
        holdings.reduce(0) { total, holding in
            let currentPrice = holding.stock?.effectiveCurrentPrice ?? 0
            let quantity = Decimal(holding.quantity)
            return total + (currentPrice * quantity)
        }
    }
    
    private var totalPurchaseValue: Decimal {
        holdings.reduce(0) { total, holding in
            let purchasePrice = holding.pricePerShare?.decimalValue ?? 0
            let quantity = Decimal(holding.quantity)
            return total + (purchasePrice * quantity)
        }
    }
    
    private var totalGainLoss: Decimal {
        holdings.reduce(0) { total, holding in
            let gainLoss = HoldingGainLossCalculator.calculateGainLoss(for: holding, context: "SUMMARY")
            return total + gainLoss
        }
    }
    
    private var percentageGainLoss: String {
        let purchaseVal = totalPurchaseValue
        let currentVal = currentValue
        
        // Calculate percentage using the same method as individual holdings
        // Percentage = ((current_value - purchase_value) / purchase_value) * 100
        if purchaseVal > 0 {
            let gainLoss = currentVal - purchaseVal
            let percentage = NSDecimalNumber(decimal: gainLoss).doubleValue / NSDecimalNumber(decimal: purchaseVal).doubleValue * 100
            
            // Format with proper +/- sign
            let sign = percentage >= 0 ? "+" : ""
            let formattedPercentage = String(format: "%.0f", percentage)
            return "\(sign)\(formattedPercentage)"
        } else {
            return "0"
        }
    }
}

struct HoldingsListView: View {
    let holdings: [Holding]
    let portfolioManager: PortfolioManager
    let onHoldingDeleted: () -> Void
    let onDeleteRequested: (Holding) -> Void
    let onEditRequested: (Holding) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Holdings")
                .font(.title3)
                .fontWeight(.semibold)
            
            if holdings.isEmpty {
                Text("No holdings yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(holdings, id: \.holdingID) { holding in
                        HoldingRowView(holding: holding, portfolioManager: portfolioManager)
                            .onTapGesture {
                                onEditRequested(holding)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    onDeleteRequested(holding)
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button("Edit") {
                                    onEditRequested(holding)
                                }
                                .tint(.blue)
                            }
                    }
                }
            }
        }
    }
}

struct HoldingRowView: View {
    let holding: Holding
    let portfolioManager: PortfolioManager
    
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(holding.stock?.symbol ?? "Unknown")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(holding.stock?.companyName ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("\(holding.quantity) shares")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Data source indicators
                    if let stock = holding.stock {
                        HStack(spacing: 4) {
                            if stock.hasPriceData {
                                Label(stock.priceDataSource, systemImage: "globe")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            } else {
                                Label("N/A", systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if currentPrice > 0 {
                    Text(formatGainLoss(currentValue))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 4) {
                        Image(systemName: gainLoss >= 0 ? "arrow.up" : "arrow.down")
                            .font(.caption)
                        Text(formatGainLoss(gainLoss))
                            .font(.caption)
                    }
                    .foregroundColor(gainLoss >= 0 ? .green : .red)
                    
                    HStack(spacing: 4) {
                        Text(formatGainLoss(currentPrice))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("N/A")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .contentShape(Rectangle()) // Makes the entire row tappable
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double tap to edit this holding")
    }
    
    private var currentPrice: Decimal {
        holding.stock?.effectiveCurrentPrice ?? 0
    }
    
    private var currentValue: Decimal {
        currentPrice * Decimal(holding.quantity)
    }
    
    private var purchaseValue: Decimal {
        (holding.pricePerShare?.decimalValue ?? 0) * Decimal(holding.quantity)
    }
    
    private var gainLoss: Decimal {
        return HoldingGainLossCalculator.calculateGainLoss(for: holding, context: "UI")
    }
    
    private func formatGainLoss(_ amount: Decimal) -> String {
        // Use same formatting as TextExportManager for consistency
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0"
    }
}


extension Animation {
    func repeatWhileActive(_ isActive: Bool) -> Animation {
        isActive ? self.repeatForever(autoreverses: false) : self
    }
}

// MARK: - Helper Extensions

struct PortfolioDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let portfolio = Portfolio(context: DataManager.shared.context)
        portfolio.name = "Sample Portfolio"
        portfolio.portfolioID = UUID()
        portfolio.createdDate = Date()
        
        return PortfolioDetailView(portfolio: portfolio)
            .environment(\.managedObjectContext, DataManager.shared.context)
            .environmentObject(BackgroundUpdateService())
    }
}