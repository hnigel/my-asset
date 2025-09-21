import Foundation
import CoreData

class DividendManager: ObservableObject {
    
    // MARK: - Properties
    
    private let dataManager = DataManager.shared
    private var distributionCache: [String: (info: DistributionInfo, timestamp: Date)] = [:]
    private let cacheValidityInterval: TimeInterval = 1800 // 30 minutes (dividend data changes less frequently)
    
    // Daily update limiting for dividend data
    private var lastDividendUpdateDate: Date?
    private let dividendUpdateInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    
    // Dividend providers in order of preference (optimized for QQQI accuracy)
    private let providers: [DividendProvider] = [
        EODHDDividendService(),             // Primary - Best frequency detection & accuracy
        YahooFinanceDividendService(),      // Secondary - Free, improved frequency detection
        NasdaqDividendService(),            // Tertiary - Free, ETF-aware frequency detection
        FinnhubDividendService(),           // Quaternary - Professional API, good for complex cases
        AlphaVantageDividendService()       // Quinary - Improved but rate limited
    ]
    
    // MARK: - Public Methods
    
    func fetchDistributionInfo(symbol: String) async -> DistributionInfo {
        let cleanSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Check cache first - don't let daily limits prevent fresh symbol fetches
        if let cachedData = distributionCache[cleanSymbol],
           Date().timeIntervalSince(cachedData.timestamp) < cacheValidityInterval {
            print("💾 Using cached dividend data for \(cleanSymbol) (cache still valid)")
            return cachedData.info
        }
        
        // Check daily update limit for dividend data (only after cache miss)
        let currentDate = Date()
        if let lastUpdate = lastDividendUpdateDate,
           Calendar.current.isDate(lastUpdate, inSameDayAs: currentDate) {
            print("⚠️ Daily dividend update limit reached, but \(cleanSymbol) not in cache")
            print("🔄 Proceeding with API fetch for new symbol \(cleanSymbol)")
        }
        
        // Try providers in order of priority
        var attemptedProviders: [String] = []
        
        for provider in providers {
            guard provider.isAvailable else {
                print("⚠️ \(provider.providerName) is not available, skipping...")
                continue
            }
            
            do {
                let distributionInfo = try await provider.fetchDividendInfo(symbol: cleanSymbol)
                print("✓ \(provider.providerName) provided dividend data for \(cleanSymbol)")
                
                // Cache successful result and update daily timestamp
                distributionCache[cleanSymbol] = (info: distributionInfo, timestamp: Date())
                lastDividendUpdateDate = Date()
                return distributionInfo
                
            } catch {
                print("✗ \(provider.providerName) failed for \(cleanSymbol): \(error.localizedDescription)")
                attemptedProviders.append(provider.providerName)
                
                // Continue to next provider
                continue
            }
        }
        
        // All providers failed - return empty distribution info
        print("❌ All dividend providers failed for \(cleanSymbol). Tried: \(attemptedProviders.joined(separator: ", "))")
        let emptyDistributionInfo = DistributionInfo(
            symbol: cleanSymbol,
            distributionRate: nil,
            distributionYieldPercent: nil,
            distributionFrequency: nil,
            lastExDate: nil,
            lastPaymentDate: nil,
            fullName: nil
        )
        
        // Don't cache failed results - allow immediate retry
        return emptyDistributionInfo
    }
    
    /// Force update distribution info, bypassing cache and daily limits
    func forceUpdateDistributionInfo(symbol: String) async -> DistributionInfo {
        let cleanSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        print("🔄 [DIVIDEND FORCE UPDATE] Forcing API update for \(cleanSymbol), bypassing cache and daily limits")
        
        // Clear existing cache for this symbol
        distributionCache.removeValue(forKey: cleanSymbol)
        print("📋 [DIVIDEND FORCE UPDATE] Cleared cache for \(cleanSymbol)")
        
        // Try providers in order of priority
        var attemptedProviders: [String] = []
        
        for provider in providers {
            guard provider.isAvailable else {
                print("⚠️ \(provider.providerName) is not available, skipping...")
                continue
            }
            
            do {
                print("🔍 [DIVIDEND FORCE UPDATE] Trying \(provider.providerName) for \(cleanSymbol)...")
                let distributionInfo = try await provider.fetchDividendInfo(symbol: cleanSymbol)
                print("✅ \(provider.providerName) provided dividend data for \(cleanSymbol)")
                
                // Cache successful result and update daily timestamp
                distributionCache[cleanSymbol] = (info: distributionInfo, timestamp: Date())
                lastDividendUpdateDate = Date()
                print("📋 [DIVIDEND FORCE UPDATE] Cached new data for \(cleanSymbol)")
                return distributionInfo
                
            } catch {
                print("✗ \(provider.providerName) failed for \(cleanSymbol): \(error.localizedDescription)")
                attemptedProviders.append(provider.providerName)
                
                // Continue to next provider
                continue
            }
        }
        
        // All providers failed - return empty distribution info
        print("❌ [DIVIDEND FORCE UPDATE] All dividend providers failed for \(cleanSymbol). Tried: \(attemptedProviders.joined(separator: ", "))")
        let emptyDistributionInfo = DistributionInfo(
            symbol: cleanSymbol,
            distributionRate: nil,
            distributionYieldPercent: nil,
            distributionFrequency: nil,
            lastExDate: nil,
            lastPaymentDate: nil,
            fullName: nil
        )
        
        // Don't cache failed results - allow immediate retry
        return emptyDistributionInfo
    }
    
    func fetchMultipleDistributionInfo(symbols: [String]) async -> [String: DistributionInfo] {
        var results: [String: DistributionInfo] = [:]
        
        // Use TaskGroup for concurrent requests
        await withTaskGroup(of: (String, DistributionInfo).self) { group in
            for symbol in symbols {
                group.addTask {
                    let info = await self.fetchDistributionInfo(symbol: symbol)
                    return (symbol, info)
                }
            }
            
            for await (symbol, info) in group {
                results[symbol] = info
            }
        }
        
        return results
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        distributionCache.removeAll()
        lastDividendUpdateDate = nil  // Clear daily limit
        print("Dividend cache and daily limits cleared")
    }
    
    func isDistributionCached(symbol: String) -> Bool {
        guard let cachedData = distributionCache[symbol.uppercased()] else { return false }
        return Date().timeIntervalSince(cachedData.timestamp) < cacheValidityInterval
    }
    
    func setCachedDistribution(symbol: String, info: DistributionInfo) {
        distributionCache[symbol.uppercased()] = (info: info, timestamp: Date())
    }
    
    var cacheSize: Int {
        return distributionCache.count
    }
    
    // MARK: - Provider Management
    
    func getAvailableProviders() -> [DividendProvider] {
        return providers.filter { $0.isAvailable }
    }
    
    func getProviderStatus() -> [(name: String, available: Bool, priority: String)] {
        return providers.enumerated().map { index, provider in
            let priority: String
            switch index {
            case 0: priority = "Primary"
            case 1: priority = "Secondary"
            case 2: priority = "Tertiary"
            case 3: priority = "Quaternary"
            default: priority = "Quinary"
            }
            return (name: provider.providerName, available: provider.isAvailable, priority: priority)
        }
    }
    
    // Get Alpha Vantage usage info if available
    func getAlphaVantageUsage() -> (requestsUsed: Int, dailyLimit: Int, resetsAt: Date)? {
        guard let alphaVantageService = providers.compactMap({ $0 as? AlphaVantageDividendService }).first else {
            return nil
        }
        return alphaVantageService.getUsageInfo()
    }
    
    // Get Finnhub dividend usage info if available
    func getFinnhubUsage() -> (requestsUsed: Int, perSecondLimit: Int, windowResetsAt: Date)? {
        guard let finnhubService = providers.compactMap({ $0 as? FinnhubDividendService }).first else {
            return nil
        }
        return finnhubService.getUsageInfo()
    }
    
    // MARK: - Core Data Integration
    
    /// 將API獲取的配息資訊儲存到Core Data
    func saveDividendToCore(distributionInfo: DistributionInfo, for stock: Stock, context: NSManagedObjectContext? = nil) async {
        guard let rateDouble = distributionInfo.distributionRate,
              rateDouble > 0 else { return }
        
        let rate = Decimal(rateDouble)
        let contextToUse = context ?? dataManager.context
        let stockObjectID = stock.objectID
        
        // Use the thread-safe CoreDataThreadingHelper
        do {
            try await CoreDataThreadingHelper.safeWrite(backgroundContext: contextToUse) { context in
                // Get the stock in the correct context
                guard let stockInContext = try context.existingObject(with: stockObjectID) as? Stock else {
                    print("Failed to get stock in context for dividend save")
                    return
                }
                
                // 檢查是否已有相同的配息記錄
                let existingDividend = self.checkExistingDividendSync(
                    for: stockInContext,
                    amount: rate,
                    paymentDate: distributionInfo.lastPaymentDate,
                    context: context
                )
                
                if existingDividend == nil {
                    let _ = Dividend.create(
                        in: context,
                        for: stockInContext,
                        amount: rate,
                        currency: "USD",
                        dividendType: .dividend,
                        frequency: self.mapFrequencyToDividendFrequency(distributionInfo.distributionFrequency),
                        paymentDate: distributionInfo.lastPaymentDate,
                        exDividendDate: distributionInfo.lastExDate,
                        annualizedAmount: self.calculateAnnualizedAmount(rate: rate, frequency: distributionInfo.distributionFrequency),
                        yield: distributionInfo.distributionYieldPercent.map { Decimal($0 / 100) },
                        isUserProvided: false,
                        dataSource: "API"
                    )
                    
                    print("✓ Saved dividend for \(stockInContext.symbol ?? "Unknown") to Core Data")
                }
            }
        } catch {
            print("Failed to save dividend to Core Data: \(error)")
        }
    }
    
    /// 強制保存或更新配息資訊到Core Data（用於用戶手動更新）
    func forceUpdateDividendToCore(distributionInfo: DistributionInfo, for stock: Stock, context: NSManagedObjectContext? = nil) async {
        guard let annualDividendDouble = distributionInfo.distributionRate,
              annualDividendDouble > 0 else { 
            print("⚠️ [DIVIDEND FORCE SAVE] No valid annual dividend, skipping save")
            return 
        }
        
        let annualDividend = Decimal(annualDividendDouble)
        let contextToUse = context ?? dataManager.context
        let stockObjectID = stock.objectID
        
        // No calculation needed - store Annual Dividend directly
        print("💾 [DIVIDEND FORCE SAVE] Storing Annual Dividend directly: \(annualDividend)")
        
        print("💾 [DIVIDEND FORCE SAVE] Force saving/updating dividend data for \(stock.symbol ?? "Unknown")...")
        
        // Use the thread-safe CoreDataThreadingHelper
        do {
            try await CoreDataThreadingHelper.safeWrite(backgroundContext: contextToUse) { context in
                // Get the stock in the correct context
                guard let stockInContext = try context.existingObject(with: stockObjectID) as? Stock else {
                    print("Failed to get stock in context for dividend force save")
                    return
                }
                
                // Check if there's an existing dividend record (using annual dividend for comparison)
                let existingDividend = self.checkExistingDividendSync(
                    for: stockInContext,
                    amount: annualDividend,
                    paymentDate: distributionInfo.lastPaymentDate,
                    context: context
                )
                
                if let existing = existingDividend {
                    // Update existing dividend record with new architecture
                    print("💾 [DIVIDEND FORCE SAVE] Updating existing dividend record")
                    print("💾 [DIVIDEND FORCE SAVE] Annual Dividend: \(annualDividend)")
                    print("💾 [DIVIDEND FORCE SAVE] Yield: \(distributionInfo.distributionYieldPercent ?? 0)%")
                    
                    // Store only Annual Dividend, no per-payment calculation
                    existing.amount = 0.0 // Not needed for annual calculation
                    existing.annualizedAmount = NSDecimalNumber(decimal: annualDividend)
                    existing.yield = distributionInfo.distributionYieldPercent.map { NSDecimalNumber(decimal: Decimal($0 / 100)) }
                    existing.currency = "USD"
                    existing.frequency = self.mapFrequencyToDividendFrequency(distributionInfo.distributionFrequency)?.rawValue
                    existing.paymentDate = distributionInfo.lastPaymentDate
                    existing.exDividendDate = distributionInfo.lastExDate
                    existing.dataSource = "API"
                    existing.lastUpdated = Date()
                    
                    print("✅ [DIVIDEND FORCE SAVE] Updated existing dividend record for \(stockInContext.symbol ?? "Unknown")")
                } else {
                    // Create new dividend record with new architecture
                    print("💾 [DIVIDEND FORCE SAVE] Creating new dividend record")
                    print("💾 [DIVIDEND FORCE SAVE] Annual Dividend: \(annualDividend)")
                    print("💾 [DIVIDEND FORCE SAVE] Yield: \(distributionInfo.distributionYieldPercent ?? 0)%")
                    
                    let _ = Dividend.create(
                        in: context,
                        for: stockInContext,
                        amount: Decimal(0), // No per-payment amount needed
                        currency: "USD",
                        dividendType: .dividend,
                        frequency: self.mapFrequencyToDividendFrequency(distributionInfo.distributionFrequency),
                        paymentDate: distributionInfo.lastPaymentDate,
                        exDividendDate: distributionInfo.lastExDate,
                        annualizedAmount: annualDividend, // Store Annual Dividend directly
                        yield: distributionInfo.distributionYieldPercent.map { Decimal($0 / 100) },
                        isUserProvided: false,
                        dataSource: "API"
                    )
                    
                    print("✅ [DIVIDEND FORCE SAVE] Created new dividend record for \(stockInContext.symbol ?? "Unknown")")
                }
            }
        } catch {
            print("Failed to force save dividend to Core Data: \(error)")
        }
    }
    
    /// 同步檢查是否已存在相同的配息記錄（用於CoreDataThreadingHelper內部）
    private func checkExistingDividendSync(for stock: Stock, amount: Decimal, paymentDate: Date?, context: NSManagedObjectContext) -> Dividend? {
        let request: NSFetchRequest<Dividend> = Dividend.fetchRequest()
        var predicates: [NSPredicate] = [NSPredicate(format: "stock == %@", stock)]
        
        if let paymentDate = paymentDate {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: paymentDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            predicates.append(NSPredicate(format: "paymentDate >= %@ AND paymentDate < %@", startOfDay as NSDate, endOfDay as NSDate))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
    }
    
    /// 檢查是否已存在相同的配息記錄
    private func checkExistingDividend(for stock: Stock, amount: Decimal, paymentDate: Date?) async -> Dividend? {
        let context = dataManager.context
        let stockID = stock.objectID
        
        return await withCheckedContinuation { continuation in
            context.perform {
                guard let stockInContext = try? context.existingObject(with: stockID) as? Stock else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let request: NSFetchRequest<Dividend> = Dividend.fetchRequest()
                var predicates = [NSPredicate(format: "stock == %@", stockInContext)]
                predicates.append(NSPredicate(format: "amount == %@", amount as NSDecimalNumber))
                
                if let paymentDate = paymentDate {
                    predicates.append(NSPredicate(format: "paymentDate == %@", paymentDate as NSDate))
                }
                
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                request.fetchLimit = 1
                
                let result = try? context.fetch(request).first
                continuation.resume(returning: result)
            }
        }
    }
    
    /// 創建手動配息記錄
    @MainActor
    func createManualDividend(
        for stock: Stock,
        amount: Decimal,
        currency: String = "USD",
        dividendType: DividendType = .dividend,
        frequency: DividendFrequency? = nil,
        paymentDate: Date? = nil,
        exDividendDate: Date? = nil,
        notes: String? = nil
    ) -> Dividend {
        let context = dataManager.context
        
        let dividend = Dividend.create(
            in: context,
            for: stock,
            amount: amount,
            currency: currency,
            dividendType: dividendType,
            frequency: frequency,
            paymentDate: paymentDate,
            exDividendDate: exDividendDate,
            isUserProvided: true,
            dataSource: "Manual",
            notes: notes
        )
        
        dataManager.save()
        return dividend
    }
    
    /// 獲取股票的所有配息記錄
    func getDividends(for stock: Stock) -> [Dividend] {
        let context = dataManager.context
        let request = Dividend.fetchRequest(for: stock)
        
        return (try? context.fetch(request)) ?? []
    }
    
    /// 獲取即將到來的配息
    func getUpcomingDividends() -> [Dividend] {
        let context = dataManager.context
        let request = Dividend.fetchUpcomingDividends()
        
        return (try? context.fetch(request)) ?? []
    }
    
    /// 計算持股的總配息收入
    func calculateTotalDividendIncome(for holding: Holding, in timeRange: DateInterval? = nil) -> Decimal {
        guard let stock = holding.stock else { return 0 }
        
        let context = dataManager.context
        let request: NSFetchRequest<Dividend> = Dividend.fetchRequest()
        
        var predicates = [NSPredicate(format: "stock == %@", stock)]
        
        if let timeRange = timeRange {
            predicates.append(NSPredicate(
                format: "paymentDate >= %@ AND paymentDate <= %@",
                timeRange.start as NSDate,
                timeRange.end as NSDate
            ))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        guard let dividends = try? context.fetch(request) else { return 0 }
        
        return dividends.reduce(0) { total, dividend in
            total + dividend.calculateDividendIncome(for: holding)
        }
    }
    
    /// 刪除配息記錄
    @MainActor
    func deleteDividend(_ dividend: Dividend) {
        let context = dataManager.context
        context.delete(dividend)
        dataManager.save()
    }
    
    // MARK: - Helper Methods
    
    private func mapFrequencyToDividendFrequency(_ frequency: String?) -> DividendFrequency? {
        guard let frequency = frequency?.lowercased() else { return nil }
        
        if frequency.contains("month") {
            return .monthly
        } else if frequency.contains("quarter") {
            return .quarterly
        } else if frequency.contains("semi") || frequency.contains("half") {
            return .semiAnnually
        } else if frequency.contains("annual") || frequency.contains("year") {
            return .annually
        } else {
            return .irregular
        }
    }
    
    private func getPaymentsPerYear(for frequency: String) -> Int {
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
    
    private func calculateAnnualizedAmount(rate: Decimal, frequency: String?) -> Decimal? {
        guard let frequency = mapFrequencyToDividendFrequency(frequency) else { return nil }
        return rate * Decimal(frequency.paymentsPerYear)
    }
}