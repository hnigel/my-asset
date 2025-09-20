import Foundation
import CoreData
import SwiftUI

/**
 * Gemini Analysis Manager
 * 
 * This manager integrates with the existing TextExportManager to provide AI-powered
 * portfolio analysis using Google Gemini. It handles prompt engineering, response
 * parsing, and provides different analysis types.
 */
@MainActor
class GeminiAnalysisManager: ObservableObject {
    private let geminiService = GeminiService()
    private let portfolioFormatter = PortfolioAnalysisFormatter()
    private let textExportManager = TextExportManager()
    
    // MARK: - Published Properties
    
    @Published var isAnalyzing = false
    @Published var analysisProgress: String = ""
    @Published var lastError: Error?
    
    // MARK: - Analysis Types
    
    enum AnalysisType: String, CaseIterable {
        case comprehensive = "Comprehensive Portfolio Analysis"
        case performance = "Performance Analysis"
        case risk = "Risk Assessment"
        case diversification = "Diversification Analysis"
        case recommendations = "Investment Recommendations"
        case dividend = "Dividend Analysis"
        
        var prompt: String {
            switch self {
            case .comprehensive:
                return "Provide a comprehensive analysis covering all aspects of this portfolio including performance, risk, diversification, and actionable recommendations."
            case .performance:
                return "Focus on analyzing the performance metrics, returns, and how this portfolio has performed relative to market benchmarks."
            case .risk:
                return "Analyze the risk profile of this portfolio including concentration risk, volatility, and provide risk management suggestions."
            case .diversification:
                return "Evaluate the diversification of this portfolio across sectors, asset classes, and provide recommendations for improving diversification."
            case .recommendations:
                return "Provide specific, actionable investment recommendations based on this portfolio's current composition and performance."
            case .dividend:
                return "Focus on analyzing the dividend aspects of this portfolio including yield, sustainability, and dividend growth potential."
            }
        }
        
        var icon: String {
            switch self {
            case .comprehensive:
                return "chart.bar.doc.horizontal"
            case .performance:
                return "chart.line.uptrend.xyaxis"
            case .risk:
                return "exclamationmark.shield"
            case .diversification:
                return "chart.pie"
            case .recommendations:
                return "lightbulb"
            case .dividend:
                return "dollarsign.circle"
            }
        }
    }
    
    // MARK: - Analysis Result Models
    
    struct AnalysisResult {
        let analysisType: AnalysisType
        let portfolioSummary: String
        let aiAnalysis: String
        let combinedReport: String
        let timestamp: Date
        let privacySettings: PortfolioAnalysisFormatter.PrivacySettings
        
        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: timestamp)
        }
    }
    
    struct AnalysisOptions {
        let analysisType: AnalysisType
        let privacySettings: PortfolioAnalysisFormatter.PrivacySettings
        let includeTextSummary: Bool
        let customPrompt: String?
        
        static let `default` = AnalysisOptions(
            analysisType: .comprehensive,
            privacySettings: .default,
            includeTextSummary: true,
            customPrompt: nil
        )
    }
    
    // MARK: - Public Methods
    
    /// Generate AI analysis for a portfolio
    func analyzePortfolio(
        _ portfolio: Portfolio,
        options: AnalysisOptions = .default
    ) async throws -> AnalysisResult {
        
        print("🤖 [GeminiAnalysisManager] Starting portfolio analysis...")
        print("🤖 [GeminiAnalysisManager] Portfolio: \(portfolio.name ?? "Unknown")")
        print("🤖 [GeminiAnalysisManager] Analysis type: \(options.analysisType.rawValue)")
        
        print("🔐 [GeminiAnalysisManager] Validating Gemini configuration...")
        guard await geminiService.validateConfiguration() else {
            print("❌ [GeminiAnalysisManager] Gemini validation failed!")
            throw GeminiServiceError.noAPIKey
        }
        print("✅ [GeminiAnalysisManager] Gemini configuration valid")
        
        isAnalyzing = true
        lastError = nil
        analysisProgress = "Preparing portfolio data..."
        
        defer {
            isAnalyzing = false
            analysisProgress = ""
        }
        
        do {
            // Step 1: Generate text summary
            print("📊 [GeminiAnalysisManager] Step 1: Generating portfolio summary...")
            analysisProgress = "Generating portfolio summary..."
            let portfolioSummary = await textExportManager.generatePortfolioTextSummary(portfolio)
            print("✅ [GeminiAnalysisManager] Portfolio summary generated (length: \(portfolioSummary.count) chars)")
            
            // Step 2: Format data for AI analysis
            print("📝 [GeminiAnalysisManager] Step 2: Formatting data for AI analysis...")
            analysisProgress = "Formatting data for AI analysis..."
            let analysisPrompt = await createAnalysisPrompt(
                portfolio: portfolio,
                analysisType: options.analysisType,
                privacySettings: options.privacySettings,
                customPrompt: options.customPrompt
            )
            print("✅ [GeminiAnalysisManager] Analysis prompt prepared (length: \(analysisPrompt.count) chars)")
            
            // Step 3: Get AI analysis
            print("🧠 [GeminiAnalysisManager] Step 3: Requesting AI analysis from Gemini...")
            analysisProgress = "Requesting AI analysis..."
            let aiAnalysis = try await geminiService.generateContent(prompt: analysisPrompt)
            print("✅ [GeminiAnalysisManager] AI analysis received (length: \(aiAnalysis.count) chars)")
            
            // Step 4: Combine results
            analysisProgress = "Finalizing analysis..."
            let combinedReport = createCombinedReport(
                portfolioSummary: portfolioSummary,
                aiAnalysis: aiAnalysis,
                analysisType: options.analysisType,
                includeTextSummary: options.includeTextSummary
            )
            
            return AnalysisResult(
                analysisType: options.analysisType,
                portfolioSummary: portfolioSummary,
                aiAnalysis: aiAnalysis,
                combinedReport: combinedReport,
                timestamp: Date(),
                privacySettings: options.privacySettings
            )
            
        } catch {
            lastError = error
            throw error
        }
    }
    
    /// Generate multiple analysis types in batch
    func generateBatchAnalysis(
        _ portfolio: Portfolio,
        analysisTypes: [AnalysisType],
        privacySettings: PortfolioAnalysisFormatter.PrivacySettings = .default
    ) async throws -> [AnalysisResult] {
        
        var results: [AnalysisResult] = []
        
        for (index, analysisType) in analysisTypes.enumerated() {
            analysisProgress = "Analyzing: \(analysisType.rawValue) (\(index + 1)/\(analysisTypes.count))"
            
            let options = AnalysisOptions(
                analysisType: analysisType,
                privacySettings: privacySettings,
                includeTextSummary: index == 0, // Only include text summary in first analysis
                customPrompt: nil
            )
            
            let result = try await analyzePortfolio(portfolio, options: options)
            results.append(result)
            
            // Add small delay between requests to be respectful to the API
            if index < analysisTypes.count - 1 {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
        
        return results
    }
    
    /// Test Gemini connection and configuration
    func testGeminiConnection() async throws -> Bool {
        isAnalyzing = true
        analysisProgress = "Testing Gemini connection..."
        
        defer {
            isAnalyzing = false
            analysisProgress = ""
        }
        
        return try await geminiService.testConnection()
    }
    
    /// Check if Gemini service is properly configured
    func isGeminiConfigured() async -> Bool {
        return await geminiService.validateConfiguration()
    }
    
    // MARK: - Private Methods
    
    private func createAnalysisPrompt(
        portfolio: Portfolio,
        analysisType: AnalysisType,
        privacySettings: PortfolioAnalysisFormatter.PrivacySettings,
        customPrompt: String?
    ) async -> String {
        
        let basePrompt = customPrompt ?? analysisType.prompt
        
        let formattedData = await portfolioFormatter.formatForAnalysis(
            portfolio,
            format: .structured,
            privacySettings: privacySettings
        )
        
        return constructAdvancedPrompt(
            analysisType: analysisType,
            basePrompt: basePrompt,
            formattedData: formattedData
        )
    }
    
    private func constructAdvancedPrompt(
        analysisType: AnalysisType,
        basePrompt: String,
        formattedData: PortfolioAnalysisFormatter.FormattedPortfolioData
    ) -> String {
        
        let rolePrompt = """
        You are a senior financial advisor and portfolio analyst with expertise in investment strategy, risk management, and portfolio optimization. You have access to a client's portfolio data and have been asked to provide professional analysis.
        """
        
        let contextPrompt = """
        ANALYSIS CONTEXT:
        - Analysis Type: \(analysisType.rawValue)
        - Client Request: \(basePrompt)
        - Data Privacy: Portfolio data has been anonymized for privacy protection
        """
        
        let analysisGuidelines = getAnalysisGuidelines(for: analysisType)
        
        let outputFormat = """
        OUTPUT FORMAT REQUIREMENTS:
        1. Start with an executive summary (2-3 key insights)
        2. Provide detailed analysis organized in clear sections
        3. Include specific, actionable recommendations
        4. End with important disclaimers about investment risk
        5. Use professional but accessible language
        6. Format with clear headings and bullet points for readability
        """
        
        return """
        \(rolePrompt)
        
        \(contextPrompt)
        
        \(formattedData.privacyNotice)
        
        PORTFOLIO DATA:
        \(formattedData.portfolioSummary)
        
        \(formattedData.holdingsData)
        
        \(formattedData.performanceData)
        
        \(formattedData.riskMetrics)
        
        ANALYSIS GUIDELINES:
        \(analysisGuidelines)
        
        \(outputFormat)
        
        Please provide your professional analysis now.
        """
    }
    
    private func getAnalysisGuidelines(for analysisType: AnalysisType) -> String {
        switch analysisType {
        case .comprehensive:
            return """
            - Evaluate all aspects: performance, risk, diversification, costs
            - Compare to market benchmarks where possible
            - Identify strengths and weaknesses
            - Provide balanced, holistic recommendations
            - Consider both short-term and long-term perspectives
            """
            
        case .performance:
            return """
            - Analyze returns and performance trends
            - Evaluate win/loss ratios and consistency
            - Compare individual holdings performance
            - Identify top performers and underperformers
            - Suggest performance improvement strategies
            """
            
        case .risk:
            return """
            - Assess concentration risk and position sizing
            - Evaluate portfolio volatility and downside risk
            - Analyze correlation between holdings
            - Identify risk factors and potential vulnerabilities
            - Recommend risk mitigation strategies
            """
            
        case .diversification:
            return """
            - Evaluate sector and geographic diversification
            - Analyze correlation between holdings
            - Identify concentration areas and gaps
            - Recommend diversification improvements
            - Consider alternative asset classes if appropriate
            """
            
        case .recommendations:
            return """
            - Provide specific, actionable investment advice
            - Prioritize recommendations by impact and feasibility
            - Consider tax implications where possible
            - Suggest position sizing and timing considerations
            - Include both buy and sell recommendations
            """
            
        case .dividend:
            return """
            - Analyze dividend yield and sustainability
            - Evaluate dividend growth trends
            - Assess payout ratios and coverage
            - Compare dividend strategy to income needs
            - Recommend dividend-focused optimizations
            """
        }
    }
    
    private func createCombinedReport(
        portfolioSummary: String,
        aiAnalysis: String,
        analysisType: AnalysisType,
        includeTextSummary: Bool
    ) -> String {
        
        let header = createReportHeader(analysisType: analysisType)
        
        var report = header
        
        if includeTextSummary {
            report += "\n\n"
            report += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            report += "PORTFOLIO SUMMARY\n"
            report += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            report += portfolioSummary
        }
        
        report += "\n\n"
        report += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        report += "AI ANALYSIS - \(analysisType.rawValue.uppercased())\n"
        report += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        report += aiAnalysis
        
        report += "\n\n"
        report += createReportFooter()
        
        return report
    }
    
    private func createReportHeader(analysisType: AnalysisType) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        
        return """
        🤖 AI-POWERED PORTFOLIO ANALYSIS
        ═══════════════════════════════════════════════════════════
        Analysis Type: \(analysisType.rawValue)
        Generated: \(formatter.string(from: Date()))
        Powered by: Google Gemini AI
        
        This analysis combines traditional portfolio metrics with AI-powered 
        insights to provide comprehensive investment guidance.
        """
    }
    
    private func createReportFooter() -> String {
        return """
        ═══════════════════════════════════════════════════════════
        
        📊 ANALYSIS METHODOLOGY
        This analysis combines quantitative portfolio metrics with AI-powered 
        qualitative insights. The AI analysis is based on current portfolio 
        composition and general market knowledge.
        
        ⚠️  IMPORTANT DISCLAIMERS
        • This analysis is for informational purposes only
        • Past performance does not guarantee future results
        • Always consult with a qualified financial advisor
        • Consider your personal financial situation and risk tolerance
        • This is not personalized financial advice
        
        🔒 PRIVACY PROTECTION
        Portfolio data has been anonymized to protect sensitive information
        while preserving analytical value for AI processing.
        
        Generated by My Asset Portfolio App with Google Gemini AI
        """
    }
}

// MARK: - Error Types

enum GeminiServiceError: LocalizedError {
    case noAPIKey
    case configurationError
    case analysisTimeout
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Gemini API key is not configured. Please add your API key in settings."
        case .configurationError:
            return "Gemini service is not properly configured."
        case .analysisTimeout:
            return "Analysis request timed out. Please try again."
        }
    }
}

// MARK: - Extensions for UI Support

extension GeminiAnalysisManager {
    
    /// Get analysis type options for UI
    static var availableAnalysisTypes: [AnalysisType] {
        return AnalysisType.allCases
    }
    
    /// Get privacy setting options for UI
    static var privacyOptions: [PortfolioAnalysisFormatter.PrivacySettings] {
        return [
            .default,
            .maxPrivacy,
            PortfolioAnalysisFormatter.PrivacySettings(
                anonymizeAmounts: false,
                anonymizeCompanyNames: false,
                anonymizeDates: false,
                includePurchaseDates: true,
                includeExactQuantities: true
            )
        ]
    }
    
    /// Format analysis result for sharing
    func formatForSharing(_ result: AnalysisResult) -> String {
        return result.combinedReport
    }
    
    /// Get estimated analysis time
    func getEstimatedAnalysisTime(for types: [AnalysisType]) -> TimeInterval {
        // Estimate based on number of analysis types and API response time
        let baseTime: TimeInterval = 10 // Base time per analysis
        let delayTime: TimeInterval = 1 // Delay between requests
        
        return TimeInterval(types.count) * baseTime + TimeInterval(max(0, types.count - 1)) * delayTime
    }
}