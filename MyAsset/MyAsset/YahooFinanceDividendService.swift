import Foundation

class YahooFinanceDividendService: DividendProvider {
    let providerName = "Yahoo Finance Dividends"
    let isAvailable = true
    
    private let baseURL = "https://query1.finance.yahoo.com/v8/finance/chart"
    private let session = URLSession.shared
    
    func fetchDividendInfo(symbol: String) async throws -> DistributionInfo {
        // Use chart API with dividend events - this works without authentication
        guard let url = URL(string: "\(baseURL)/\(symbol)?range=1y&events=div&interval=1d&includePrePost=false") else {
            throw ProviderError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15.0
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProviderError.networkError(NSError(domain: "NoHTTPResponse", code: 0, userInfo: nil))
            }
            
            switch httpResponse.statusCode {
            case 200:
                break
            case 404:
                throw ProviderError.invalidSymbol(symbol)
            case 429:
                throw ProviderError.rateLimitExceeded
            default:
                throw ProviderError.networkError(NSError(domain: "HTTPError", code: httpResponse.statusCode))
            }
            
            let yahooResponse = try JSONDecoder().decode(YahooFinanceResponse.self, from: data)
            
            guard let result = yahooResponse.chart.result?.first else {
                if let error = yahooResponse.chart.error {
                    throw ProviderError.invalidSymbol("\(symbol): \(error.description)")
                }
                throw ProviderError.noData
            }
            
            let meta = result.meta
            let companyName = meta.longName ?? "\(symbol) Corporation"
            
            // Parse dividend events from chart data
            var distributionRate: Double? = nil
            var lastExDate: Date? = nil
            var lastPayDate: Date? = nil
            var estimatedYield: Double? = nil
            var estimatedFrequency: String = "Quarterly"
            
            // Check for dividend events in the response
            if let chartData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let chart = chartData["chart"] as? [String: Any],
               let results = chart["result"] as? [[String: Any]],
               let firstResult = results.first,
               let events = firstResult["events"] as? [String: Any],
               let dividends = events["dividends"] as? [String: Any] {
                
                // Get the most recent dividend entries
                let sortedTimestamps = dividends.keys.compactMap { Double($0) }.sorted(by: >)
                
                if !sortedTimestamps.isEmpty {
                    // Get recent dividend data for frequency analysis
                    let oneYearAgo = Date().timeIntervalSince1970 - (365 * 24 * 60 * 60)
                    let recentTimestamps = sortedTimestamps.filter { $0 >= oneYearAgo }
                    
                    // Calculate annual dividend rate from last 12 months
                    let recentDividends = recentTimestamps.compactMap { timestamp in
                        dividends[String(Int(timestamp))] as? [String: Any]
                    }.compactMap { div in
                        div["amount"] as? Double
                    }
                    
                    if !recentDividends.isEmpty {
                        // Sum recent 12-month dividends for accurate annual rate
                        distributionRate = recentDividends.reduce(0, +)
                        
                        // Detect frequency based on number of payments in last 12 months
                        estimatedFrequency = detectDividendFrequency(count: recentDividends.count)
                        
                        // Calculate yield if we have current price
                        if let currentPrice = meta.regularMarketPrice, currentPrice > 0 {
                            estimatedYield = (distributionRate! / currentPrice) * 100.0
                        }
                    }
                    
                    // Get most recent ex-dividend date
                    if let mostRecentTimestamp = sortedTimestamps.first {
                        lastExDate = Date(timeIntervalSince1970: mostRecentTimestamp)
                        
                        // Payment date is typically ~3 weeks after ex-date for most US stocks
                        lastPayDate = Calendar.current.date(byAdding: .day, value: 21, to: lastExDate!)
                    }
                }
            }
            
            return DistributionInfo(
                symbol: symbol,
                distributionRate: distributionRate,
                distributionYieldPercent: estimatedYield,
                distributionFrequency: estimatedFrequency,
                lastExDate: lastExDate,
                lastPaymentDate: lastPayDate,
                fullName: companyName
            )
            
        } catch let error as ProviderError {
            throw error
        } catch {
            throw ProviderError.networkError(error)
        }
    }
    
    // MARK: - Helper Methods
    
    private func detectDividendFrequency(count: Int) -> String {
        switch count {
        case 1:
            return "Annual"
        case 2:
            return "Semi-Annual"
        case 3:
            return "Quarterly" // Sometimes irregular
        case 4:
            return "Quarterly"
        case 6:
            return "Bi-Monthly"
        case 12:
            return "Monthly"
        case let c where c > 12:
            return "Monthly" // Likely monthly with some extra distributions
        case let c where c > 4:
            return "Variable" // Irregular distribution pattern
        default:
            return "Quarterly" // Default fallback
        }
    }
}