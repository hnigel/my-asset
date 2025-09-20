import Foundation

/**
 * Dividend Provider Test
 * 
 * Test script to evaluate all dividend providers with QQQI symbol
 * Expected results for QQQI:
 * - Distribution rate: 14.42 (annual)
 * - Distribution frequency: Monthly
 */

class DividendProviderTest {
    
    private let providers: [DividendProvider] = [
        YahooFinanceDividendService(),
        EODHDDividendService(),
        NasdaqDividendService(),
        AlphaVantageDividendService(),
        FinnhubDividendService()
    ]
    
    func testAllProviders() async {
        let testSymbol = "QQQI"
        print("🧪 Testing dividend providers with symbol: \(testSymbol)")
        print("📊 Expected: Distribution rate ~14.42, Frequency: Monthly")
        print(String(repeating: "=", count: 60))
        
        var results: [(provider: String, success: Bool, data: DistributionInfo?, error: String?)] = []
        
        for provider in providers {
            print("\n🔍 Testing \(provider.providerName)...")
            
            guard provider.isAvailable else {
                print("  ❌ Provider not available (missing API key or configuration)")
                results.append((provider: provider.providerName, success: false, data: nil, error: "Not available"))
                continue
            }
            
            do {
                let startTime = Date()
                let distributionInfo = try await provider.fetchDividendInfo(symbol: testSymbol)
                let duration = Date().timeIntervalSince(startTime)
                
                print("  ✅ Success (%.2fs)", duration)
                print("  📈 Distribution Rate: \(distributionInfo.distributionRate?.formatted(.number.precision(.fractionLength(2))) ?? "N/A")")
                print("  📊 Distribution Yield: \(distributionInfo.distributionYieldPercent?.formatted(.number.precision(.fractionLength(2))) ?? "N/A")%")
                print("  🗓️  Frequency: \(distributionInfo.distributionFrequency ?? "N/A")")
                print("  📅 Last Ex-Date: \(distributionInfo.lastExDate?.formatted(.dateTime.month(.wide).day().year()) ?? "N/A")")
                print("  💰 Last Pay Date: \(distributionInfo.lastPaymentDate?.formatted(.dateTime.month(.wide).day().year()) ?? "N/A")")
                print("  🏢 Company Name: \(distributionInfo.fullName ?? "N/A")")
                
                results.append((provider: provider.providerName, success: true, data: distributionInfo, error: nil))
                
            } catch {
                print("  ❌ Failed: \(error.localizedDescription)")
                results.append((provider: provider.providerName, success: false, data: nil, error: error.localizedDescription))
            }
        }
        
        // Generate summary report
        print("\n" + String(repeating: "=", count: 60))
        print("📋 SUMMARY REPORT")
        print(String(repeating: "=", count: 60))
        
        let successfulProviders = results.filter { $0.success }
        print("✅ Successful providers: \(successfulProviders.count)/\(results.count)")
        
        if !successfulProviders.isEmpty {
            print("\n🏆 PROVIDER RANKING (by accuracy for QQQI):")
            
            // Rank providers by how close they are to expected values
            let rankedProviders = successfulProviders.sorted { first, second in
                let firstScore = calculateAccuracyScore(first.data)
                let secondScore = calculateAccuracyScore(second.data)
                return firstScore > secondScore
            }
            
            for (index, result) in rankedProviders.enumerated() {
                let medal = index == 0 ? "🥇" : index == 1 ? "🥈" : index == 2 ? "🥉" : "🏅"
                let score = calculateAccuracyScore(result.data)
                print("\(medal) \(index + 1). \(result.provider) (Score: \(Int(score * 100))%)")
                
                if let data = result.data {
                    let rateAccuracy = evaluateDistributionRate(data.distributionRate)
                    let frequencyAccuracy = evaluateFrequency(data.distributionFrequency)
                    print("     Rate: \(rateAccuracy), Frequency: \(frequencyAccuracy)")
                }
            }
            
            // Recommendation
            if let bestProvider = rankedProviders.first {
                print("\n🎯 RECOMMENDATION:")
                print("   Use \(bestProvider.provider) as primary provider for dividend data")
                print("   This provider showed the highest accuracy for QQQI test case")
            }
        }
        
        print("\n❌ Failed providers:")
        for result in results where !result.success {
            print("   • \(result.provider): \(result.error ?? "Unknown error")")
        }
    }
    
    private func calculateAccuracyScore(_ data: DistributionInfo?) -> Double {
        guard let data = data else { return 0.0 }
        
        var score: Double = 0.0
        
        // Rate accuracy (50% of score)
        if let rate = data.distributionRate {
            let expectedRate = 14.42
            let rateDifference = abs(rate - expectedRate) / expectedRate
            let rateScore = max(0, 1 - rateDifference) // 1.0 = perfect, decreases with difference
            score += rateScore * 0.5
        }
        
        // Frequency accuracy (30% of score)
        if let frequency = data.distributionFrequency?.lowercased() {
            if frequency.contains("monthly") || frequency.contains("month") {
                score += 0.3 // Perfect frequency match
            } else if frequency.contains("quarterly") || frequency.contains("quarter") {
                score += 0.1 // Some providers might default to quarterly
            }
        }
        
        // Data completeness (20% of score)
        var completenessScore: Double = 0.0
        if data.distributionRate != nil { completenessScore += 0.05 }
        if data.distributionYieldPercent != nil { completenessScore += 0.05 }
        if data.distributionFrequency != nil { completenessScore += 0.05 }
        if data.lastExDate != nil { completenessScore += 0.025 }
        if data.lastPaymentDate != nil { completenessScore += 0.025 }
        
        score += completenessScore
        
        return min(1.0, score) // Cap at 100%
    }
    
    private func evaluateDistributionRate(_ rate: Double?) -> String {
        guard let rate = rate else { return "❌ Missing" }
        
        let expectedRate = 14.42
        let difference = abs(rate - expectedRate)
        let percentageDifference = (difference / expectedRate) * 100
        
        if percentageDifference < 5 {
            return "✅ Excellent (\(rate.formatted(.number.precision(.fractionLength(2)))))"
        } else if percentageDifference < 15 {
            return "🟡 Good (\(rate.formatted(.number.precision(.fractionLength(2)))))"
        } else if percentageDifference < 30 {
            return "🟠 Fair (\(rate.formatted(.number.precision(.fractionLength(2)))))"
        } else {
            return "❌ Poor (\(rate.formatted(.number.precision(.fractionLength(2)))))"
        }
    }
    
    private func evaluateFrequency(_ frequency: String?) -> String {
        guard let frequency = frequency else { return "❌ Missing" }
        
        let lowerFreq = frequency.lowercased()
        if lowerFreq.contains("monthly") || lowerFreq.contains("month") {
            return "✅ Correct (Monthly)"
        } else if lowerFreq.contains("quarterly") || lowerFreq.contains("quarter") {
            return "🟡 Incorrect (Quarterly - should be Monthly)"
        } else {
            return "🟠 Other (\(frequency))"
        }
    }
}

// Test runner function
func runDividendProviderTest() async {
    let tester = DividendProviderTest()
    await tester.testAllProviders()
}