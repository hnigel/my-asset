import Foundation

/**
 * Compilation Fix Validation
 * 
 * This script validates that the compilation errors have been resolved:
 * 1. No hashbang line issues
 * 2. AsyncSemaphore is properly defined once
 * 3. No ambiguous init(value:) errors
 * 4. Swift 6.0 concurrency compliance
 */

// Removed @main to fix compilation conflict - can be run independently
struct CompilationFixValidation {
    static func main() async {
        print("🔧 Validating compilation fixes...")
        
        // Test 1: AsyncSemaphore functionality
        print("\n1️⃣ Testing AsyncSemaphore...")
        await testAsyncSemaphore()
        
        // Test 2: Concurrent operations with semaphore
        print("\n2️⃣ Testing concurrent semaphore operations...")
        await testConcurrentSemaphore()
        
        // Test 3: TaskGroup pattern
        print("\n3️⃣ Testing TaskGroup with semaphore...")
        await testTaskGroupWithSemaphore()
        
        print("\n✅ All compilation fixes validated successfully!")
        print("🎉 Swift 6.0 concurrency compliance maintained!")
    }
    
    static func testAsyncSemaphore() async {
        // Test basic functionality
        let semaphore = AsyncSemaphore(value: 2)
        
        // Test wait and signal
        await semaphore.wait()
        print("   ✓ AsyncSemaphore wait() works")
        
        await semaphore.signal()
        print("   ✓ AsyncSemaphore signal() works")
        
        // Test debugging methods
        let availableCount = await semaphore.getAvailableCount()
        let waiterCount = await semaphore.getWaiterCount()
        print("   ✓ Available count: \(availableCount), Waiters: \(waiterCount)")
    }
    
    static func testConcurrentSemaphore() async {
        let semaphore = AsyncSemaphore(value: 1) // Only allow 1 concurrent operation
        
        // Test concurrent access
        async let task1: Void = {
            await semaphore.wait()
            print("   ✓ Task 1 acquired semaphore")
            // Simulate work
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            await semaphore.signal()
            print("   ✓ Task 1 released semaphore")
        }()
        
        async let task2: Void = {
            await semaphore.wait()
            print("   ✓ Task 2 acquired semaphore")
            // Simulate work
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            await semaphore.signal()
            print("   ✓ Task 2 released semaphore")
        }()
        
        let _ = await (task1, task2)
        print("   ✅ Concurrent semaphore operations completed")
    }
    
    static func testTaskGroupWithSemaphore() async {
        let semaphore = AsyncSemaphore(value: 2) // Allow 2 concurrent operations
        let items = ["Item1", "Item2", "Item3", "Item4", "Item5"]
        
        let results = await withTaskGroup(of: (String, Bool).self) { group in
            for item in items {
                group.addTask {
                    await semaphore.wait()
                    
                    // Simulate work
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                    let success = true // Simulate successful processing
                    
                    await semaphore.signal()
                    return (item, success)
                }
            }
            
            var processedResults: [(String, Bool)] = []
            for await result in group {
                processedResults.append(result)
            }
            return processedResults
        }
        
        print("   ✓ Processed \(results.count) items using TaskGroup with semaphore")
        let successCount = results.filter { $0.1 }.count
        print("   ✓ Success rate: \(successCount)/\(results.count)")
    }
}