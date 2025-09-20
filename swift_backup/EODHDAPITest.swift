import Foundation

/**
 * EODHD API Testing Utility
 * 
 * This utility tests EODHD API connectivity and validates the API key.
 * Run this to verify EODHD integration works correctly.
 */
class EODHDAPITest {
    
    private let apiKey = "68c2e2273ae499.81958135"
    private let baseURL = "https://eodhistoricaldata.com/api"
    
    func testAPIConnectivity() async {
        print("🧪 Testing EODHD API Connectivity...")
        
        // Test 1: Basic API key validation with end-of-day data
        await testBasicAPIAccess()
        
        // Test 2: Dividend API endpoint
        await testDividendAPI()
        
        // Test 3: Multiple symbols
        await testMultipleSymbols()
    }
    
    private func testBasicAPIAccess() async {
        print("\n1️⃣ Testing Basic API Access...")
        
        guard let url = URL(string: "\(baseURL)/eod/AAPL.US?api_token=\(apiKey)&fmt=json&period=d&limit=1") else {
            print("❌ Invalid URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ No HTTP response")
                return
            }
            
            print("📡 Status Code: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200:
                print("✅ API key is valid and working")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📊 Sample response: \(String(jsonString.prefix(200)))...")
                }
            case 403:
                print("❌ API key invalid or access forbidden")
            case 401:
                print("❌ Unauthorized - check API key")
            default:
                print("⚠️ Unexpected status code: \(httpResponse.statusCode)")
            }
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
        }
    }
    
    private func testDividendAPI() async {
        print("\n2️⃣ Testing Dividend API...")
        
        let symbols = ["AAPL.US", "MSFT.US", "KO.US"] // Apple, Microsoft, Coca-Cola
        
        for symbol in symbols {
            await testDividendForSymbol(symbol)
        }
    }
    
    private func testDividendForSymbol(_ symbol: String) async {
        guard let url = URL(string: "\(baseURL)/div/\(symbol)?api_token=\(apiKey)&fmt=json") else {
            print("❌ Invalid URL for \(symbol)")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ No HTTP response for \(symbol)")
                return
            }
            
            print("📈 \(symbol) - Status: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        print("✅ \(symbol) - Found \(json.count) dividend entries")
                        
                        if let latest = json.first {
                            print("   Latest: \(latest["date"] ?? "N/A") - $\(latest["value"] ?? "N/A")")
                        }
                    }
                } catch {
                    print("⚠️ \(symbol) - JSON parsing error: \(error.localizedDescription)")
                }
            case 404:
                print("❌ \(symbol) - No dividend data found")
            case 403:
                print("❌ \(symbol) - Access forbidden")
            default:
                print("⚠️ \(symbol) - Status: \(httpResponse.statusCode)")
            }
            
        } catch {
            print("❌ \(symbol) - Network error: \(error.localizedDescription)")
        }
    }
    
    private func testMultipleSymbols() async {
        print("\n3️⃣ Testing Multiple Symbols...")
        
        let testSymbols = [
            "AAPL.US",    // US Stock
            "MSFT.US",    // US Stock  
            "TSM",        // Taiwan (might need different suffix)
            "TSLA.US",    // US Stock
            "SPY.US"      // ETF
        ]
        
        for symbol in testSymbols {
            await testSymbolFormatting(symbol)
        }
    }
    
    private func testSymbolFormatting(_ symbol: String) async {
        guard let url = URL(string: "\(baseURL)/div/\(symbol)?api_token=\(apiKey)&fmt=json") else {
            print("❌ Invalid URL for \(symbol)")
            return
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return
            }
            
            let status = httpResponse.statusCode == 200 ? "✅" : "❌"
            print("\(status) \(symbol) - Status: \(httpResponse.statusCode)")
            
        } catch {
            print("❌ \(symbol) - Error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Usage Example
/*
Task {
    let tester = EODHDAPITest()
    await tester.testAPIConnectivity()
}
*/