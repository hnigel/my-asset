# Gemini LLM Portfolio Analysis Integration Guide

## Overview

This guide documents the complete Google Gemini AI integration for portfolio analysis in the My Asset app. The integration provides AI-powered insights while maintaining strict privacy protection for financial data.

## Features

### Analysis Types
- **Comprehensive Analysis**: Complete portfolio overview with performance, risk, and recommendations
- **Performance Analysis**: Focus on returns, trends, and performance metrics
- **Risk Assessment**: Concentration risk, volatility analysis, and risk mitigation strategies
- **Diversification Analysis**: Sector allocation and diversification recommendations
- **Investment Recommendations**: Specific, actionable investment advice
- **Dividend Analysis**: Dividend yield, sustainability, and growth analysis

### Privacy Protection
- **Standard Privacy**: Anonymizes dollar amounts while keeping company names
- **Maximum Privacy**: Anonymizes all sensitive data including amounts and company names
- **No Anonymization**: Full data for users who prefer complete transparency

### Integration Points
- Seamless integration with existing portfolio export functionality
- Real-time progress indicators during AI analysis
- Error handling with user-friendly messages
- Combined text summary and AI analysis exports

## Setup Instructions

### 1. Obtain Google Gemini API Key
1. Visit [Google AI Studio](https://aistudio.google.com/)
2. Create a new project or select existing project
3. Generate a new API key for Gemini
4. Copy the API key for configuration

### 2. Configure API Key in App
1. Open app Settings (when implemented)
2. Navigate to AI Analysis section
3. Enter your Gemini API key
4. Test connection to verify setup

### 3. Using AI Analysis
1. Open any portfolio in the app
2. Tap "Export Portfolio" button
3. Select "AI Portfolio Analysis"
4. Choose analysis type and privacy settings
5. Tap "Analyze" to generate AI insights
6. Review, edit, and share the combined report

## Technical Implementation

### Core Architecture

```
GeminiService
├── API communication with Google Gemini
├── Request/response handling
├── Error management
└── Connection validation

PortfolioAnalysisFormatter
├── Data anonymization (3 privacy levels)
├── Portfolio data structuring
├── AI-optimized formatting
└── Privacy compliance

GeminiAnalysisManager
├── High-level analysis coordination
├── Prompt engineering
├── Multiple analysis types
└── Result formatting

AIAnalysisOptionsSheet
├── User interface for configuration
├── Analysis type selection
├── Privacy settings
└── Progress indicators
```

### Privacy Implementation

The integration implements three levels of privacy protection:

#### Level 1: Standard Privacy (Default)
- Converts exact dollar amounts to ranges (e.g., "$1,500" → "$1K-5K")
- Preserves company names and stock symbols
- Maintains analytical accuracy through percentages

#### Level 2: Maximum Privacy
- Anonymizes all dollar amounts to ranges
- Converts company names to generic identifiers
- Uses relative time periods instead of specific dates
- Preserves only essential analytical patterns

#### Level 3: No Anonymization
- Includes exact dollar amounts
- Shows complete company information
- Provides full transparency for users who prefer it

### Error Handling

Comprehensive error handling covers:
- Network connectivity issues
- API key validation problems
- Quota exceeded scenarios
- Content filtering by AI safety systems
- Timeout and retry mechanisms

## Usage Examples

### Basic Analysis
```swift
let options = GeminiAnalysisManager.AnalysisOptions(
    analysisType: .comprehensive,
    privacySettings: .default,
    includeTextSummary: true,
    customPrompt: nil
)

let result = try await geminiAnalysisManager.analyzePortfolio(portfolio, options: options)
```

### Batch Analysis
```swift
let analysisTypes: [GeminiAnalysisManager.AnalysisType] = [
    .performance,
    .risk,
    .diversification
]

let results = try await geminiAnalysisManager.generateBatchAnalysis(
    portfolio,
    analysisTypes: analysisTypes,
    privacySettings: .maxPrivacy
)
```

### Custom Analysis
```swift
let customPrompt = "Focus on ESG considerations and sustainable investing opportunities."

let options = GeminiAnalysisManager.AnalysisOptions(
    analysisType: .recommendations,
    privacySettings: .default,
    includeTextSummary: false,
    customPrompt: customPrompt
)
```

## Files Added/Modified

### New Files Created
- `GeminiService.swift` - Core Google Gemini API integration
- `PortfolioAnalysisFormatter.swift` - Privacy-protected data formatting
- `GeminiAnalysisManager.swift` - High-level analysis coordination
- `AIAnalysisOptionsSheet.swift` - User interface for AI analysis
- `GeminiIntegrationTest.swift` - Comprehensive test suite

### Modified Files
- `APIKeyManager.swift` - Added Gemini API provider support
- `ExportSheet.swift` - Integrated AI analysis options
- `IMPLEMENTATION_PLAN.md` - Complete implementation tracking

## Testing

### Automated Tests
The `GeminiIntegrationTest.swift` file provides comprehensive testing:
- API key management validation
- Service connection testing
- Data formatting verification
- Privacy protection validation
- End-to-end workflow testing

### Manual Testing
1. **API Configuration**: Verify API key setup and validation
2. **Analysis Generation**: Test all analysis types with different portfolios
3. **Privacy Protection**: Validate data anonymization at all levels
4. **Error Handling**: Test with invalid API keys and network issues
5. **UI Integration**: Verify seamless integration with existing workflows

## API Costs and Limits

### Google Gemini Pricing
- Free tier: 15 requests per minute, 1 million tokens per day
- Paid tier: Higher limits based on usage
- Text-only requests are cost-effective for portfolio analysis

### Cost Optimization
- Efficient prompt engineering to minimize token usage
- Caching of results to avoid duplicate requests
- Batch processing for multiple analysis types
- Rate limiting to respect API quotas

## Security Considerations

### Data Protection
- All financial data is anonymized before sending to AI
- API keys stored securely in iOS Keychain
- No persistent storage of AI analysis data
- User consent required for AI analysis

### Privacy Compliance
- GDPR-compliant data anonymization
- User control over privacy levels
- Clear disclosure of data usage
- Option to disable AI features completely

## Troubleshooting

### Common Issues

#### "Gemini API key not configured"
- Verify API key is entered correctly in settings
- Check that key has proper permissions
- Test with a simple request to validate key

#### "Network error"
- Check internet connectivity
- Verify firewall/proxy settings
- Ensure API endpoints are accessible

#### "Content filtered"
- Try different privacy settings
- Reduce portfolio size if very large
- Contact support if issue persists

#### "Quota exceeded"
- Wait for quota reset (daily/monthly)
- Consider upgrading to paid tier
- Implement request caching

### Debug Information
Enable debug logging in `GeminiService.swift` to troubleshoot:
- Request/response data
- Error details
- Network timing
- API response codes

## Future Enhancements

### Planned Features
- Historical trend analysis using past portfolio data
- Benchmark comparison with market indices
- Sector rotation recommendations
- Tax optimization suggestions
- ESG (Environmental, Social, Governance) analysis

### Integration Opportunities
- Real-time market data integration
- News sentiment analysis
- Economic indicator correlation
- Social media sentiment tracking

## Support

For technical support or questions about the Gemini integration:
1. Check this documentation first
2. Review the test suite for examples
3. Examine debug logs for error details
4. Verify API key configuration and permissions

## Disclaimer

The AI analysis provided by this integration is for informational purposes only and should not be considered as financial advice. Users should always consult with qualified financial advisors before making investment decisions. The accuracy of AI analysis depends on the quality of portfolio data and current market conditions.