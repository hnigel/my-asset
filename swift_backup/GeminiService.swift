import Foundation

/**
 * Google Gemini API Service
 * 
 * This service provides integration with Google's Gemini AI API for portfolio analysis.
 * It reads the API key from .env file or environment variables (in that order).
 * It follows the existing codebase patterns for async/await and error handling.
 */
@MainActor
class GeminiService: ObservableObject {
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let session = URLSession.shared
    
    // MARK: - Error Types
    
    enum GeminiError: LocalizedError, Equatable {
        case noAPIKey
        case invalidAPIKey
        case networkError(String)
        case invalidResponse
        case apiError(String)
        case quotaExceeded
        case contentFiltered
        case invalidRequest
        case serviceOverloaded
        case rateLimited
        
        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "Gemini API key not configured"
            case .invalidAPIKey:
                return "Invalid Gemini API key"
            case .networkError(let message):
                return "Network error: \(message)"
            case .invalidResponse:
                return "Invalid response from Gemini API"
            case .apiError(let message):
                return "Gemini API error: \(message)"
            case .quotaExceeded:
                return "Gemini API quota exceeded"
            case .contentFiltered:
                return "Content was filtered by Gemini safety settings"
            case .invalidRequest:
                return "Invalid request to Gemini API"
            case .serviceOverloaded:
                return "Gemini service is currently overloaded. Please try again in a few moments."
            case .rateLimited:
                return "Too many requests. Please wait before trying again."
            }
        }
    }
    
    // MARK: - Response Models
    
    struct GeminiResponse: Codable {
        let candidates: [Candidate]?
        let promptFeedback: PromptFeedback?
        
        struct Candidate: Codable {
            let content: Content?
            let finishReason: String?
            let safetyRatings: [SafetyRating]?
            
            struct Content: Codable {
                let parts: [Part]
                let role: String?
                
                struct Part: Codable {
                    let text: String?
                }
            }
            
            struct SafetyRating: Codable {
                let category: String
                let probability: String
            }
        }
        
        struct PromptFeedback: Codable {
            let blockReason: String?
            let safetyRatings: [Candidate.SafetyRating]?
        }
    }
    
    struct GeminiErrorResponse: Codable {
        let error: ErrorDetail
        
        struct ErrorDetail: Codable {
            let code: Int
            let message: String
            let status: String?
        }
    }
    
    // MARK: - Request Models
    
    struct GeminiRequest: Codable {
        let contents: [Content]
        let generationConfig: GenerationConfig?
        let safetySettings: [SafetySetting]?
        
        struct Content: Codable {
            let parts: [Part]
            let role: String?
            
            struct Part: Codable {
                let text: String
            }
        }
        
        struct GenerationConfig: Codable {
            let temperature: Double?
            let topK: Int?
            let topP: Double?
            let maxOutputTokens: Int?
            let stopSequences: [String]?
        }
        
        struct SafetySetting: Codable {
            let category: String
            let threshold: String
        }
    }
    
    // MARK: - Public Methods
    
    /// Analyze portfolio data using Gemini AI
    func analyzePortfolio(prompt: String, portfolioData: String) async throws -> String {
        guard let apiKey = getAPIKeyFromEnvironment() else {
            throw GeminiError.noAPIKey
        }
        
        let fullPrompt = constructAnalysisPrompt(userPrompt: prompt, portfolioData: portfolioData)
        return try await generateContentWithRetry(prompt: fullPrompt, apiKey: apiKey)
    }
    
    /// Generate content using Gemini with custom prompt
    func generateContent(prompt: String) async throws -> String {
        guard let apiKey = getAPIKeyFromEnvironment() else {
            throw GeminiError.noAPIKey
        }
        
        return try await generateContentWithRetry(prompt: prompt, apiKey: apiKey)
    }
    
    /// Validate if Gemini service is properly configured
    func validateConfiguration() async -> Bool {
        guard let apiKey = getAPIKeyFromEnvironment() else {
            return false
        }
        
        return await validateAPIKey(apiKey)
    }
    
    /// Test connection with a simple request
    func testConnection() async throws -> Bool {
        let testPrompt = "Hello, please respond with 'API connection successful' if you can read this."
        let response = try await generateContent(prompt: testPrompt)
        return response.localizedCaseInsensitiveContains("successful")
    }
    
    // MARK: - Private Methods
    
    /// Get API key from .env file or environment variables
    private func getAPIKeyFromEnvironment() -> String? {
        print("🔑 [GeminiService] Attempting to get API key...")
        
        // First try to read from .env file
        if let apiKey = readAPIKeyFromEnvFile() {
            print("✅ [GeminiService] API key found in .env file (length: \(apiKey.count))")
            return apiKey
        }
        
        // Fallback to environment variables
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
            print("✅ [GeminiService] API key found in environment variables (length: \(envKey.count))")
            return envKey
        }
        
        print("❌ [GeminiService] No API key found in .env file or environment variables")
        return nil
    }
    
    /// Read API key from .env file
    private func readAPIKeyFromEnvFile() -> String? {
        let envPath = "/Users/hnigel/coding/my asset/.env"
        
        guard let envContent = try? String(contentsOfFile: envPath, encoding: .utf8) else {
            return nil
        }
        
        let lines = envContent.components(separatedBy: .newlines)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.hasPrefix("GEMINI_API_KEY=") {
                let keyValue = trimmedLine.replacingOccurrences(of: "GEMINI_API_KEY=", with: "")
                return keyValue.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return nil
    }
    
    /// Validate API key by making a test request
    private func validateAPIKey(_ key: String) async -> Bool {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(key)") else {
            return false
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            return httpResponse.statusCode == 200
            
        } catch {
            return false
        }
    }
    
    /// Generate content with retry mechanism for handling overloaded service
    private func generateContentWithRetry(prompt: String, apiKey: String, maxRetries: Int = 3) async throws -> String {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                print("🔄 [GeminiService] Attempt \(attempt)/\(maxRetries)")
                return try await generateContent(prompt: prompt, apiKey: apiKey)
                
            } catch let error as GeminiError where error == .serviceOverloaded || error == .rateLimited {
                lastError = error
                let errorType = error == .serviceOverloaded ? "Service overloaded" : "Rate limited"
                print("⏳ [GeminiService] \(errorType). Waiting before retry...")
                
                if attempt < maxRetries {
                    let delay = Double(attempt * 2) // Exponential backoff: 2s, 4s, 6s
                    print("⏳ [GeminiService] Waiting \(delay) seconds before retry \(attempt + 1)/\(maxRetries)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                
            } catch {
                // For other errors, don't retry
                print("❌ [GeminiService] Non-retryable error: \(error.localizedDescription)")
                throw error
            }
        }
        
        print("❌ [GeminiService] All retry attempts failed")
        throw lastError ?? GeminiError.serviceOverloaded
    }
    
    private func generateContent(prompt: String, apiKey: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/models/gemini-1.5-flash:generateContent?key=\(apiKey)") else {
            throw GeminiError.invalidRequest
        }
        
        let request = createRequest(url: url, prompt: prompt)
        
        do {
            // Log request details
            print("🔄 [GeminiService] Making request to: \(url.absoluteString)")
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [GeminiService] Invalid HTTP response")
                throw GeminiError.invalidResponse
            }
            
            // Log response details
            print("📊 [GeminiService] HTTP Status: \(httpResponse.statusCode)")
            print("📊 [GeminiService] Response Headers: \(httpResponse.allHeaderFields)")
            
            // Handle different HTTP status codes
            switch httpResponse.statusCode {
            case 200:
                print("✅ [GeminiService] Success response received")
                return try parseSuccessResponse(data)
            case 400:
                print("❌ [GeminiService] Bad Request (400)")
                let errorMessage = try parseErrorResponse(data)
                print("❌ [GeminiService] Error details: \(errorMessage)")
                throw GeminiError.invalidRequest
            case 403:
                print("❌ [GeminiService] Forbidden (403) - Invalid API Key")
                throw GeminiError.invalidAPIKey
            case 429:
                print("❌ [GeminiService] Rate Limited (429)")
                throw GeminiError.rateLimited
            case 503:
                print("❌ [GeminiService] Service Unavailable (503) - Server Overloaded")
                throw GeminiError.serviceOverloaded
            case 529:
                print("❌ [GeminiService] Service Overloaded (529)")
                throw GeminiError.serviceOverloaded
            default:
                let errorMessage = try parseErrorResponse(data)
                print("❌ [GeminiService] Unexpected status code \(httpResponse.statusCode): \(errorMessage)")
                
                // Check if error message contains "overloaded"
                if errorMessage.lowercased().contains("overloaded") {
                    throw GeminiError.serviceOverloaded
                }
                
                throw GeminiError.apiError(errorMessage)
            }
            
        } catch let error as GeminiError {
            print("❌ [GeminiService] GeminiError: \(error.localizedDescription)")
            throw error
        } catch {
            print("❌ [GeminiService] Network error: \(error.localizedDescription)")
            throw GeminiError.networkError(error.localizedDescription)
        }
    }
    
    private func createRequest(url: URL, prompt: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = GeminiRequest(
            contents: [
                GeminiRequest.Content(
                    parts: [GeminiRequest.Content.Part(text: prompt)],
                    role: "user"
                )
            ],
            generationConfig: GeminiRequest.GenerationConfig(
                temperature: 0.7,
                topK: 40,
                topP: 0.95,
                maxOutputTokens: 2048,
                stopSequences: nil
            ),
            safetySettings: createSafetySettings()
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            print("Error encoding request body: \(error)")
        }
        
        return request
    }
    
    private func createSafetySettings() -> [GeminiRequest.SafetySetting] {
        return [
            GeminiRequest.SafetySetting(category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_MEDIUM_AND_ABOVE"),
            GeminiRequest.SafetySetting(category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_MEDIUM_AND_ABOVE"),
            GeminiRequest.SafetySetting(category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_MEDIUM_AND_ABOVE"),
            GeminiRequest.SafetySetting(category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE")
        ]
    }
    
    private func parseSuccessResponse(_ data: Data) throws -> String {
        let decoder = JSONDecoder()
        
        do {
            let response = try decoder.decode(GeminiResponse.self, from: data)
            
            // Check for content filtering
            if let promptFeedback = response.promptFeedback,
               promptFeedback.blockReason != nil {
                throw GeminiError.contentFiltered
            }
            
            // Extract text from the first candidate
            guard let candidate = response.candidates?.first,
                  let content = candidate.content,
                  let part = content.parts.first,
                  let text = part.text else {
                throw GeminiError.invalidResponse
            }
            
            // Check if content was filtered
            if candidate.finishReason == "SAFETY" {
                throw GeminiError.contentFiltered
            }
            
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
            
        } catch let decodingError as DecodingError {
            print("Decoding error: \(decodingError)")
            throw GeminiError.invalidResponse
        }
    }
    
    private func parseErrorResponse(_ data: Data) throws -> String {
        let decoder = JSONDecoder()
        
        do {
            let errorResponse = try decoder.decode(GeminiErrorResponse.self, from: data)
            return errorResponse.error.message
        } catch {
            // If we can't parse the error response, return a generic message
            if let dataString = String(data: data, encoding: .utf8) {
                return "API error: \(dataString)"
            }
            return "Unknown API error"
        }
    }
    
    private func constructAnalysisPrompt(userPrompt: String, portfolioData: String) -> String {
        return """
        You are a professional financial advisor and portfolio analyst. Please analyze the following portfolio data and provide insights based on the user's request.
        
        User Request: \(userPrompt)
        
        Portfolio Data:
        \(portfolioData)
        
        Please provide a comprehensive analysis that includes:
        1. Overall portfolio assessment
        2. Performance analysis
        3. Risk evaluation
        4. Diversification assessment
        5. Specific recommendations
        
        Format your response in a clear, professional manner suitable for sharing or saving. Use bullet points and sections where appropriate for readability.
        
        Note: This analysis is for informational purposes only and should not be considered as financial advice. Always consult with a qualified financial advisor before making investment decisions.
        """
    }
}

// MARK: - Extensions for Testing

extension GeminiService {
    /// Internal method for testing purposes
    func testAPIKeyValidation(apiKey: String) async -> Bool {
        return await validateAPIKey(apiKey)
    }
}