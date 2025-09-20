import Foundation

/**
 * QQQI Verification Test
 * 
 * Simple test to verify the improvements work for QQQI (Invesco NASDAQ Internet ETF)
 * Expected: Distribution rate ~14.42, Frequency: Monthly
 */

class QQQIVerificationTest {
    
    func testQQQIDividendData() async {
        print("🎯 QQQI Dividend Data Verification Test")
        print("Expected: Rate ~14.42, Frequency: Monthly")
        print("=" + String(repeating: "=", count: 50))
        print("")
        
        let dividendManager = DividendManager()
        
        // Test QQQI with improved dividend manager
        print("📊 Testing QQQI with improved provider order...")
        let startTime = Date()
        let distributionInfo = await dividendManager.fetchDistributionInfo(symbol: "QQQI")
        let duration = Date().timeIntervalSince(startTime)
        
        print("⏱️  Request completed in \(String(format: "%.2f", duration))s")
        print("")
        
        // Display results
        displayDistributionInfo(distributionInfo, symbol: "QQQI")
        
        // Evaluate accuracy
        evaluateAccuracy(distributionInfo)
        
        // Show provider status
        print("\n🔧 Provider Status:")
        let providerStatus = dividendManager.getProviderStatus()
        for (index, status) in providerStatus.enumerated() {
            let icon = status.available ? "✅" : "❌"
            print("  \(index + 1). \(status.priority): \(status.name) \(icon)")
        }
        
        // Test individual providers for comparison
        print("\n🔍 Testing Individual Providers:")
        await testIndividualProviders()
        
        print("\n💡 To improve results:")
        print("  • Configure EODHD API key for best accuracy")
        print("  • Yahoo Finance and Nasdaq are free alternatives")
        print("  • Rate: \(distributionInfo.distributionRate != nil ? "✅" : "❌")")
        print("  • Frequency: \(distributionInfo.distributionFrequency != nil ? "✅" : "❌")")
    }
    
    private func testIndividualProviders() async {
        let providers: [DividendProvider] = [
            EODHDDividendService(),
            YahooFinanceDividendService(),
            NasdaqDividendService(),
            FinnhubDividendService(),
            AlphaVantageDividendService()
        ]
        
        for provider in providers {
            guard provider.isAvailable else {
                print("  ❌ \(provider.providerName): Not available")
                continue
            }
            
            do {
                let info = try await provider.fetchDividendInfo(symbol: "QQQI")
                let rate = info.distributionRate?.formatted(.number.precision(.fractionLength(2))) ?? "N/A"
                let frequency = info.distributionFrequency ?? "N/A"
                print("  ✅ \(provider.providerName): Rate=\(rate), Freq=\(frequency)")
            } catch {
                print("  ❌ \(provider.providerName): \(error.localizedDescription)")
            }
        }
    }
    
    private func displayDistributionInfo(_ info: DistributionInfo, symbol: String) {
        print("📈 DISTRIBUTION INFO FOR \(symbol):")
        print("  Symbol: \(info.symbol)")
        print("  Rate: \(info.distributionRate?.formatted(.number.precision(.fractionLength(2))) ?? "N/A")")
        print("  Yield: \(info.distributionYieldPercent?.formatted(.number.precision(.fractionLength(2))) ?? "N/A")%")
        print("  Frequency: \(info.distributionFrequency ?? "N/A")")
        print("  Last Ex-Date: \(info.lastExDate?.formatted(.dateTime.month().day().year()) ?? "N/A")")
        print("  Last Pay Date: \(info.lastPaymentDate?.formatted(.dateTime.month().day().year()) ?? "N/A")")
        print("  Full Name: \(info.fullName ?? "N/A")")
    }
    
    private func evaluateAccuracy(_ info: DistributionInfo) {
        print("\n🎯 ACCURACY EVALUATION:")
        
        // Rate accuracy
        if let rate = info.distributionRate {
            let expectedRate = 14.42
            let difference = abs(rate - expectedRate)
            let percentageDifference = (difference / expectedRate) * 100
            
            let rateAccuracy: String
            if percentageDifference < 5 {
                rateAccuracy = "🟢 Excellent"
            } else if percentageDifference < 15 {
                rateAccuracy = "🟡 Good"
            } else if percentageDifference < 30 {
                rateAccuracy = "🟠 Fair"
            } else {
                rateAccuracy = "🔴 Poor"
            }
            
            print("  Rate: \(rateAccuracy) - \(rate.formatted(.number.precision(.fractionLength(2)))) vs expected 14.42")
            print("        Difference: \(difference.formatted(.number.precision(.fractionLength(2)))) (\(percentageDifference.formatted(.number.precision(.fractionLength(1))))%)")
        } else {
            print("  Rate: ❌ Missing")
        }
        
        // Frequency accuracy
        if let frequency = info.distributionFrequency {
            let isCorrect = frequency.lowercased().contains("monthly") || frequency.lowercased().contains("month")
            let frequencyAccuracy = isCorrect ? "🟢 Correct" : "🟡 Incorrect"
            print("  Frequency: \(frequencyAccuracy) - \(frequency) (expected: Monthly)")
        } else {
            print("  Frequency: ❌ Missing")
        }
        
        // Overall score
        var score = 0.0
        if let rate = info.distributionRate {
            let expectedRate = 14.42
            let rateDifference = abs(rate - expectedRate) / expectedRate
            score += max(0, 1 - rateDifference) * 0.6 // 60% weight on rate accuracy
        }
        
        if let frequency = info.distributionFrequency?.lowercased() {
            if frequency.contains("monthly") || frequency.contains("month") {
                score += 0.4 // 40% weight on frequency accuracy
            }
        }
        
        let scorePercentage = Int(score * 100)
        print("  Overall Score: \(scorePercentage)%")
        
        if scorePercentage >= 80 {
            print("  ✅ EXCELLENT - Provider improvements are working well!")
        } else if scorePercentage >= 60 {
            print("  🟡 GOOD - Some improvements visible, may need API key for best results")
        } else {
            print("  🔴 NEEDS WORK - Consider configuring API keys for better data")
        }
    }
}

// Test runner function
func runQQQIVerificationTest() async {
    let tester = QQQIVerificationTest()
    await tester.testQQQIDividendData()
}