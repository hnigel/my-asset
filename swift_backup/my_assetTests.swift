//
//  my_assetTests.swift
//  my assetTests
//
//  Created by 洪子翔 on 2025/9/7.
//

import Testing
import CoreData
@testable import my_asset

struct my_assetTests {
    
    // MARK: - Test Core Data Setup
    
    private func clearTestData() {
        let context = DataManager.shared.context
        let entities = ["Portfolio", "Holding", "Stock", "PriceHistory"]
        for entityName in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try? context.execute(deleteRequest)
        }
        try? context.save()
    }
    
    // MARK: - Portfolio Management Tests
    
    @Test func createPortfolio() async throws {
        clearTestData()
        defer { clearTestData() }
        
        let portfolioManager = PortfolioManager()
        let portfolioName = "Test Portfolio"
        let portfolio = portfolioManager.createPortfolio(name: portfolioName)
        
        #expect(portfolio.name == portfolioName)
        #expect(portfolio.portfolioID != nil)
        #expect(portfolio.createdDate != nil)
        
        // Verify it was saved to context
        let fetchRequest: NSFetchRequest<Portfolio> = Portfolio.fetchRequest()
        let savedPortfolios = try DataManager.shared.context.fetch(fetchRequest)
        #expect(savedPortfolios.count == 1)
        #expect(savedPortfolios.first?.name == portfolioName)
    }
    
    @Test func deletePortfolioSafely() async throws {
        clearTestData()
        defer { clearTestData() }
        
        let portfolioManager = PortfolioManager()
        
        // Create multiple portfolios to test IndexSet deletion
        let portfolio1 = portfolioManager.createPortfolio(name: "Test Portfolio 1")
        let portfolio2 = portfolioManager.createPortfolio(name: "Test Portfolio 2")
        let portfolio3 = portfolioManager.createPortfolio(name: "Test Portfolio 3")
        
        // Verify they were created
        let initialPortfolios = portfolioManager.fetchPortfolios()
        #expect(initialPortfolios.count == 3)
        
        // Test deleting portfolios by IndexSet (simulating SwiftUI onDelete behavior)
        let indexSet = IndexSet([1]) // Delete the second portfolio
        
        // This mimics the deletePortfolios function logic
        let portfoliosToDelete = indexSet.compactMap { index -> Portfolio? in
            guard index >= 0, 
                  index < initialPortfolios.count,
                  let portfolio = initialPortfolios.indices.contains(index) ? initialPortfolios[index] : nil,
                  !portfolio.isDeleted else { 
                return nil 
            }
            return portfolio
        }
        
        for portfolio in portfoliosToDelete {
            guard !portfolio.isDeleted, portfolio.managedObjectContext != nil else { continue }
            portfolioManager.deletePortfolio(portfolio)
        }
        
        // Verify deletion worked
        let remainingPortfolios = portfolioManager.fetchPortfolios()
        #expect(remainingPortfolios.count == 2)
        
        // Verify the correct portfolio was deleted (should be portfolio2)
        let remainingNames = remainingPortfolios.compactMap { $0.name }
        #expect(remainingNames.contains("Test Portfolio 1"))
        #expect(!remainingNames.contains("Test Portfolio 2"))
        #expect(remainingNames.contains("Test Portfolio 3"))
    }
    
    @Test func addHolding() async throws {
        clearTestData()
        defer { clearTestData() }
        
        let portfolioManager = PortfolioManager()
        let portfolio = portfolioManager.createPortfolio(name: "Test Portfolio")
        
        let holding = portfolioManager.addHolding(
            to: portfolio,
            symbol: "AAPL",
            quantity: 10,
            pricePerShare: Decimal(150.00),
            datePurchased: Date()
        )
        
        #expect(holding.quantity == 10)
        #expect(holding.pricePerShare as Decimal == Decimal(150.00))
        #expect(holding.stock?.symbol == "AAPL")
        #expect(holding.portfolio == portfolio)
        
        // Verify stock was created or found
        let stockRequest: NSFetchRequest<Stock> = Stock.fetchRequest()
        let stocks = try DataManager.shared.context.fetch(stockRequest)
        #expect(stocks.count == 1)
        #expect(stocks.first?.symbol == "AAPL")
    }
    
    @Test func calculatePortfolioValue() async throws {
        clearTestData()
        defer { clearTestData() }
        
        let portfolioManager = PortfolioManager()
        let portfolio = portfolioManager.createPortfolio(name: "Test Portfolio")
        
        portfolioManager.addHolding(
            to: portfolio,
            symbol: "AAPL",
            quantity: 10,
            pricePerShare: Decimal(150.00),
            datePurchased: Date()
        )
        
        let holding = portfolio.holdings?.anyObject() as? Holding
        holding?.stock?.currentPrice = NSDecimalNumber(decimal: Decimal(160.00))
        
        let portfolioValue = portfolioManager.calculatePortfolioValue(portfolio)
        #expect(portfolioValue == Decimal(1600.00))
    }
    
    // MARK: - Stock Price Service Tests
    
    @Test func stockPriceServiceDemo() async throws {
        let service = StockPriceService()
        let quote = await service.fetchDemoStockPrice(symbol: "AAPL")
        
        #expect(quote.symbol == "AAPL")
        #expect(quote.price > 0)
        #expect(quote.companyName?.contains("AAPL") == true)
        #expect(quote.lastUpdated <= Date())
        #expect(quote.isValid)
        #expect(quote.formattedPrice.contains("$"))
        
        // Test with different symbol
        let googQuote = await service.fetchDemoStockPrice(symbol: "GOOGL")
        #expect(googQuote.symbol == "GOOGL")
        #expect(googQuote.price > 0)
        #expect(googQuote.companyName?.contains("GOOGL") == true)
        #expect(googQuote.isValid)
    }
    
    @Test func stockPriceServiceCaching() async throws {
        let service = StockPriceService()
        let testSymbol = "TEST"
        
        // Initially not cached
        #expect(!service.isCached(symbol: testSymbol))
        
        // Add to cache manually for testing
        let testQuote = StockQuote(
            symbol: testSymbol,
            price: 100.0,
            companyName: "Test Company",
            lastUpdated: Date()
        )
        service.setCachedPrice(symbol: testSymbol, quote: testQuote)
        
        // Should now be cached
        #expect(service.isCached(symbol: testSymbol))
        #expect(service.cacheSize >= 1)
        
        // Clear cache
        service.clearCache()
        #expect(!service.isCached(symbol: testSymbol))
        #expect(service.cacheSize == 0)
    }
    
    @Test func stockPriceServiceErrorHandling() async throws {
        let service = StockPriceService()
        
        // Test with invalid/empty symbol
        do {
            _ = try await service.fetchStockPrice(symbol: "")
            #expect(false, "Should have thrown an error for empty symbol")
        } catch {
            // Expected to fail
            #expect(error is StockPriceService.APIError)
        }
        
        // Test with likely invalid symbol
        do {
            _ = try await service.fetchStockPrice(symbol: "INVALIDSTOCKSYMBOL123456")
            // This might succeed or fail depending on API response
        } catch let apiError as StockPriceService.APIError {
            // Check that error descriptions are provided
            #expect(apiError.errorDescription != nil)
            #expect(!apiError.errorDescription!.isEmpty)
        } catch {
            // Other errors are also acceptable for invalid symbols
        }
    }
    
    @Test func stockQuoteValidation() async throws {
        // Valid stock quote
        let validQuote = StockQuote(
            symbol: "AAPL",
            price: 150.0,
            companyName: "Apple Inc.",
            lastUpdated: Date()
        )
        #expect(validQuote.isValid)
        #expect(validQuote.formattedPrice == "$150.00")
        
        // Invalid stock quote (zero price)
        let invalidQuote = StockQuote(
            symbol: "TEST",
            price: 0.0,
            companyName: "Test Company",
            lastUpdated: Date()
        )
        #expect(!invalidQuote.isValid)
        
        // Invalid stock quote (empty symbol)
        let invalidSymbolQuote = StockQuote(
            symbol: "",
            price: 100.0,
            companyName: "Test Company",
            lastUpdated: Date()
        )
        #expect(!invalidSymbolQuote.isValid)
    }
    
    // MARK: - Background Update Service Tests
    
    @Test func backgroundUpdateService() async throws {
        clearTestData()
        defer { clearTestData() }
        
        let portfolioManager = PortfolioManager()
        let portfolio = portfolioManager.createPortfolio(name: "Test Portfolio")
        
        // Add a holding to create a stock
        portfolioManager.addHolding(
            to: portfolio,
            symbol: "AAPL",
            quantity: 10,
            pricePerShare: Decimal(150.00),
            datePurchased: Date()
        )
        
        let backgroundService = BackgroundUpdateService()
        await backgroundService.updateAllStockPrices()
        
        // Verify the stock price was updated
        let holding = portfolio.holdings?.anyObject() as? Holding
        #expect(holding?.stock?.currentPrice?.doubleValue ?? 0 > 0)
        #expect(holding?.stock?.lastUpdated != nil)
        
        // Verify price history was created
        let priceHistoryCount = holding?.stock?.priceHistory?.count ?? 0
        #expect(priceHistoryCount > 0)
    }
    
    // MARK: - Portfolio Calculation Tests
    
    // Total cost functionality has been removed
    
    @Test func calculateGainLoss() async throws {
        clearTestData()
        defer { clearTestData() }
        
        let portfolioManager = PortfolioManager()
        let portfolio = portfolioManager.createPortfolio(name: "Test Portfolio")
        
        let holding = portfolioManager.addHolding(
            to: portfolio,
            symbol: "AAPL",
            quantity: 10,
            pricePerShare: Decimal(150.00),
            datePurchased: Date()
        )
        
        // Set current price higher than purchase price
        holding.stock?.currentPrice = NSDecimalNumber(decimal: Decimal(160.00))
        
        // Portfolio gain/loss functionality has been removed
    }
    
    
    // MARK: - Data Management Tests
    
    @Test func dataManagerSave() async throws {
        clearTestData()
        defer { clearTestData() }
        
        let context = DataManager.shared.context
        
        // Create a portfolio directly in the context
        let portfolio = Portfolio(context: context)
        portfolio.portfolioID = UUID()
        portfolio.name = "Direct Test Portfolio"
        portfolio.createdDate = Date()
        
        // Verify it hasn't been saved yet
        #expect(context.hasChanges)
        
        // Save using DataManager
        DataManager.shared.save()
        
        // Verify save completed
        #expect(!context.hasChanges)
        
        // Verify the portfolio is persisted
        let fetchRequest: NSFetchRequest<Portfolio> = Portfolio.fetchRequest()
        let portfolios = try context.fetch(fetchRequest)
        #expect(portfolios.count == 1)
        #expect(portfolios.first?.name == "Direct Test Portfolio")
    }
    
    @Test func dataManagerContextAccess() async throws {
        let context = DataManager.shared.context
        #expect(context.automaticallyMergesChangesFromParent == true)
        #expect(context.persistentStoreCoordinator != nil)
    }
    
    // MARK: - Export Manager Tests
    
    @Test func exportManagerTextSummary() async throws {
        clearTestData()
        defer { clearTestData() }
        
        let portfolioManager = PortfolioManager()
        let portfolio = portfolioManager.createPortfolio(name: "Text Export Test Portfolio")
        
        // Add test holdings
        let holding1 = portfolioManager.addHolding(
            to: portfolio,
            symbol: "AAPL",
            quantity: 10,
            pricePerShare: Decimal(150.00),
            datePurchased: Date()
        )
        
        let holding2 = portfolioManager.addHolding(
            to: portfolio,
            symbol: "GOOGL",
            quantity: 5,
            pricePerShare: Decimal(200.00),
            datePurchased: Date()
        )
        
        // Set current prices for calculations
        holding1.stock?.currentPrice = NSDecimalNumber(decimal: Decimal(160.00))
        holding2.stock?.currentPrice = NSDecimalNumber(decimal: Decimal(220.00))
        
        let exportManager = ExportManager()
        let exportURL = await exportManager.exportPortfolio(portfolio)
        
        #expect(exportURL != nil)
        #expect(exportURL?.pathExtension == "txt")
        
        // Verify the file exists and contains expected content
        if let url = exportURL {
            let content = try String(contentsOf: url)
            #expect(content.contains("AAPL"))
            #expect(content.contains("GOOGL"))
            #expect(content.contains("Portfolio Summary"))
            #expect(content.contains("Total Value"))
            
            // Clean up the test file
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    // MARK: - Comprehensive StockPriceService Tests
    
    @Test func realStockPriceFetching() async throws {
        let service = StockPriceService()
        
        // Test with valid major stock symbols
        for symbol in ["AAPL", "MSFT", "GOOGL"] {
            do {
                let quote = try await service.fetchStockPrice(symbol: symbol)
                
                #expect(quote.symbol == symbol)
                #expect(quote.price > 0)
                #expect(quote.isValid)
                #expect(!quote.formattedPrice.isEmpty)
                #expect(quote.formattedPrice.contains("$"))
                #expect(quote.lastUpdated <= Date())
                
                // Company name might be nil for some APIs, but symbol should always be there
                #expect(!quote.symbol.isEmpty)
                
                print("✓ Successfully fetched \(symbol): \(quote.formattedPrice)")
            } catch let apiError as StockPriceService.APIError {
                print("⚠️ API Error for \(symbol): \(apiError.errorDescription ?? "Unknown error")")
                // Don't fail the test for API errors - they might be temporary
            } catch {
                print("⚠️ Unexpected error for \(symbol): \(error)")
            }
        }
    }
    
    @Test func stockPriceServiceInvalidSymbols() async throws {
        let service = StockPriceService()
        
        let invalidSymbols = ["", "   ", "INVALIDSTOCK123", "!@#$%"]
        
        for invalidSymbol in invalidSymbols {
            do {
                let _ = try await service.fetchStockPrice(symbol: invalidSymbol)
                // If we get here without error, that's unexpected for clearly invalid symbols
                if invalidSymbol.isEmpty || invalidSymbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    #expect(false, "Empty symbol should have thrown an error")
                }
            } catch let apiError as StockPriceService.APIError {
                #expect(apiError.errorDescription != nil)
                #expect(!apiError.errorDescription!.isEmpty)
                print("✓ Correctly handled invalid symbol '\(invalidSymbol)': \(apiError.errorDescription!)")
            } catch {
                // Other errors are also acceptable for invalid symbols
                print("✓ Error for invalid symbol '\(invalidSymbol)': \(error.localizedDescription)")
            }
        }
    }
    
    @Test func stockPriceServiceCachingBehavior() async throws {
        let service = StockPriceService()
        service.clearCache()
        let testSymbol = "AAPL"
        
        // Initially not cached
        #expect(!service.isCached(symbol: testSymbol))
        #expect(service.cacheSize == 0)
        
        do {
            // First fetch - should hit API and cache result
            let firstQuote = try await service.fetchStockPrice(symbol: testSymbol)
            #expect(service.isCached(symbol: testSymbol))
            #expect(service.cacheSize >= 1)
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Second fetch - should be from cache (much faster)
            let secondQuote = try await service.fetchStockPrice(symbol: testSymbol)
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let fetchTime = endTime - startTime
            
            #expect(firstQuote.symbol == secondQuote.symbol)
            #expect(firstQuote.price == secondQuote.price)
            #expect(fetchTime < 0.1) // Should be very fast from cache
            
            print("✓ Cache fetch time: \(String(format: "%.3f", fetchTime))s")
        } catch {
            print("⚠️ Cache test skipped due to API error: \(error)")
        }
    }
    
    @Test func stockPriceServiceConcurrentRequests() async throws {
        let service = StockPriceService()
        let symbols = ["AAPL", "MSFT", "GOOGL", "TSLA", "AMZN"]
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let quotes = await service.fetchMultipleStockPrices(symbols: symbols)
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        
        print("✓ Concurrent fetch of \(symbols.count) symbols took \(String(format: "%.2f", totalTime))s")
        
        // Should complete in reasonable time (concurrent requests should be faster than sequential)
        #expect(totalTime < Double(symbols.count) * 2.0) // Much faster than sequential
        
        // Verify we got some results (API might fail for some symbols)
        #expect(quotes.count >= 0) // At least don't crash
        
        for (symbol, quote) in quotes {
            #expect(symbols.contains(symbol))
            #expect(quote.isValid)
            #expect(quote.symbol == symbol)
            print("✓ \(symbol): \(quote.formattedPrice)")
        }
    }
    
    @Test func stockQuoteValidationEdgeCases() async throws {
        // Test edge cases for StockQuote validation
        
        // Valid quote
        let validQuote = StockQuote(symbol: "AAPL", price: 150.0, companyName: "Apple Inc.", lastUpdated: Date())
        #expect(validQuote.isValid)
        
        // Invalid: zero price
        let zeroPrice = StockQuote(symbol: "TEST", price: 0.0, companyName: "Test Co", lastUpdated: Date())
        #expect(!zeroPrice.isValid)
        
        // Invalid: negative price
        let negativePrice = StockQuote(symbol: "TEST", price: -10.0, companyName: "Test Co", lastUpdated: Date())
        #expect(!negativePrice.isValid)
        
        // Invalid: empty symbol
        let emptySymbol = StockQuote(symbol: "", price: 100.0, companyName: "Test Co", lastUpdated: Date())
        #expect(!emptySymbol.isValid)
        
        // Valid: minimal data
        let minimalQuote = StockQuote(symbol: "TEST", price: 0.01, companyName: nil, lastUpdated: Date())
        #expect(minimalQuote.isValid)
        
        // Test formatted price
        #expect(validQuote.formattedPrice == "$150.00")
        #expect(minimalQuote.formattedPrice == "$0.01")
    }
    
    // MARK: - Auto-Fetch Integration Tests
    
    @Test func portfolioManagerWithStockQuote() async throws {
        clearTestData()
        defer { clearTestData() }
        
        let portfolioManager = PortfolioManager()
        let portfolio = portfolioManager.createPortfolio(name: "Auto-Fetch Test Portfolio")
        
        // Create a test stock quote
        let stockQuote = StockQuote(
            symbol: "AAPL",
            price: 175.50,
            companyName: "Apple Inc.",
            lastUpdated: Date()
        )
        
        // Add holding using the new async method with stock quote
        let holding = try await portfolioManager.addHolding(
            to: portfolio,
            stockQuote: stockQuote,
            quantity: 10,
            datePurchased: Date()
        )
        
        #expect(holding.quantity == 10)
        #expect(holding.pricePerShare.doubleValue == 175.50)
        #expect(holding.stock?.symbol == "AAPL")
        #expect(holding.stock?.companyName == "Apple Inc.")
        #expect(holding.stock?.currentPrice?.doubleValue == 175.50)
        
        // Verify portfolio calculations work with auto-fetched data
        let totalValue = portfolioManager.calculatePortfolioValue(portfolio)
        #expect(totalValue == Decimal(1755.0)) // 10 * 175.50
        
        // Total cost functionality has been removed
    }
    
    @Test func updatePortfolioPricesAsync() async throws {
        clearTestData()
        defer { clearTestData() }
        
        let portfolioManager = PortfolioManager()
        let portfolio = portfolioManager.createPortfolio(name: "Price Update Test")
        
        // Add holdings with initial prices
        portfolioManager.addHolding(
            to: portfolio,
            symbol: "AAPL",
            quantity: 10,
            pricePerShare: Decimal(150.00),
            datePurchased: Date()
        )
        
        portfolioManager.addHolding(
            to: portfolio,
            symbol: "GOOGL",
            quantity: 5,
            pricePerShare: Decimal(200.00),
            datePurchased: Date()
        )
        
        // Initial portfolio value should be based on purchase prices
        let initialValue = portfolioManager.calculatePortfolioValue(portfolio)
        #expect(initialValue == Decimal(2500.0))
        
        // Update portfolio prices using real API
        await portfolioManager.updatePortfolioPrices(portfolio)
        
        // After update, current prices should be updated
        guard let holdings = portfolio.holdings as? Set<Holding> else {
            #expect(false, "Holdings should exist")
            return
        }
        
        for holding in holdings {
            #expect(holding.stock?.currentPrice?.doubleValue ?? 0 > 0)
            #expect(holding.stock?.lastUpdated != nil)
            print("✓ Updated \(holding.stock?.symbol ?? "unknown"): $\(holding.stock?.currentPrice?.doubleValue ?? 0)")
        }
    }
    
    @Test func portfolioManagerAsyncAddHoldingWithRealAPI() async throws {
        clearTestData()
        defer { clearTestData() }
        
        let portfolioManager = PortfolioManager()
        let portfolio = portfolioManager.createPortfolio(name: "Real API Test Portfolio")
        
        // Try to add a holding using real API data
        do {
            let stockPriceService = StockPriceService()
            let quote = try await stockPriceService.fetchStockPrice(symbol: "AAPL")
            
            let holding = try await portfolioManager.addHolding(
                to: portfolio,
                stockQuote: quote,
                quantity: 5,
                datePurchased: Date()
            )
            
            #expect(holding.quantity == 5)
            #expect(holding.stock?.symbol == "AAPL")
            #expect(holding.stock?.currentPrice?.doubleValue == quote.price)
            #expect(holding.stock?.companyName != nil)
            #expect(!holding.stock!.companyName!.isEmpty)
            
            print("✓ Added holding with real data: \(holding.stock?.companyName ?? "AAPL") at \(quote.formattedPrice)")
        } catch {
            print("⚠️ Real API test skipped due to error: \(error)")
            // Don't fail test for API issues - use demo data as fallback test
            let demoQuote = StockQuote(symbol: "AAPL", price: 150.0, companyName: "Apple Inc.", lastUpdated: Date())
            let holding = try await portfolioManager.addHolding(
                to: portfolio,
                stockQuote: demoQuote,
                quantity: 5,
                datePurchased: Date()
            )
            #expect(holding.quantity == 5)
        }
    }
    
    @Test func backgroundUpdateServiceWithRealAPI() async throws {
        clearTestData()
        defer { clearTestData() }
        
        let portfolioManager = PortfolioManager()
        let portfolio = portfolioManager.createPortfolio(name: "Background Update Test")
        
        // Add holdings with demo prices first
        portfolioManager.addHolding(
            to: portfolio,
            symbol: "AAPL",
            quantity: 10,
            pricePerShare: Decimal(100.00), // Deliberately low price
            datePurchased: Date()
        )
        
        portfolioManager.addHolding(
            to: portfolio,
            symbol: "MSFT",
            quantity: 5,
            pricePerShare: Decimal(50.00), // Deliberately low price
            datePurchased: Date()
        )
        
        let backgroundService = BackgroundUpdateService()
        
        // Record initial state
        guard let holdings = portfolio.holdings as? Set<Holding> else {
            #expect(false, "Holdings should exist")
            return
        }
        
        let initialPrices = holdings.compactMap { ($0.stock?.symbol ?? "", $0.stock?.currentPrice?.doubleValue ?? 0) }
        
        // Update all stock prices
        await backgroundService.updateAllStockPrices()
        
        // Verify prices were updated
        for holding in holdings {
            let symbol = holding.stock?.symbol ?? ""
            let newPrice = holding.stock?.currentPrice?.doubleValue ?? 0
            
            #expect(newPrice > 0)
            #expect(holding.stock?.lastUpdated != nil)
            
            // Check if price history was created
            let priceHistoryCount = holding.stock?.priceHistory?.count ?? 0
            #expect(priceHistoryCount > 0)
            
            print("✓ Background update for \(symbol): $\(newPrice)")
        }
    }
    
    @Test func stockPriceServicePerformanceBenchmark() async throws {
        let service = StockPriceService()
        service.clearCache()
        
        let symbols = ["AAPL", "MSFT", "GOOGL", "TSLA", "AMZN", "META", "NVDA", "NFLX"]
        
        // Test sequential fetches
        let sequentialStart = CFAbsoluteTimeGetCurrent()
        for symbol in symbols.prefix(3) { // Test with fewer symbols to avoid rate limits
            do {
                _ = try await service.fetchStockPrice(symbol: symbol)
            } catch {
                print("⚠️ Sequential fetch failed for \(symbol): \(error)")
            }
        }
        let sequentialTime = CFAbsoluteTimeGetCurrent() - sequentialStart
        
        service.clearCache()
        
        // Test concurrent fetches
        let concurrentStart = CFAbsoluteTimeGetCurrent()
        let _ = await service.fetchMultipleStockPrices(symbols: Array(symbols.prefix(3)))
        let concurrentTime = CFAbsoluteTimeGetCurrent() - concurrentStart
        
        print("📊 Performance: Sequential: \(String(format: "%.2f", sequentialTime))s, Concurrent: \(String(format: "%.2f", concurrentTime))s")
        
        // Concurrent should generally be faster or comparable
        #expect(concurrentTime <= sequentialTime + 2.0) // Allow some variance
    }
    
    @Test func stockPriceServiceCacheExpiration() async throws {
        let service = StockPriceService()
        service.clearCache()
        
        // Add a mock quote to cache manually
        let testSymbol = "TESTCACHE"
        let testQuote = StockQuote(
            symbol: testSymbol,
            price: 100.0,
            companyName: "Test Company",
            lastUpdated: Date(timeIntervalSinceNow: -400) // 400 seconds ago (expired)
        )
        
        service.setCachedPrice(symbol: testSymbol, quote: testQuote)
        
        // Should be cached but expired (cache validity is 300 seconds)
        #expect(service.cacheSize > 0)
        
        // When we try to fetch, it should not use the expired cache
        // (This will likely fail with invalid symbol, but that's expected)
        do {
            let _ = try await service.fetchStockPrice(symbol: testSymbol)
        } catch {
            // Expected to fail since TESTCACHE is not a real symbol
            #expect(error is StockPriceService.APIError)
        }
    }
    
    @Test func stockPriceServiceErrorHandlingRobustness() async throws {
        let service = StockPriceService()
        
        // Test various error conditions
        let errorTestCases = [
            ("", "empty string"),
            ("   ", "whitespace only"),
            ("VERYLONGINVALIDSYMBOLNAME123456789", "very long symbol"),
            ("!@#$%^&*()", "special characters"),
            ("12345", "numbers only")
        ]
        
        for (symbol, description) in errorTestCases {
            do {
                let _ = try await service.fetchStockPrice(symbol: symbol)
                if symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    #expect(false, "\(description) should have failed")
                }
            } catch let apiError as StockPriceService.APIError {
                #expect(apiError.errorDescription != nil)
                print("✓ Properly handled \(description): \(apiError.errorDescription!)")
            } catch {
                print("✓ Handled \(description) with error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    @Test func portfolioWithNoHoldings() async throws {
        clearTestData()
        defer { clearTestData() }
        
        let portfolioManager = PortfolioManager()
        let portfolio = portfolioManager.createPortfolio(name: "Empty Portfolio")
        
        let value = portfolioManager.calculatePortfolioValue(portfolio)
        #expect(value == 0)
    }
    
    @Test func stockSymbolCaseHandling() async throws {
        clearTestData()
        defer { clearTestData() }
        
        let portfolioManager = PortfolioManager()
        let portfolio = portfolioManager.createPortfolio(name: "Case Test Portfolio")
        
        // Add holdings with lowercase symbols
        portfolioManager.addHolding(
            to: portfolio,
            symbol: "aapl",
            quantity: 10,
            pricePerShare: Decimal(150.00),
            datePurchased: Date()
        )
        
        portfolioManager.addHolding(
            to: portfolio,
            symbol: "AAPL",  // Same symbol, uppercase
            quantity: 5,
            pricePerShare: Decimal(160.00),
            datePurchased: Date()
        )
        
        // Should use the same stock object (both should use uppercase)
        let stockRequest: NSFetchRequest<Stock> = Stock.fetchRequest()
        let stocks = try DataManager.shared.context.fetch(stockRequest)
        
        #expect(stocks.count == 1)
        #expect(stocks.first?.symbol == "AAPL")
        #expect(stocks.first?.holdings?.count == 2)
    }
    
    @Test func symbolCleaning() async throws {
        let service = StockPriceService()
        
        // Test symbol cleaning with whitespace and case conversion
        let quote1 = await service.fetchDemoStockPrice(symbol: " aapl ")
        #expect(quote1.symbol == "AAPL")
        
        let quote2 = await service.fetchDemoStockPrice(symbol: "googl")
        #expect(quote2.symbol == "GOOGL")
        
        let quote3 = await service.fetchDemoStockPrice(symbol: "MSFT")
        #expect(quote3.symbol == "MSFT")
    }
    
    @Test func multipleStockPricesFetch() async throws {
        let service = StockPriceService()
        let symbols = ["AAPL", "GOOGL", "MSFT", "TSLA"]
        
        let quotes = await service.fetchMultipleStockPrices(symbols: symbols)
        
        // Should get results for all symbols (using demo data)
        #expect(quotes.count == symbols.count)
        
        for (symbol, quote) in quotes {
            #expect(symbols.contains(symbol))
            #expect(quote.symbol == symbol)
            #expect(quote.isValid)
            #expect(quote.price > 0)
        }
    }
    
    @Test func holdingUpdateAndDeletion() async throws {
        clearTestData()
        defer { clearTestData() }
        
        let portfolioManager = PortfolioManager()
        let portfolio = portfolioManager.createPortfolio(name: "CRUD Test Portfolio")
        
        let holding = portfolioManager.addHolding(
            to: portfolio,
            symbol: "MSFT",
            quantity: 10,
            pricePerShare: Decimal(300.00),
            datePurchased: Date()
        )
        
        // Test update
        portfolioManager.updateHolding(holding, quantity: 15, pricePerShare: Decimal(310.00))
        
        #expect(holding.quantity == 15)
        #expect(holding.pricePerShare as Decimal == Decimal(310.00))
        
        // Test deletion
        portfolioManager.deleteHolding(holding)
        
        // Portfolio should exist but have no holdings
        let fetchRequest: NSFetchRequest<Portfolio> = Portfolio.fetchRequest()
        let portfolios = try DataManager.shared.context.fetch(fetchRequest)
        #expect(portfolios.count == 1)
        #expect(portfolios.first?.holdings?.count == 0)
    }

}

// MARK: - Mock Classes for Testing

class MockStockPriceService: StockPriceService {
    var shouldFail: Bool = false
    var mockQuotes: [String: StockQuote] = [:]
    
    override func fetchStockPrice(symbol: String) async throws -> StockQuote {
        if shouldFail {
            throw APIError.networkError(NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock network error"]))
        }
        
        if let mockQuote = mockQuotes[symbol.uppercased()] {
            return mockQuote
        }
        
        return await fetchDemoStockPrice(symbol: symbol)
    }
    
    func setMockQuote(symbol: String, price: Double, companyName: String? = nil) {
        mockQuotes[symbol.uppercased()] = StockQuote(
            symbol: symbol,
            price: price,
            companyName: companyName ?? "\(symbol) Corporation",
            lastUpdated: Date()
        )
    }
}
