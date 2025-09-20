import Foundation

/**
 * Demo/Example Usage of the Modular Stock Price Service Architecture
 * 
 * This file demonstrates how to use both the individual services
 * and the unified interface provided by ModularStockPriceService.
 */
class StockServiceDemo {
    
    // MARK: - Using Individual Services
    
    func demonstrateIndividualServices() async {
        print("=== Demonstrating Individual Services ===\n")
        
        // Using Yahoo Finance Stock Service directly
        let yahooStockService = YahooFinanceStockService()
        print("Testing \(yahooStockService.providerName) (Available: \(yahooStockService.isAvailable))")
        
        do {
            let quote = try await yahooStockService.fetchStockPrice(symbol: "AAPL")
            print("✓ Got AAPL price: \(quote.formattedPrice) from \(yahooStockService.providerName)")
        } catch {
            print("✗ \(yahooStockService.providerName) failed: \(error.localizedDescription)")
        }
        
        // Using Nasdaq Dividend Service directly  
        let nasdaqDividendService = NasdaqDividendService()
        print("\nTesting \(nasdaqDividendService.providerName) (Available: \(nasdaqDividendService.isAvailable))")
        
        do {
            let dividend = try await nasdaqDividendService.fetchDividendInfo(symbol: "AAPL")
            print("✓ Got AAPL dividend info from \(nasdaqDividendService.providerName)")
            if let rate = dividend.distributionRate {
                print("  Annual Dividend: $\(String(format: "%.2f", rate))")
            }
            if let yield = dividend.distributionYieldPercent {
                print("  Dividend Yield: \(String(format: "%.2f", yield))%")
            }
        } catch {
            print("✗ \(nasdaqDividendService.providerName) failed: \(error.localizedDescription)")
        }
        
        print("\n")
    }
    
    // MARK: - Using Manager Classes
    
    func demonstrateManagers() async {
        print("=== Demonstrating Manager Classes ===\n")
        
        let stockManager = StockPriceManager()
        let dividendManager = DividendManager()
        
        // Stock Price Manager handles fallbacks automatically
        print("Testing Stock Price Manager with fallback logic:")
        do {
            let quote = try await stockManager.fetchStockPrice(symbol: "MSFT")
            print("✓ Got MSFT price: \(quote.formattedPrice)")
        } catch {
            print("✗ All stock providers failed: \(error.localizedDescription)")
        }
        
        // Dividend Manager handles fallbacks automatically
        print("\nTesting Dividend Manager with fallback logic:")
        let dividendInfo = await dividendManager.fetchDistributionInfo(symbol: "MSFT")
        if let rate = dividendInfo.distributionRate {
            print("✓ Got MSFT dividend rate: $\(String(format: "%.2f", rate))")
        } else {
            print("✗ No dividend data available for MSFT")
        }
        
        // Provider status
        print("\nStock Provider Status:")
        for status in stockManager.getProviderStatus() {
            print("  \(status.priority): \(status.name) - \(status.available ? "Available" : "Unavailable")")
        }
        
        print("\nDividend Provider Status:")
        for status in dividendManager.getProviderStatus() {
            print("  \(status.priority): \(status.name) - \(status.available ? "Available" : "Unavailable")")
        }
        
        print("\n")
    }
    
    // MARK: - Using Unified Interface
    
    func demonstrateUnifiedInterface() async {
        print("=== Demonstrating Unified Interface ===\n")
        
        let service = await MainActor.run { ModularStockPriceService() }
        
        // This maintains backward compatibility with the original StockPriceService API
        print("Testing unified interface (backward compatible):")
        
        do {
            let quote = try await service.fetchStockPrice(symbol: "GOOGL")
            print("✓ Got GOOGL price: \(quote.formattedPrice)")
        } catch {
            print("✗ Failed to get GOOGL price: \(error.localizedDescription)")
        }
        
        let dividendInfo = await service.fetchDistributionInfo(symbol: "GOOGL")
        if let rate = dividendInfo.distributionRate {
            print("✓ Got GOOGL dividend rate: $\(String(format: "%.2f", rate))")
        } else {
            print("ℹ️ No dividend data available for GOOGL (as expected - they don't pay dividends)")
        }
        
        // Batch operations
        print("\nTesting batch operations:")
        let symbols = ["AAPL", "MSFT", "GOOGL"]
        let quotes = await service.fetchMultipleStockPrices(symbols: symbols)
        print("✓ Successfully fetched \(quotes.count)/\(symbols.count) stock quotes")
        
        for (symbol, quote) in quotes {
            print("  \(symbol): \(quote.formattedPrice)")
        }
        
        // System health check
        print("\nSystem Health Check:")
        let healthReport = await service.performHealthCheck()
        print(healthReport.summary)
        
        print("\n")
    }
    
    // MARK: - Using Legacy Interface
    
    func demonstrateLegacyCompatibility() async {
        print("=== Demonstrating Legacy Compatibility ===\n")
        
        // The original StockPriceService now uses the modular architecture internally
        let legacyService = await MainActor.run { StockPriceService() }
        
        print("Testing original StockPriceService interface (now powered by modular architecture):")
        
        do {
            let quote = try await legacyService.fetchStockPrice(symbol: "TSLA")
            print("✓ Got TSLA price: \(quote.formattedPrice)")
        } catch {
            print("✗ Failed to get TSLA price: \(error.localizedDescription)")
        }
        
        // All original methods still work
        let _ = await legacyService.fetchDistributionInfo(symbol: "TSLA")
        print("✓ Dividend info request completed")
        
        // Cache operations
        let cacheSize = await MainActor.run { legacyService.cacheSize }
        let isCached = await MainActor.run { legacyService.isCached(symbol: "TSLA") }
        print("Cache size: \(cacheSize) items")
        print("Is TSLA cached: \(isCached)")
        
        // New features available through extensions
        print("\nNew modular features available:")
        let stockProviders = await MainActor.run { legacyService.getStockProviderStatus() }
        print("Available stock providers: \(stockProviders.filter { $0.available }.count)")
        
        let healthReport = await legacyService.performHealthCheck()
        print("System health: \(healthReport.systemWorking ? "Good" : "Issues detected")")
        
        print("\n")
    }
    
    // MARK: - Dividend Provider Testing
    
    func testDividendProvidersWithQQQI() async {
        print("🧪 Testing dividend providers with QQQI (Invesco NASDAQ Internet ETF)")
        print("📊 Expected: Distribution rate ~14.42, Frequency: Monthly")
        print("=" + String(repeating: "=", count: 60))
        
        let providers: [DividendProvider] = [
            YahooFinanceDividendService(),
            EODHDDividendService(),
            NasdaqDividendService(),
            AlphaVantageDividendService(),
            FinnhubDividendService()
        ]
        
        var results: [(provider: String, success: Bool, data: DistributionInfo?, error: String?, score: Double)] = []
        
        for provider in providers {
            print("\n🔍 Testing \(provider.providerName)...")
            
            guard provider.isAvailable else {
                print("  ❌ Provider not available (missing API key or configuration)")
                results.append((provider: provider.providerName, success: false, data: nil, error: "Not available", score: 0.0))
                continue
            }
            
            do {
                let startTime = Date()
                let distributionInfo = try await provider.fetchDividendInfo(symbol: "QQQI")
                let duration = Date().timeIntervalSince(startTime)
                
                print("  ✅ Success (\(String(format: "%.2f", duration))s)")
                print("  📈 Distribution Rate: \(distributionInfo.distributionRate?.formatted(.number.precision(.fractionLength(2))) ?? "N/A")")
                print("  📊 Distribution Yield: \(distributionInfo.distributionYieldPercent?.formatted(.number.precision(.fractionLength(2))) ?? "N/A")%")
                print("  🗓️  Frequency: \(distributionInfo.distributionFrequency ?? "N/A")")
                print("  📅 Last Ex-Date: \(distributionInfo.lastExDate?.formatted(.dateTime.month(.wide).day().year()) ?? "N/A")")
                print("  💰 Last Pay Date: \(distributionInfo.lastPaymentDate?.formatted(.dateTime.month(.wide).day().year()) ?? "N/A")")
                print("  🏢 Company Name: \(distributionInfo.fullName ?? "N/A")")
                
                let score = calculateQQQIAccuracyScore(distributionInfo)
                results.append((provider: provider.providerName, success: true, data: distributionInfo, error: nil, score: score))
                
            } catch {
                print("  ❌ Failed: \(error.localizedDescription)")
                results.append((provider: provider.providerName, success: false, data: nil, error: error.localizedDescription, score: 0.0))
            }
        }
        
        // Generate summary report
        print("\n" + String(repeating: "=", count: 60))
        print("📋 QQQI DIVIDEND PROVIDER ANALYSIS")
        print(String(repeating: "=", count: 60))
        
        let successfulProviders = results.filter { $0.success }
        print("✅ Successful providers: \(successfulProviders.count)/\(results.count)")
        
        if !successfulProviders.isEmpty {
            print("\n🏆 PROVIDER RANKING (by accuracy for QQQI):")
            
            let rankedProviders = successfulProviders.sorted { $0.score > $1.score }
            
            for (index, result) in rankedProviders.enumerated() {
                let medal = index == 0 ? "🥇" : index == 1 ? "🥈" : index == 2 ? "🥉" : "🏅"
                let scorePercentage = Int(result.score * 100)
                print("\(medal) \(index + 1). \(result.provider) (Score: \(scorePercentage)%)")
                
                if let data = result.data {
                    let rateAccuracy = evaluateQQQIDistributionRate(data.distributionRate)
                    let frequencyAccuracy = evaluateQQQIFrequency(data.distributionFrequency)
                    print("     Rate: \(rateAccuracy), Frequency: \(frequencyAccuracy)")
                }
            }
            
            // Recommendation
            if let bestProvider = rankedProviders.first {
                print("\n🎯 RECOMMENDATION:")
                print("   Use \(bestProvider.provider) as primary provider for dividend data")
                print("   This provider showed the highest accuracy for QQQI test case")
                
                // Generate new provider order
                let newOrder = generateOptimalProviderOrder(rankedProviders: rankedProviders, failedProviders: results.filter { !$0.success })
                print("\n📋 SUGGESTED PROVIDER ORDER:")
                for (index, provider) in newOrder.enumerated() {
                    print("   \(index + 1). \(provider)")
                }
            }
        }
        
        print("\n❌ Failed providers:")
        for result in results where !result.success {
            print("   • \(result.provider): \(result.error ?? "Unknown error")")
        }
        
        print("\n")
    }
    
    private func calculateQQQIAccuracyScore(_ data: DistributionInfo) -> Double {
        var score: Double = 0.0
        
        // Rate accuracy (50% of score) - QQQI expected rate: 14.42
        if let rate = data.distributionRate {
            let expectedRate = 14.42
            let rateDifference = abs(rate - expectedRate) / expectedRate
            let rateScore = max(0, 1 - rateDifference) // 1.0 = perfect, decreases with difference
            score += rateScore * 0.5
        }
        
        // Frequency accuracy (30% of score) - QQQI should be Monthly
        if let frequency = data.distributionFrequency?.lowercased() {
            if frequency.contains("monthly") || frequency.contains("month") {
                score += 0.3 // Perfect frequency match
            } else if frequency.contains("quarterly") || frequency.contains("quarter") {
                score += 0.1 // Some providers might default to quarterly
            }
        }
        
        // Data completeness (20% of score)
        var completenessScore: Double = 0.0
        if data.distributionRate != nil { completenessScore += 0.05 }
        if data.distributionYieldPercent != nil { completenessScore += 0.05 }
        if data.distributionFrequency != nil { completenessScore += 0.05 }
        if data.lastExDate != nil { completenessScore += 0.025 }
        if data.lastPaymentDate != nil { completenessScore += 0.025 }
        
        score += completenessScore
        
        return min(1.0, score) // Cap at 100%
    }
    
    private func evaluateQQQIDistributionRate(_ rate: Double?) -> String {
        guard let rate = rate else { return "❌ Missing" }
        
        let expectedRate = 14.42
        let difference = abs(rate - expectedRate)
        let percentageDifference = (difference / expectedRate) * 100
        
        if percentageDifference < 5 {
            return "✅ Excellent (\(rate.formatted(.number.precision(.fractionLength(2)))))"
        } else if percentageDifference < 15 {
            return "🟡 Good (\(rate.formatted(.number.precision(.fractionLength(2)))))"
        } else if percentageDifference < 30 {
            return "🟠 Fair (\(rate.formatted(.number.precision(.fractionLength(2)))))"
        } else {
            return "❌ Poor (\(rate.formatted(.number.precision(.fractionLength(2)))))"
        }
    }
    
    private func evaluateQQQIFrequency(_ frequency: String?) -> String {
        guard let frequency = frequency else { return "❌ Missing" }
        
        let lowerFreq = frequency.lowercased()
        if lowerFreq.contains("monthly") || lowerFreq.contains("month") {
            return "✅ Correct (Monthly)"
        } else if lowerFreq.contains("quarterly") || lowerFreq.contains("quarter") {
            return "🟡 Incorrect (Quarterly - should be Monthly)"
        } else {
            return "🟠 Other (\(frequency))"
        }
    }
    
    private func generateOptimalProviderOrder(rankedProviders: [(provider: String, success: Bool, data: DistributionInfo?, error: String?, score: Double)], failedProviders: [(provider: String, success: Bool, data: DistributionInfo?, error: String?, score: Double)]) -> [String] {
        var newOrder: [String] = []
        
        // Add successful providers in order of accuracy score
        newOrder.append(contentsOf: rankedProviders.map { $0.provider })
        
        // Add failed providers at the end (in their original relative order)
        let originalOrder = ["Yahoo Finance Dividends", "EODHD", "Nasdaq Dividends", "Alpha Vantage Dividends", "Finnhub"]
        for providerName in originalOrder {
            if failedProviders.contains(where: { $0.provider == providerName }) && !newOrder.contains(providerName) {
                newOrder.append(providerName)
            }
        }
        
        return newOrder
    }
    
    // MARK: - Main Demo Function
    
    func runFullDemo() async {
        print("🚀 Stock Service Modular Architecture Demo\n")
        print("This demo shows the new modular architecture with:")
        print("• 6 individual API service classes")
        print("• 2 manager classes for orchestration")
        print("• 1 unified interface for backward compatibility")
        print("• Full fallback logic and error handling\n")
        
        await demonstrateIndividualServices()
        await demonstrateManagers()
        await demonstrateUnifiedInterface()
        await demonstrateLegacyCompatibility()
        
        // Test dividend providers with QQQI
        await testDividendProvidersWithQQQI()
        
        print("✅ Demo completed! The modular architecture provides:")
        print("• Single responsibility principle")
        print("• Easy testing and maintenance")
        print("• Clear separation of concerns")
        print("• Backward compatibility")
        print("• Extensible design for new providers")
    }
}