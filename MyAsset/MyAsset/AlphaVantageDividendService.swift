import Foundation

class AlphaVantageDividendService: DividendProvider {
    let providerName = "Alpha Vantage Dividends"
    
    private let baseURL = "https://www.alphavantage.co/query"
    private let session = URLSession.shared
    private let apiKeyManager = APIKeyManager.shared
    
    // Rate limiting for Alpha Vantage (25 requests per day for free tier)
    private var requestCount = 0
    private var lastResetDate = Date()
    private let maxRequestsPerDay = 25
    
    var isAvailable: Bool {
        return apiKeyManager.hasAPIKey(for: .alphaVantage)
    }
    
    func fetchDividendInfo(symbol: String) async throws -> DistributionInfo {
        // Check rate limits
        try checkRateLimit()
        
        guard let apiKey = apiKeyManager.getAPIKey(for: .alphaVantage) else {
            throw ProviderError.apiKeyMissing
        }
        
        guard let url = URL(string: "\(baseURL)?function=DIVIDENDS&symbol=\(symbol)&apikey=\(apiKey)") else {
            throw ProviderError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30.0
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProviderError.networkError(NSError(domain: "NoHTTPResponse", code: 0))
            }
            
            if httpResponse.statusCode != 200 {
                throw ProviderError.noData
            }
            
            // Increment rate limit counter
            incrementRequestCount()
            
            let dividendResponse = try JSONDecoder().decode(AlphaVantageDividendResponse.self, from: data)
            
            guard !dividendResponse.data.isEmpty else {
                throw ProviderError.noData
            }
            
            // Get the most recent dividend
            let mostRecentDividend = dividendResponse.data.first!
            
            // Parse dividend amount
            guard let dividendAmount = Double(mostRecentDividend.dividendAmount) else {
                throw ProviderError.noData
            }
            
            // Parse dates
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            let exDate = dateFormatter.date(from: mostRecentDividend.exDividendDate)
            let payDate = mostRecentDividend.paymentDate != nil ? dateFormatter.date(from: mostRecentDividend.paymentDate!) : nil
            
            // Improved dividend calculation based on symbol type
            let (estimatedAnnualDividend, frequency) = calculateAnnualDividendAndFrequency(
                symbol: symbol, 
                mostRecentAmount: dividendAmount,
                dividends: dividendResponse.data
            )
            
            return DistributionInfo(
                symbol: symbol,
                distributionRate: estimatedAnnualDividend,
                distributionYieldPercent: nil, // Yield calculation would need current stock price
                distributionFrequency: frequency,
                lastExDate: exDate,
                lastPaymentDate: payDate,
                fullName: nil // Will be populated from stock quote if needed
            )
            
        } catch let error as ProviderError {
            throw error
        } catch {
            throw ProviderError.networkError(error)
        }
    }
    
    // MARK: - Rate Limiting
    
    private func checkRateLimit() throws {
        let calendar = Calendar.current
        let currentDate = Date()
        
        // Reset counter if it's a new day
        if !calendar.isDate(lastResetDate, inSameDayAs: currentDate) {
            requestCount = 0
            lastResetDate = currentDate
        }
        
        // Check if we've exceeded the daily limit
        if requestCount >= maxRequestsPerDay {
            throw ProviderError.rateLimitExceeded
        }
    }
    
    private func incrementRequestCount() {
        requestCount += 1
    }
    
    // Get usage info for monitoring
    func getUsageInfo() -> (requestsUsed: Int, dailyLimit: Int, resetsAt: Date) {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: lastResetDate) ?? Date()
        return (requestCount, maxRequestsPerDay, tomorrow)
    }
    
    // MARK: - Helper Methods
    
    private func calculateAnnualDividendAndFrequency(
        symbol: String, 
        mostRecentAmount: Double, 
        dividends: [AlphaVantageDividendResponse.AlphaVantageDividend]
    ) -> (annualAmount: Double, frequency: String) {
        let symbolUpper = symbol.uppercased()
        
        // For known monthly distribution ETFs
        if isKnownMonthlyETF(symbolUpper) {
            return (mostRecentAmount * 12.0, "Monthly")
        }
        
        // Try to detect frequency from dividend history if we have enough data
        if dividends.count >= 4 {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            let recentDates = dividends.prefix(4).compactMap { 
                dateFormatter.date(from: $0.exDividendDate) 
            }.sorted(by: >)
            
            if recentDates.count >= 4 {
                let intervals = zip(recentDates, recentDates.dropFirst()).map { 
                    $0.0.timeIntervalSince($0.1) 
                }
                let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
                let avgDays = avgInterval / (24 * 60 * 60)
                
                // Classify based on average interval
                if avgDays < 45 {
                    return (mostRecentAmount * 12.0, "Monthly")
                } else if avgDays < 120 {
                    return (mostRecentAmount * 4.0, "Quarterly")
                } else if avgDays < 270 {
                    return (mostRecentAmount * 2.0, "Semi-Annual")
                } else {
                    return (mostRecentAmount, "Annual")
                }
            }
        }
        
        // Default fallback: assume quarterly
        return (mostRecentAmount * 4.0, "Quarterly")
    }
    
    private func isKnownMonthlyETF(_ symbol: String) -> Bool {
        let monthlyETFs: Set<String> = [
            "QQQI", "QYLD", "RYLD", "XYLD", "NUSI", "JEPI", "JEPQ",
            "DIVO", "FDVV", "DIV", "SPHD"
        ]
        return monthlyETFs.contains(symbol)
    }
}