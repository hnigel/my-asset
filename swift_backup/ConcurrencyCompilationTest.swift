/**
 * Concurrency Compilation Test
 * 
 * This script tests key concurrency fixes to ensure Swift 6.0 compliance
 * by creating minimal instances and testing basic functionality.
 */

import Foundation

// Removed @main to fix compilation conflict - can be run independently
struct ConcurrencyCompilationTest {
    static func main() async {
        print("🔍 Testing Swift 6.0 concurrency compliance...")
        
        // Test 1: AsyncSemaphore functionality
        print("\n1. Testing AsyncSemaphore...")
        await testAsyncSemaphore()
        
        // Test 2: HistoricalDataService actor
        print("\n2. Testing HistoricalDataService actor...")
        await testHistoricalDataService()
        
        // Test 3: ComprehensiveHistoricalDataManager @MainActor
        print("\n3. Testing ComprehensiveHistoricalDataManager...")
        await testComprehensiveHistoricalDataManager()
        
        // Test 4: HistoricalStockDataManager actor
        print("\n4. Testing HistoricalStockDataManager actor...")
        await testHistoricalStockDataManager()
        
        print("\n✅ All concurrency tests completed successfully!")
    }
    
    @MainActor
    static func testAsyncSemaphore() async {
        let semaphore = AsyncSemaphore(value: 2)
        
        // Test wait and signal
        await semaphore.wait()
        print("   ✓ AsyncSemaphore wait() works")
        
        await semaphore.signal()
        print("   ✓ AsyncSemaphore signal() works")
    }
    
    static func testHistoricalDataService() async {
        let config = HistoricalDataServiceConfiguration.default
        let service = await HistoricalDataService(configuration: config)
        
        // Test basic async operations
        let isProcessing = await service.isCurrentlyProcessing()
        print("   ✓ HistoricalDataService actor isolation: \(isProcessing)")
        
        let lastError = await service.getLastError()
        print("   ✓ HistoricalDataService error handling: \(lastError == nil ? "No errors" : "Has error")")
    }
    
    @MainActor
    static func testComprehensiveHistoricalDataManager() async {
        let config = HistoricalDataServiceConfiguration.default
        let manager = ComprehensiveHistoricalDataManager(configuration: config)
        
        // Test @MainActor properties
        print("   ✓ ComprehensiveHistoricalDataManager @MainActor: isLoading = \(manager.isLoading)")
        print("   ✓ ComprehensiveHistoricalDataManager @MainActor: loadingStatus = '\(manager.loadingStatus)'")
    }
    
    static func testHistoricalStockDataManager() async {
        let config = HistoricalDataServiceConfiguration.default
        let manager = await HistoricalStockDataManager(configuration: config)
        
        // Test actor isolation
        let isLoading = await manager.getLoadingState()
        print("   ✓ HistoricalStockDataManager actor isolation: isLoading = \(isLoading)")
        
        // Test async methods
        let providerStatus = await manager.getProviderStatus()
        print("   ✓ HistoricalStockDataManager async methods: \(providerStatus.count) providers")
        
        let usageStats = await manager.getUsageStats()
        print("   ✓ HistoricalStockDataManager usage stats: \(usageStats.count) stats")
    }
}

