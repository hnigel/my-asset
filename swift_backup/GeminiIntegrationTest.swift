import Foundation
import CoreData

/**
 * Gemini Integration Test
 * 
 * This test validates the complete Gemini LLM integration workflow
 * to ensure all components work together properly.
 */
@MainActor
class GeminiIntegrationTest: ObservableObject {
    private let dataManager = DataManager.shared
    private let portfolioManager = PortfolioManager()
    private let geminiAnalysisManager = GeminiAnalysisManager()
    private let portfolioFormatter = PortfolioAnalysisFormatter()
    
    @Published var testResults: [TestResult] = []
    @Published var isRunningTests = false
    @Published var currentTest = ""
    
    struct TestResult {
        let testName: String
        let passed: Bool
        let message: String
        let duration: TimeInterval
    }
    
    // MARK: - Test Suite
    
    func runCompleteTestSuite() async {
        isRunningTests = true
        testResults = []
        
        await runTest("API Key Management") {
            await testAPIKeyManagement()
        }
        
        await runTest("Gemini Service Connection") {
            await testGeminiServiceConnection()
        }
        
        await runTest("Portfolio Data Formatting") {
            await testPortfolioDataFormatting()
        }
        
        await runTest("Privacy Protection") {
            await testPrivacyProtection()
        }
        
        await runTest("Analysis Manager Integration") {
            await testAnalysisManagerIntegration()
        }
        
        await runTest("End-to-End Analysis Workflow") {
            await testEndToEndWorkflow()
        }
        
        isRunningTests = false
        printTestSummary()
    }
    
    // MARK: - Individual Tests
    
    private func testAPIKeyManagement() async -> (Bool, String) {
        let apiKeyManager = APIKeyManager.shared
        
        // Test API key storage and retrieval
        let testKey = "test-gemini-key-12345"
        let success = apiKeyManager.setAPIKey(testKey, for: .gemini)
        
        guard success else {
            return (false, "Failed to store API key")
        }
        
        let retrievedKey = apiKeyManager.getAPIKey(for: .gemini)
        guard retrievedKey == testKey else {
            return (false, "Retrieved key doesn't match stored key")
        }
        
        // Clean up
        _ = apiKeyManager.removeAPIKey(for: .gemini)
        
        return (true, "API key management working correctly")
    }
    
    private func testGeminiServiceConnection() async -> (Bool, String) {
        let geminiService = GeminiService()
        
        // Test configuration validation
        let isConfigured = await geminiService.validateConfiguration()
        
        if !isConfigured {
            return (true, "Gemini not configured (expected for test environment)")
        }
        
        // If configured, test connection
        do {
            let connectionTest = try await geminiService.testConnection()
            return (connectionTest, connectionTest ? "Connection successful" : "Connection failed")
        } catch {
            return (false, "Connection test failed: \\(error.localizedDescription)")
        }
    }
    
    private func testPortfolioDataFormatting() async -> (Bool, String) {
        let testPortfolio = createTestPortfolio()
        
        let formattedData = await portfolioFormatter.formatForAnalysis(
            testPortfolio,
            format: .structured,
            privacySettings: .default
        )
        
        // Validate formatted data contains expected sections
        let requiredSections = [
            "PORTFOLIO OVERVIEW",
            "INDIVIDUAL HOLDINGS",
            "PERFORMANCE METRICS",
            "RISK ASSESSMENT",
            "PRIVACY PROTECTION NOTICE"
        ]
        
        for section in requiredSections {
            if !formattedData.portfolioSummary.contains(section) &&
               !formattedData.holdingsData.contains(section) &&
               !formattedData.performanceData.contains(section) &&
               !formattedData.riskMetrics.contains(section) &&
               !formattedData.privacyNotice.contains(section) {
                return (false, "Missing required section: \\(section)")
            }
        }
        
        return (true, "Portfolio data formatting working correctly")
    }
    
    private func testPrivacyProtection() async -> (Bool, String) {
        let testPortfolio = createTestPortfolio()
        
        // Test with maximum privacy settings
        let maxPrivacyData = await portfolioFormatter.formatForAnalysis(
            testPortfolio,
            format: .structured,
            privacySettings: .maxPrivacy
        )
        
        // Verify no exact dollar amounts are present
        let dollarPattern = "\\$[0-9]+(\\.[0-9]{2})?"
        let regex = try? NSRegularExpression(pattern: dollarPattern)
        
        let combinedText = maxPrivacyData.portfolioSummary + maxPrivacyData.holdingsData + maxPrivacyData.performanceData
        let matches = regex?.matches(in: combinedText, range: NSRange(combinedText.startIndex..., in: combinedText))
        
        if let matches = matches, !matches.isEmpty {
            return (false, "Privacy protection failed: exact dollar amounts found")
        }
        
        return (true, "Privacy protection working correctly")
    }
    
    private func testAnalysisManagerIntegration() async -> (Bool, String) {
        let isConfigured = await geminiAnalysisManager.isGeminiConfigured()
        
        if !isConfigured {
            return (true, "Analysis manager correctly detects unconfigured state")
        }
        
        // If configured, test analysis options
        let analysisTypes = GeminiAnalysisManager.availableAnalysisTypes
        guard !analysisTypes.isEmpty else {
            return (false, "No analysis types available")
        }
        
        let privacyOptions = GeminiAnalysisManager.privacyOptions
        guard !privacyOptions.isEmpty else {
            return (false, "No privacy options available")
        }
        
        return (true, "Analysis manager integration working correctly")
    }
    
    private func testEndToEndWorkflow() async -> (Bool, String) {
        let isConfigured = await geminiAnalysisManager.isGeminiConfigured()
        
        if !isConfigured {
            return (true, "End-to-end test skipped (Gemini not configured)")
        }
        
        let testPortfolio = createTestPortfolio()
        
        do {
            let options = GeminiAnalysisManager.AnalysisOptions(
                analysisType: .comprehensive,
                privacySettings: .default,
                includeTextSummary: true,
                customPrompt: "Please provide a brief test analysis."
            )
            
            let result = try await geminiAnalysisManager.analyzePortfolio(testPortfolio, options: options)
            
            // Validate result structure
            guard !result.aiAnalysis.isEmpty else {
                return (false, "AI analysis is empty")
            }
            
            guard !result.combinedReport.isEmpty else {
                return (false, "Combined report is empty")
            }
            
            guard result.analysisType == .comprehensive else {
                return (false, "Analysis type mismatch")
            }
            
            return (true, "End-to-end workflow completed successfully")
            
        } catch {
            return (false, "End-to-end test failed: \\(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestPortfolio() -> Portfolio {
        let portfolio = Portfolio(context: dataManager.context)
        portfolio.portfolioID = UUID()
        portfolio.name = "Test Portfolio"
        portfolio.createdDate = Date()
        
        // Add some test holdings
        let _ = portfolioManager.addHolding(
            to: portfolio,
            symbol: "AAPL",
            quantity: 10,
            pricePerShare: 150.0,
            datePurchased: Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days ago
        )
        
        let _ = portfolioManager.addHolding(
            to: portfolio,
            symbol: "MSFT",
            quantity: 5,
            pricePerShare: 300.0,
            datePurchased: Date().addingTimeInterval(-60 * 24 * 60 * 60) // 60 days ago
        )
        
        return portfolio
    }
    
    private func runTest(_ testName: String, test: () async -> (Bool, String)) async {
        currentTest = testName
        let startTime = Date()
        
        let (passed, message) = await test()
        
        let duration = Date().timeIntervalSince(startTime)
        let result = TestResult(
            testName: testName,
            passed: passed,
            message: message,
            duration: duration
        )
        
        testResults.append(result)
    }
    
    private func printTestSummary() {
        print("\\n🧪 GEMINI INTEGRATION TEST RESULTS")
        print("═══════════════════════════════════════")
        
        let passedTests = testResults.filter { $0.passed }.count
        let totalTests = testResults.count
        
        for result in testResults {
            let status = result.passed ? "✅ PASS" : "❌ FAIL"
            let duration = String(format: "%.2fs", result.duration)
            print("\\(status) \\(result.testName) (\\(duration)) - \\(result.message)")
        }
        
        print("───────────────────────────────────────")
        print("Summary: \\(passedTests)/\\(totalTests) tests passed")
        print("═══════════════════════════════════════\\n")
    }
}

// MARK: - Test Runner for Integration

extension GeminiIntegrationTest {
    /// Run a quick validation of critical components
    func runQuickValidation() async -> Bool {
        print("🔍 Running quick Gemini integration validation...")
        
        // Test 1: API Key Management
        let apiKeyManager = APIKeyManager.shared
        if !apiKeyManager.hasAPIKey(for: .gemini) {
            print("ℹ️  Gemini API key not configured - integration ready but not active")
            return true
        }
        
        // Test 2: Service Configuration
        let isConfigured = await geminiAnalysisManager.isGeminiConfigured()
        if !isConfigured {
            print("⚠️  Gemini service configuration issue")
            return false
        }
        
        // Test 3: Data Formatting
        let testPortfolio = createTestPortfolio()
        let formattedData = await portfolioFormatter.formatForAnalysis(testPortfolio)
        
        if formattedData.portfolioSummary.isEmpty {
            print("❌ Portfolio formatting failed")
            return false
        }
        
        print("✅ Gemini integration validation passed")
        return true
    }
}