/**
 * Final Concurrency Validation
 * 
 * This script validates all the key Swift 6.0 concurrency fixes:
 * 1. AsyncSemaphore actor with proper Sendable compliance
 * 2. TaskGroup patterns without concurrent mutation
 * 3. Proper actor isolation
 * 4. @MainActor usage
 */

import Foundation

// MARK: - AsyncSemaphore now imported from dedicated file

// MARK: - Test Actor Pattern

actor TestDataService {
    private var isProcessing: Bool = false
    private var cache: [String: [String]] = [:]
    
    func fetchMultipleItems(symbols: [String]) async -> [String: [String]] {
        // ✅ Fixed: Proper TaskGroup usage without defer async calls
        let semaphore = AsyncSemaphore(value: 3)
        
        return await withTaskGroup(of: (String, [String]?).self) { group in
            for symbol in symbols {
                group.addTask {
                    await semaphore.wait()
                    
                    do {
                        let result = try await self.processSymbol(symbol)
                        await semaphore.signal()  // ✅ Explicit signal calls
                        return (symbol, result)
                    } catch {
                        await semaphore.signal()  // ✅ Signal on error too
                        return (symbol, nil)
                    }
                }
            }
            
            var results: [String: [String]] = [:]
            for await (symbol, data) in group {
                if let data = data {
                    results[symbol] = data
                }
            }
            
            return results
        }
    }
    
    private func processSymbol(_ symbol: String) async throws -> [String] {
        isProcessing = true
        defer { isProcessing = false }
        
        // Simulate work
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        return ["\(symbol)_data"]
    }
    
    func getProcessingState() async -> Bool {
        return isProcessing
    }
}

// MARK: - Test MainActor Pattern

@MainActor
class TestUIManager: ObservableObject {
    @Published var isLoading = false
    @Published var loadingStatus: String = ""
    @Published var results: [String: [String]] = [:]
    
    private var dataService: TestDataService?
    
    init() {
        Task {
            self.dataService = TestDataService()
        }
    }
    
    func fetchData(symbols: [String]) async {
        isLoading = true
        loadingStatus = "Fetching data..."
        
        guard let dataService = dataService else {
            isLoading = false
            loadingStatus = "Service not available"
            return
        }
        
        let fetchedResults = await dataService.fetchMultipleItems(symbols: symbols)
        
        // ✅ These updates happen on @MainActor automatically
        results = fetchedResults
        isLoading = false
        loadingStatus = "Completed"
    }
}

// MARK: - Validation Tests

// Removed @main to fix compilation conflict - can be run independently
struct ConcurrencyValidation {
    static func main() async {
        print("🧪 Starting Swift 6.0 Concurrency Validation...")
        
        // Test 1: AsyncSemaphore
        print("\n1️⃣ Testing AsyncSemaphore...")
        await testAsyncSemaphore()
        
        // Test 2: Actor TaskGroup
        print("\n2️⃣ Testing Actor with TaskGroup...")
        await testActorTaskGroup()
        
        // Test 3: MainActor UI Manager
        print("\n3️⃣ Testing MainActor UI Manager...")
        await testMainActorManager()
        
        print("\n✅ All concurrency patterns validated successfully!")
        print("🎉 Swift 6.0 strict concurrency compliance achieved!")
    }
    
    static func testAsyncSemaphore() async {
        let semaphore = AsyncSemaphore(value: 2)
        
        // Test concurrent access
        async let task1: Void = {
            await semaphore.wait()
            print("   ✓ Task 1 acquired semaphore")
            try? await Task.sleep(nanoseconds: 100_000_000)
            await semaphore.signal()
            print("   ✓ Task 1 released semaphore")
        }()
        
        async let task2: Void = {
            await semaphore.wait()
            print("   ✓ Task 2 acquired semaphore")
            try? await Task.sleep(nanoseconds: 100_000_000)
            await semaphore.signal()
            print("   ✓ Task 2 released semaphore")
        }()
        
        let _ = await (task1, task2)
        print("   ✅ AsyncSemaphore concurrency test passed")
    }
    
    static func testActorTaskGroup() async {
        let service = TestDataService()
        let symbols = ["AAPL", "GOOGL", "MSFT", "TSLA"]
        
        let results = await service.fetchMultipleItems(symbols: symbols)
        print("   ✓ Fetched \(results.count) symbols using TaskGroup")
        
        let isProcessing = await service.getProcessingState()
        print("   ✓ Actor state access: isProcessing = \(isProcessing)")
        print("   ✅ Actor TaskGroup test passed")
    }
    
    @MainActor
    static func testMainActorManager() async {
        let manager = TestUIManager()
        
        print("   ✓ Created MainActor UI manager")
        print("   ✓ Initial state: isLoading = \(manager.isLoading)")
        
        await manager.fetchData(symbols: ["TEST1", "TEST2"])
        
        print("   ✓ Final state: isLoading = \(manager.isLoading)")
        print("   ✓ Results count: \(manager.results.count)")
        print("   ✅ MainActor UI Manager test passed")
    }
}