import Foundation

/**
 * Concurrency Test Validation
 * 
 * 驗證 Swift 6.0 併發架構重構後的編譯和運行時安全性
 */

@MainActor
class ConcurrencyTestValidation {
    
    // MARK: - Test UI Layer
    
    func testComprehensiveHistoricalDataManager() async {
        print("Testing ComprehensiveHistoricalDataManager...")
        
        let manager = ComprehensiveHistoricalDataManager()
        
        // Test basic state access
        let isLoading = manager.isLoading
        let lastError = manager.lastError
        
        print("Initial state - Loading: \(isLoading), Error: \(String(describing: lastError))")
        
        // Test async operations
        do {
            let prices = try await manager.fetchHistoricalPrices(
                symbol: "AAPL",
                period: .oneWeek
            )
            print("Successfully fetched \(prices.count) prices")
        } catch {
            print("Error fetching prices: \(error)")
        }
        
        // Test health check
        let healthReport = await manager.performHealthCheck()
        print("Health check: \(healthReport.overallHealthy)")
    }
    
    // MARK: - Test Actor Communication
    
    func testActorCommunication() async {
        print("Testing actor communication...")
        
        let service = await HistoricalDataService()
        
        // Test concurrent operations
        async let pricesTask = service.fetchHistoricalPrices(
            symbol: "GOOGL",
            period: .oneMonth
        )
        
        async let healthTask = service.performHealthCheck()
        async let statsTask = service.getCacheStats()
        
        do {
            let (prices, health, stats) = try await (pricesTask, healthTask, statsTask)
            print("Concurrent results:")
            print("- Prices: \(prices.count)")
            print("- Health: \(health.overallHealthy)")
            print("- Cache entries: \(stats?.entriesCount ?? 0)")
        } catch {
            print("Concurrent operation error: \(error)")
        }
    }
    
    // MARK: - Test Multiple Symbol Fetching
    
    func testMultipleSymbolFetching() async {
        print("Testing multiple symbol fetching...")
        
        let service = await HistoricalDataService()
        
        let symbols = ["AAPL", "GOOGL", "MSFT", "TSLA", "AMZN"]
        
        let results = await service.fetchMultipleHistoricalPrices(
            symbols: symbols,
            period: .oneWeek
        )
        
        print("Multiple symbol results:")
        for (symbol, prices) in results {
            print("- \(symbol): \(prices.count) prices")
        }
    }
    
    // MARK: - Test TaskGroup Safety
    
    func testTaskGroupSafety() async {
        print("Testing TaskGroup safety...")
        
        let symbols = ["AAPL", "GOOGL", "MSFT"]
        
        let results = await withTaskGroup(of: (String, Int).self) { group in
            for symbol in symbols {
                group.addTask {
                    let service = await HistoricalDataService()
                    do {
                        let prices = try await service.fetchHistoricalPrices(
                            symbol: symbol,
                            period: .oneWeek
                        )
                        return (symbol, prices.count)
                    } catch {
                        return (symbol, 0)
                    }
                }
            }
            
            var results: [String: Int] = [:]
            for await (symbol, count) in group {
                results[symbol] = count
            }
            
            return results
        }
        
        print("TaskGroup results:")
        for (symbol, count) in results {
            print("- \(symbol): \(count)")
        }
    }
    
    // MARK: - Test Sendable Compliance
    
    func testSendableCompliance() async {
        print("Testing Sendable compliance...")
        
        // Test that all data structures can be safely passed across actor boundaries
        let configuration = HistoricalDataServiceConfiguration.default
        let service = await HistoricalDataService(configuration: configuration)
        
        // This should compile without warnings
        let healthReport = await service.performHealthCheck()
        let cacheStats = await service.getCacheStats()
        let storageStats = await service.getStorageStats()
        
        print("Sendable compliance test completed:")
        print("- Configuration: \(configuration.enableLogging)")
        print("- Health: \(healthReport.overallHealthy)")
        print("- Cache: \(cacheStats?.entriesCount ?? 0)")
        print("- Storage: \(storageStats?.totalRecords ?? 0)")
    }
    
    // MARK: - Run All Tests
    
    func runAllTests() async {
        print("=== Starting Concurrency Validation Tests ===")
        
        await testComprehensiveHistoricalDataManager()
        await testActorCommunication()
        await testMultipleSymbolFetching()
        await testTaskGroupSafety()
        await testSendableCompliance()
        
        print("=== All Concurrency Tests Completed ===")
    }
}

// MARK: - Test Runner

@MainActor
func runConcurrencyValidation() async {
    let validator = ConcurrencyTestValidation()
    await validator.runAllTests()
}