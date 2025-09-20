import Foundation
import CoreData
import Testing
@testable import my_asset

/// Test class to validate that threading fixes prevent the mach_msg2_trap kernel error
struct ThreadingFixValidationTest {
    
    init() {
        dataManager = DataManager.shared
        backgroundService = BackgroundUpdateService()
        portfolioManager = PortfolioManager()
    }
    
    /// Test that multiple concurrent background updates don't cause deadlocks
    @Test func concurrentBackgroundUpdates() async {        
        // Simulate multiple concurrent update requests
        await withTaskGroup(of: Void.self) { group in
            for i in 1...3 {
                group.addTask {
                    print("Starting concurrent update \(i)")
                    await self.backgroundService.updateAllStockPrices()
                    print("Completed concurrent update \(i)")
                }
            }
        }
    }
    
    /// Test that Core Data context operations don't block the main thread
    func testMainThreadNotBlocked() {
        let expectation = XCTestExpectation(description: "Main thread operations complete")
        
        // Create test portfolio on main thread
        let portfolio = portfolioManager.createPortfolio(name: "Test Portfolio")
        
        // Add holding which should not block main thread
        Task { @MainActor in
            let holding = portfolioManager.addHolding(
                to: portfolio,
                symbol: "AAPL",
                quantity: 10,
                pricePerShare: 150.0,
                datePurchased: Date()
            )
            
            XCTAssertNotNil(holding)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    /// Test that notification handling doesn't cause retain cycles
    func testNotificationHandlingMemorySafety() {
        let expectation = XCTestExpectation(description: "Notification handling completes")
        
        // Create a portfolio detail view simulation
        let portfolio = portfolioManager.createPortfolio(name: "Test Portfolio")
        
        // Simulate notification setup and teardown
        var changeNotificationCancellable = NotificationCenter.default
            .publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.global(qos: .utility))
            .compactMap { notification -> NSManagedObjectContext? in
                guard let context = notification.object as? NSManagedObjectContext else { return nil }
                return context
            }
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.global(qos: .utility))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Weak reference prevents retain cycle
                print("Notification received safely")
                expectation.fulfill()
            }
        
        // Trigger a save to test notification
        dataManager.save()
        
        // Clean up
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            changeNotificationCancellable?.cancel()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    /// Test that background context operations are properly isolated
    @Test func backgroundContextIsolation() async throws {
        // Test the new thread-safe helper
        let stocks = try await CoreDataThreadingHelper.safeRead(context: dataManager.context) { context in
            let request: NSFetchRequest<Stock> = Stock.fetchRequest()
            request.fetchLimit = 5
            return try context.fetch(request)
        }
        
        print("Successfully fetched \(stocks.count) stocks safely")
        
        // Test write operation
        try await CoreDataThreadingHelper.safeWrite(backgroundContext: dataManager.backgroundContext) { context in
            let testStock = Stock(context: context)
            testStock.stockID = UUID()
            testStock.symbol = "TEST"
            testStock.companyName = "Test Company"
            testStock.currentPrice = NSDecimalNumber(value: 100.0)
            testStock.lastUpdated = Date()
        }
        
        print("Successfully created test stock safely")
    }
    
    /// Test that object validation prevents crashes
    @Test func objectValidation() async {
        let portfolio = portfolioManager.createPortfolio(name: "Test Portfolio")
        let holding = portfolioManager.addHolding(
            to: portfolio,
            symbol: "MSFT",
            quantity: 5,
            pricePerShare: 200.0,
            datePurchased: Date()
        )
        
        // Test validation helper
        #expect(CoreDataThreadingHelper.isObjectValid(holding))
        #expect(CoreDataThreadingHelper.isObjectValid(portfolio))
        
        // Test after deletion
        portfolioManager.deleteHolding(holding)
        
        // Wait a bit for deletion to process
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Object should now be invalid
        #expect(!CoreDataThreadingHelper.isObjectValid(holding))
    }
    
    /// Stress test to ensure no kernel traps occur under heavy load
    func testStressTestNoKernelTrap() {
        let expectation = XCTestExpectation(description: "Stress test completes without crashes")
        expectation.expectedFulfillmentCount = 10
        
        // Create multiple portfolios with concurrent operations
        for i in 1...10 {
            Task {
                let portfolio = portfolioManager.createPortfolio(name: "Stress Test Portfolio \(i)")
                
                // Add multiple holdings concurrently
                let holding1 = portfolioManager.addHolding(
                    to: portfolio,
                    symbol: "STOCK\(i)A",
                    quantity: Int32(i),
                    pricePerShare: Decimal(100 + i),
                    datePurchased: Date()
                )
                
                let holding2 = portfolioManager.addHolding(
                    to: portfolio,
                    symbol: "STOCK\(i)B",
                    quantity: Int32(i * 2),
                    pricePerShare: Decimal(200 + i),
                    datePurchased: Date()
                )
                
                // Perform calculations
                let _ = portfolioManager.calculatePortfolioValue(portfolio)
                // Portfolio gain/loss functionality has been removed
                
                // Update and delete operations
                portfolioManager.updateHolding(holding1, quantity: Int32(i + 1), pricePerShare: Decimal(110 + i))
                portfolioManager.deleteHolding(holding2)
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
}

// MARK: - Test Extensions

extension ThreadingFixValidationTest {
    
    /// Helper method to simulate background app refresh
    func simulateBackgroundAppRefresh() async {
        await backgroundService.updateAllStockPrices()
    }
    
    /// Helper method to clean up test data
    func cleanupTestData() {
        let portfolios = portfolioManager.fetchPortfolios()
        for portfolio in portfolios where portfolio.name?.hasPrefix("Test") == true || portfolio.name?.hasPrefix("Stress Test") == true {
            portfolioManager.deletePortfolio(portfolio)
        }
    }
}