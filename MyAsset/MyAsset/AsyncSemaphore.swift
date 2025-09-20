import Foundation

/**
 * AsyncSemaphore Actor
 * 
 * A Swift 6.0 compliant semaphore implementation using actors for thread-safe
 * concurrency control. This semaphore allows limiting the number of concurrent
 * operations while maintaining proper async/await semantics.
 */
actor AsyncSemaphore: Sendable {
    private let maxCount: Int
    private var currentCount: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    /// Initialize the semaphore with a maximum count
    /// - Parameter value: The maximum number of concurrent operations allowed
    init(value: Int) {
        maxCount = value
        currentCount = value
    }
    
    /// Wait for semaphore availability
    /// This method will suspend if no permits are available
    func wait() async {
        if currentCount > 0 {
            currentCount -= 1
            return
        }
        
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
    
    /// Signal the semaphore to release a permit
    /// This will resume any waiting operations if available
    func signal() async {
        if !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.resume()
        } else {
            currentCount = min(currentCount + 1, maxCount)
        }
    }
    
    /// Get the current available count (for debugging)
    func getAvailableCount() -> Int {
        return currentCount
    }
    
    /// Get the number of waiting operations (for debugging)
    func getWaiterCount() -> Int {
        return waiters.count
    }
}