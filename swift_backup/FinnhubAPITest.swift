import Foundation

/**
 * Finnhub API Testing Utility
 * 
 * This utility tests Finnhub API connectivity and validates both stock and dividend endpoints.
 * Run this to verify Finnhub integration works correctly.
 */
class FinnhubAPITest {
    
    private let apiKey = "d31e7u9r01qsprr0ibvgd31e7u9r01qsprr0ic00"
    private let baseURL = "https://finnhub.io/api/v1"
    
    func testAPIConnectivity() async {
        print("🧪 Testing Finnhub API Connectivity...")
        print("🔑 API Key: \(String(apiKey.prefix(10)))...")
        
        // Test 1: API key validation with stock quote
        await testStockQuoteAPI()
        
        // Test 2: Company profile API
        await testCompanyProfileAPI()
        
        // Test 3: Dividend API endpoint
        await testDividendAPI()
        
        // Test 4: Multiple symbols
        await testMultipleSymbols()
        
        // Test 5: Rate limiting
        await testRateLimiting()
    }
    
    private func testStockQuoteAPI() async {
        print("\n1️⃣ Testing Stock Quote API...")
        
        let testSymbols = ["AAPL", "MSFT", "GOOGL", "TSLA", "SPY"]
        
        for symbol in testSymbols {
            await testStockQuote(symbol)
        }
    }
    
    private func testStockQuote(_ symbol: String) async {
        guard let url = URL(string: "\(baseURL)/quote?symbol=\(symbol)&token=\(apiKey)") else {
            print("❌ Invalid URL for \(symbol)")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ \(symbol) - No HTTP response")
                return
            }
            
            print("📈 \(symbol) - Status: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    let quote = try JSONDecoder().decode(FinnhubQuoteResponse.self, from: data)
                    if quote.c > 0 {
                        print("✅ \(symbol) - Price: $\(String(format: "%.2f", quote.c))")
                    } else {
                        print("⚠️ \(symbol) - No price data (market closed?)")
                    }
                } catch {
                    print("⚠️ \(symbol) - JSON parsing error: \(error.localizedDescription)")
                }
            case 401:
                print("❌ \(symbol) - Unauthorized (invalid API key)")
            case 403:
                print("❌ \(symbol) - Forbidden (access denied)")
            case 429:
                print("⚠️ \(symbol) - Rate limit exceeded")
            default:
                print("⚠️ \(symbol) - Status: \(httpResponse.statusCode)")
            }
            
        } catch {
            print("❌ \(symbol) - Network error: \(error.localizedDescription)")
        }
    }
    
    private func testCompanyProfileAPI() async {
        print("\n2️⃣ Testing Company Profile API...")
        
        let testSymbols = ["AAPL", "MSFT"]
        
        for symbol in testSymbols {
            await testCompanyProfile(symbol)
        }
    }
    
    private func testCompanyProfile(_ symbol: String) async {
        guard let url = URL(string: "\(baseURL)/stock/profile2?symbol=\(symbol)&token=\(apiKey)") else {
            print("❌ Invalid URL for \(symbol)")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ \(symbol) - No HTTP response")
                return
            }
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    let profile = try JSONDecoder().decode(FinnhubCompanyProfile.self, from: data)
                    print("✅ \(symbol) - Company: \(profile.name)")
                    if let industry = profile.finnhubIndustry {
                        print("   Industry: \(industry)")
                    }
                } catch {
                    print("⚠️ \(symbol) - Profile parsing error: \(error.localizedDescription)")
                }
            case 401:
                print("❌ \(symbol) - Unauthorized")
            default:
                print("⚠️ \(symbol) - Profile Status: \(httpResponse.statusCode)")
            }
            
        } catch {
            print("❌ \(symbol) - Profile error: \(error.localizedDescription)")
        }
    }
    
    private func testDividendAPI() async {
        print("\n3️⃣ Testing Dividend API...")
        
        let dividendStocks = ["AAPL", "MSFT", "KO", "JNJ"] // Known dividend-paying stocks
        
        for symbol in dividendStocks {
            await testDividendData(symbol)
        }
    }
    
    private func testDividendData(_ symbol: String) async {
        let fromDate = "2023-01-01"
        let toDate = "2024-12-31"
        
        guard let url = URL(string: "\(baseURL)/stock/dividend?symbol=\(symbol)&from=\(fromDate)&to=\(toDate)&token=\(apiKey)") else {
            print("❌ Invalid URL for \(symbol)")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ \(symbol) - No HTTP response")
                return
            }
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        if json.isEmpty {
                            print("⚠️ \(symbol) - No dividend data found")
                        } else {
                            print("✅ \(symbol) - Found \(json.count) dividend entries")
                            if let latest = json.first {
                                print("   Latest: \(latest["date"] ?? "N/A") - $\(latest["amount"] ?? "N/A")")
                            }
                        }
                    }
                } catch {
                    print("⚠️ \(symbol) - Dividend JSON parsing error: \(error.localizedDescription)")
                }
            case 401:
                print("❌ \(symbol) - Dividend API unauthorized")
            case 403:
                print("❌ \(symbol) - Dividend API forbidden (premium required?)")
            default:
                print("⚠️ \(symbol) - Dividend Status: \(httpResponse.statusCode)")
            }
            
        } catch {
            print("❌ \(symbol) - Dividend error: \(error.localizedDescription)")
        }
    }
    
    private func testMultipleSymbols() async {
        print("\n4️⃣ Testing Various Symbol Formats...")
        
        let testSymbols = [
            "AAPL",      // US Stock
            "MSFT",      // US Stock  
            "BRK.B",     // Class B shares
            "BRK.A",     // Class A shares
            "SPY",       // ETF
            "QQQ",       // NASDAQ ETF
            "VTI"        // Vanguard ETF
        ]
        
        for symbol in testSymbols {
            await testSymbolFormat(symbol)
            
            // Small delay to respect rate limits
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        }
    }
    
    private func testSymbolFormat(_ symbol: String) async {
        guard let url = URL(string: "\(baseURL)/quote?symbol=\(symbol)&token=\(apiKey)") else {
            print("❌ Invalid URL for \(symbol)")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return
            }
            
            let status = httpResponse.statusCode == 200 ? "✅" : "❌"
            print("\(status) \(symbol) - Status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                do {
                    let quote = try JSONDecoder().decode(FinnhubQuoteResponse.self, from: data)
                    if quote.c > 0 {
                        print("   Price: $\(String(format: "%.2f", quote.c))")
                    }
                } catch {
                    print("   Parsing error")
                }
            }
            
        } catch {
            print("❌ \(symbol) - Error: \(error.localizedDescription)")
        }
    }
    
    private func testRateLimiting() async {
        print("\n5️⃣ Testing Rate Limiting...")
        
        let startTime = Date()
        let requestCount = 10
        
        print("Making \(requestCount) rapid requests...")
        
        for i in 1...requestCount {
            await testRapidRequest(requestNumber: i)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let requestsPerSecond = Double(requestCount) / duration
        
        print("📊 Rate Test Results:")
        print("   Duration: \(String(format: "%.2f", duration)) seconds")
        print("   Rate: \(String(format: "%.2f", requestsPerSecond)) requests/second")
        
        if requestsPerSecond > 60 {
            print("⚠️ Rate limiting may apply (Finnhub free tier: 60/min)")
        } else {
            print("✅ Within expected rate limits")
        }
    }
    
    private func testRapidRequest(requestNumber: Int) async {
        guard let url = URL(string: "\(baseURL)/quote?symbol=AAPL&token=\(apiKey)") else {
            return
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                let status = httpResponse.statusCode == 200 ? "✅" : "❌"
                print("   Request \(requestNumber): \(status) (\(httpResponse.statusCode))")
            }
            
        } catch {
            print("   Request \(requestNumber): ❌ Error")
        }
    }
}

// MARK: - Note: Uses FinnhubQuoteResponse and FinnhubCompanyProfile from FinnhubStockService.swift

// MARK: - Usage Example
/*
Task {
    let tester = FinnhubAPITest()
    await tester.testAPIConnectivity()
}
*/