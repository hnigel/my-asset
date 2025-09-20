import Foundation

class StockPriceManager: ObservableObject {
    
    // MARK: - Properties
    
    private var priceCache: [String: (quote: StockQuote, timestamp: Date)] = [:]
    private let cacheValidityInterval: TimeInterval = 300 // 5 minutes
    private let cacheLock = NSLock() // Thread safety for cache access
    
    // Stock price providers in order of preference
    private let providers: [StockPriceProvider] = [
        YahooFinanceStockService(),      // Primary - Free, reliable
        FinnhubStockService(),           // Secondary - Fast, real-time, 30 req/sec
        NasdaqStockService(),            // Tertiary - Free, good coverage
        AlphaVantageStockService()       // Quaternary - Rate limited but reliable
    ]
    
    // MARK: - Public Methods
    
    func fetchStockPrice(symbol: String) async throws -> StockQuote {
        let cleanSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        // Check cache first (thread-safe)
        cacheLock.lock()
        let cachedData = priceCache[cleanSymbol]
        cacheLock.unlock()
        
        if let cachedData = cachedData,
           Date().timeIntervalSince(cachedData.timestamp) < cacheValidityInterval {
            return cachedData.quote
        }
        
        // Try providers in order of priority
        var lastError: Error?
        var attemptedProviders: [String] = []
        
        for provider in providers {
            guard provider.isAvailable else {
                print("⚠️ \(provider.providerName) is not available, skipping...")
                continue
            }
            
            do {
                let quote = try await provider.fetchStockPrice(symbol: cleanSymbol)
                print("✓ \(provider.providerName) provided data for \(cleanSymbol)")
                
                // Cache successful result (thread-safe)
                cacheLock.lock()
                priceCache[cleanSymbol] = (quote: quote, timestamp: Date())
                cacheLock.unlock()
                return quote
                
            } catch {
                print("✗ \(provider.providerName) failed for \(cleanSymbol): \(error.localizedDescription)")
                attemptedProviders.append(provider.providerName)
                lastError = error
                
                // Continue to next provider
                continue
            }
        }
        
        // All providers failed
        print("❌ All stock price providers failed for \(cleanSymbol). Tried: \(attemptedProviders.joined(separator: ", "))")
        throw lastError ?? ProviderError.noData
    }
    
    func fetchMultipleStockPrices(symbols: [String]) async -> [String: StockQuote] {
        var results: [String: StockQuote] = [:]
        
        // Use TaskGroup for concurrent requests
        await withTaskGroup(of: (String, StockQuote?).self) { group in
            for symbol in symbols {
                group.addTask {
                    do {
                        let quote = try await self.fetchStockPrice(symbol: symbol)
                        return (symbol, quote)
                    } catch {
                        print("Failed to fetch price for \(symbol): \(error.localizedDescription)")
                        return (symbol, nil)
                    }
                }
            }
            
            for await (symbol, quote) in group {
                if let quote = quote {
                    results[symbol] = quote
                }
            }
        }
        
        return results
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        cacheLock.lock()
        priceCache.removeAll()
        cacheLock.unlock()
        print("Stock price cache cleared")
    }
    
    func isCached(symbol: String) -> Bool {
        cacheLock.lock()
        let cachedData = priceCache[symbol.uppercased()]
        cacheLock.unlock()
        
        guard let cachedData = cachedData else { return false }
        return Date().timeIntervalSince(cachedData.timestamp) < cacheValidityInterval
    }
    
    func setCachedPrice(symbol: String, quote: StockQuote) {
        cacheLock.lock()
        priceCache[symbol.uppercased()] = (quote: quote, timestamp: Date())
        cacheLock.unlock()
    }
    
    var cacheSize: Int {
        cacheLock.lock()
        let count = priceCache.count
        cacheLock.unlock()
        return count
    }
    
    // MARK: - Provider Management
    
    func getAvailableProviders() -> [StockPriceProvider] {
        return providers.filter { $0.isAvailable }
    }
    
    func getProviderStatus() -> [(name: String, available: Bool, priority: String)] {
        return providers.enumerated().map { index, provider in
            let priority: String
            switch index {
            case 0: priority = "Primary"
            case 1: priority = "Secondary"
            case 2: priority = "Tertiary"
            default: priority = "Quaternary"
            }
            return (name: provider.providerName, available: provider.isAvailable, priority: priority)
        }
    }
    
    // Get Alpha Vantage usage info if available
    func getAlphaVantageUsage() -> (requestsUsed: Int, dailyLimit: Int, resetsAt: Date)? {
        guard let alphaVantageService = providers.compactMap({ $0 as? AlphaVantageStockService }).first else {
            return nil
        }
        return alphaVantageService.getUsageInfo()
    }
    
    // Get Finnhub usage info if available
    func getFinnhubUsage() -> (requestsUsed: Int, perSecondLimit: Int, windowResetsAt: Date)? {
        guard let finnhubService = providers.compactMap({ $0 as? FinnhubStockService }).first else {
            return nil
        }
        return finnhubService.getUsageInfo()
    }
}