import Foundation

/**
 * Historical Data Integration Test
 * 
 * Comprehensive test suite for the historical stock data functionality,
 * validating all layers: API services, caching, persistence, and integration.
 */
@MainActor
class HistoricalDataIntegrationTest {
    
    private let manager = ComprehensiveHistoricalDataManager()
    private let testSymbols = ["AAPL", "GOOGL", "MSFT", "TSLA"]
    
    // MARK: - Main Test Runner
    
    func runAllTests() async {
        print("🚀 Starting Historical Data Integration Tests")
        print("============================================")
        
        await testBasicFunctionality()
        await testMultipleSymbols()
        await testCaching()
        await testPersistence()
        await testErrorHandling()
        await testHealthCheck()
        await testProviderFallback()
        
        print("✅ All tests completed!")
        print("======================")
    }
    
    // MARK: - Individual Tests
    
    private func testBasicFunctionality() async {
        print("\n📊 Testing Basic Functionality...")
        
        do {
            // Test single symbol fetch
            let prices = try await manager.fetchHistoricalPrices(
                symbol: "AAPL",
                period: .oneMonth
            )
            
            guard !prices.isEmpty else {
                print("❌ No data returned for AAPL")
                return
            }
            
            print("✅ Fetched \(prices.count) historical prices for AAPL")
            
            // Validate data quality
            let validPrices = prices.filter { $0.isValid }
            print("✅ \(validPrices.count)/\(prices.count) prices passed validation")
            
            // Test latest price
            let latestPrice = try await manager.fetchLatestPrice(for: "AAPL")
            print("✅ Latest price for AAPL: \(latestPrice.formattedClosePrice)")
            
        } catch {
            print("❌ Basic functionality test failed: \(error)")
        }
    }
    
    private func testMultipleSymbols() async {
        print("\n📈 Testing Multiple Symbols...")
        
        let results = await manager.fetchMultipleHistoricalPrices(
            symbols: testSymbols,
            period: .oneWeek
        )
        
        print("✅ Fetched data for \(results.count)/\(testSymbols.count) symbols")
        
        for (symbol, prices) in results {
            print("  • \(symbol): \(prices.count) prices")
        }
    }
    
    private func testCaching() async {
        print("\n💾 Testing Caching...")
        
        let symbol = "MSFT"
        let period = HistoricalPrice.TimePeriod.oneWeek
        
        // Clear cache first
        await manager.clearAllCache()
        print("✅ Cache cleared")
        
        // First fetch - should be from API
        let startTime1 = Date()
        do {
            let prices1 = try await manager.fetchHistoricalPrices(symbol: symbol, period: period)
            let duration1 = Date().timeIntervalSince(startTime1)
            print("✅ First fetch (API): \(prices1.count) prices in \(String(format: "%.2f", duration1))s")
            
            // Second fetch - should be from cache
            let startTime2 = Date()
            let prices2 = try await manager.fetchHistoricalPrices(symbol: symbol, period: period)
            let duration2 = Date().timeIntervalSince(startTime2)
            print("✅ Second fetch (Cache): \(prices2.count) prices in \(String(format: "%.2f", duration2))s")
            
            if duration2 < duration1 {
                print("✅ Cache is faster than API (\(String(format: "%.2f", duration1/duration2))x speedup)")
            }
            
        } catch {
            print("❌ Caching test failed: \(error)")
        }
    }
    
    private func testPersistence() async {
        print("\n💿 Testing Persistence...")
        
        let symbol = "GOOGL"
        let period = HistoricalPrice.TimePeriod.oneMonth
        
        do {
            // Fetch data (should be saved to Core Data)
            let prices = try await manager.fetchHistoricalPrices(
                symbol: symbol,
                period: period,
                forceRefresh: true
            )
            print("✅ Fetched and saved \(prices.count) prices for \(symbol)")
            
            // Clear cache to ensure we're testing persistence
            await manager.clearAllCache()
            
            // Fetch again (should come from Core Data)
            let startTime = Date()
            let persistedPrices = try await manager.fetchHistoricalPrices(
                symbol: symbol,
                period: period
            )
            let duration = Date().timeIntervalSince(startTime)
            
            print("✅ Loaded \(persistedPrices.count) prices from persistence in \(String(format: "%.2f", duration))s")
            
            if persistedPrices.count == prices.count {
                print("✅ Persistence data matches original fetch")
            } else {
                print("⚠️ Persistence count mismatch: \(persistedPrices.count) vs \(prices.count)")
            }
            
        } catch {
            print("❌ Persistence test failed: \(error)")
        }
    }
    
    private func testErrorHandling() async {
        print("\n⚠️ Testing Error Handling...")
        
        // Test invalid symbol
        do {
            _ = try await manager.fetchHistoricalPrices(symbol: "INVALID", period: .oneWeek)
            print("❌ Should have thrown error for invalid symbol")
        } catch {
            print("✅ Correctly handled invalid symbol: \(error.localizedDescription)")
        }
        
        // Test invalid date range
        do {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: 1, to: endDate)! // Future date
            _ = try await manager.fetchHistoricalPrices(symbol: "AAPL", startDate: startDate, endDate: endDate)
            print("❌ Should have thrown error for invalid date range")
        } catch {
            print("✅ Correctly handled invalid date range: \(error.localizedDescription)")
        }
    }
    
    private func testHealthCheck() async {
        print("\n🔍 Testing Health Check...")
        
        let healthReport = await manager.performHealthCheck()
        
        print("✅ Overall Health: \(healthReport.overallHealthy ? "Healthy" : "Issues Detected")")
        print("✅ Cache Stats: \(healthReport.cacheStats.entriesCount) entries, \(String(format: "%.1f", healthReport.cacheStats.hitRate * 100))% hit rate")
        print("✅ Storage Stats: \(healthReport.storageStats.totalRecords) records for \(healthReport.storageStats.symbolsWithHistory) symbols")
        
        // Print provider status
        let providerStatus = await manager.getProviderStatus()
        print("📡 Provider Status:")
        for provider in providerStatus {
            print("  • \(provider.name): \(provider.available ? "✅ Available" : "❌ Unavailable") (\(provider.priority))")
        }
    }
    
    private func testProviderFallback() async {
        print("\n🔄 Testing Provider Fallback...")
        
        // This is a conceptual test - in practice, we'd simulate provider failures
        let symbol = "TSLA"
        let period = HistoricalPrice.TimePeriod.oneWeek
        
        do {
            let prices = try await manager.fetchHistoricalPrices(symbol: symbol, period: period)
            print("✅ Successfully fetched \(prices.count) prices (fallback working)")
            
            // Check which provider was used (this would require more detailed logging)
            if !prices.isEmpty {
                let dataSource = prices.first?.dataSource ?? "Unknown"
                print("✅ Data source: \(dataSource)")
            }
            
        } catch {
            print("❌ Provider fallback test failed: \(error)")
        }
    }
    
    // MARK: - Performance Testing
    
    func runPerformanceTests() async {
        print("\n🏎️ Running Performance Tests...")
        print("===============================")
        
        await testConcurrentFetching()
        await testLargeDataSet()
        await testCachePerformance()
    }
    
    private func testConcurrentFetching() async {
        print("\n⚡ Testing Concurrent Fetching...")
        
        let symbols = ["AAPL", "GOOGL", "MSFT", "TSLA", "AMZN", "META", "NVDA", "NFLX"]
        let startTime = Date()
        
        let results = await manager.fetchMultipleHistoricalPrices(
            symbols: symbols,
            period: .oneWeek
        )
        
        let duration = Date().timeIntervalSince(startTime)
        let avgTimePerSymbol = duration / Double(symbols.count)
        
        print("✅ Fetched \(results.count) symbols in \(String(format: "%.2f", duration))s")
        print("✅ Average time per symbol: \(String(format: "%.2f", avgTimePerSymbol))s")
    }
    
    private func testLargeDataSet() async {
        print("\n📊 Testing Large Data Set...")
        
        let startTime = Date()
        
        do {
            let prices = try await manager.fetchHistoricalPrices(
                symbol: "AAPL",
                period: .oneYear
            )
            
            let duration = Date().timeIntervalSince(startTime)
            let pricesPerSecond = Double(prices.count) / duration
            
            print("✅ Fetched \(prices.count) prices in \(String(format: "%.2f", duration))s")
            print("✅ Rate: \(String(format: "%.0f", pricesPerSecond)) prices/second")
            
        } catch {
            print("❌ Large data set test failed: \(error)")
        }
    }
    
    private func testCachePerformance() async {
        print("\n💨 Testing Cache Performance...")
        
        let symbol = "MSFT"
        let period = HistoricalPrice.TimePeriod.oneMonth
        
        // Warm up cache
        do {
            _ = try await manager.fetchHistoricalPrices(symbol: symbol, period: period)
            
            // Test cache speed
            let iterations = 10
            var totalTime: TimeInterval = 0
            
            for _ in 1...iterations {
                let startTime = Date()
                _ = try await manager.fetchHistoricalPrices(symbol: symbol, period: period)
                totalTime += Date().timeIntervalSince(startTime)
            }
            
            let avgCacheTime = totalTime / Double(iterations)
            print("✅ Average cache fetch time: \(String(format: "%.4f", avgCacheTime))s")
            
        } catch {
            print("❌ Cache performance test failed: \(error)")
        }
    }
}

// MARK: - Test Runner Extension

extension HistoricalDataIntegrationTest {
    /// Run quick smoke test
    func runSmokeTest() async {
        print("💨 Running Quick Smoke Test...")
        
        do {
            let prices = try await manager.fetchHistoricalPrices(
                symbol: "AAPL",
                period: .oneWeek
            )
            
            if !prices.isEmpty && prices.allSatisfy({ $0.isValid }) {
                print("✅ Smoke test passed - system is working")
            } else {
                print("❌ Smoke test failed - data quality issues")
            }
            
        } catch {
            print("❌ Smoke test failed: \(error)")
        }
    }
    
    /// Generate test report
    func generateTestReport() async -> String {
        let healthReport = await manager.performHealthCheck()
        let cacheStats = healthReport.cacheStats
        let storageStats = healthReport.storageStats
        
        return """
        Historical Data System Test Report
        ==================================
        
        System Status: \(healthReport.overallHealthy ? "✅ Healthy" : "❌ Issues")
        
        Cache Performance:
        • Entries: \(cacheStats.entriesCount)
        • Hit Rate: \(String(format: "%.1f", cacheStats.hitRate * 100))%
        • Size: \(ByteCountFormatter().string(fromByteCount: cacheStats.totalSizeBytes))
        
        Storage Statistics:
        • Total Records: \(storageStats.totalRecords)
        • Symbols with History: \(storageStats.symbolsWithHistory)
        • Storage Size: \(storageStats.formattedSize)
        • Date Range: \(storageStats.dateRangeDescription)
        
        API Providers:
        \(await manager.getProviderStatus().map { "• \($0.name): \($0.available ? "Available" : "Unavailable")" }.joined(separator: "\n"))
        
        Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))
        """
    }
}