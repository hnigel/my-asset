import Foundation

/**
 * Historical Data Error Handling
 * 
 * Comprehensive error handling for historical stock data operations,
 * following the existing ProviderError pattern but specialized for
 * historical data specific scenarios.
 * 
 * Sendable-compliant for Swift 6.0 concurrency safety.
 */
enum HistoricalDataError: Error, LocalizedError, Sendable {
    case invalidURL
    case noData
    case decodingError(String)
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case networkError(Error)
    case invalidSymbol(String)
    case invalidDateRange(String)
    case providerUnavailable(String)
    case apiKeyMissing(String)
    case quotaExceeded(String)
    case dataQualityError(String)
    case cacheError(String)
    case persistenceError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for historical data request"
        case .noData:
            return "No historical data available for the requested period"
        case .decodingError(let details):
            return "Failed to parse historical data: \(details)"
        case .rateLimitExceeded(let retryAfter):
            if let retry = retryAfter {
                return "Rate limit exceeded. Please retry after \(Int(retry)) seconds."
            }
            return "Rate limit exceeded. Please try again later."
        case .networkError(let error):
            return "Network error while fetching historical data: \(error.localizedDescription)"
        case .invalidSymbol(let symbol):
            return "Invalid or unknown stock symbol: \(symbol)"
        case .invalidDateRange(let details):
            return "Invalid date range: \(details)"
        case .providerUnavailable(let provider):
            return "\(provider) is currently unavailable"
        case .apiKeyMissing(let provider):
            return "API key is required for \(provider) but not configured"
        case .quotaExceeded(let provider):
            return "\(provider) API quota exceeded for today"
        case .dataQualityError(let details):
            return "Data quality issue: \(details)"
        case .cacheError(let details):
            return "Cache operation failed: \(details)"
        case .persistenceError(let details):
            return "Failed to save historical data: \(details)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .invalidURL:
            return "The URL constructed for the API request was malformed"
        case .noData:
            return "The API returned an empty response or no data for the requested symbol and date range"
        case .decodingError:
            return "The API response format was unexpected or contained invalid data"
        case .rateLimitExceeded:
            return "Too many requests have been made to the API in a short time period"
        case .networkError:
            return "A network connectivity issue prevented the request from completing"
        case .invalidSymbol:
            return "The stock symbol provided does not exist or is not supported"
        case .invalidDateRange:
            return "The requested date range is invalid or not supported by the provider"
        case .providerUnavailable:
            return "The data provider service is temporarily unavailable"
        case .apiKeyMissing:
            return "An API key is required to access this service but has not been configured"
        case .quotaExceeded:
            return "The daily API request limit has been reached"
        case .dataQualityError:
            return "The returned data failed validation checks"
        case .cacheError:
            return "Failed to read from or write to the local cache"
        case .persistenceError:
            return "Failed to save data to the local database"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidURL:
            return "Please verify the stock symbol and try again"
        case .noData:
            return "Try a different date range or stock symbol"
        case .decodingError:
            return "This may be a temporary API issue. Please try again later"
        case .rateLimitExceeded(let retryAfter):
            if let retry = retryAfter {
                return "Wait \(Int(retry)) seconds before making another request"
            }
            return "Wait a few minutes before trying again"
        case .networkError:
            return "Check your internet connection and try again"
        case .invalidSymbol:
            return "Verify the stock symbol is correct (e.g., AAPL, GOOGL)"
        case .invalidDateRange:
            return "Ensure the start date is before the end date and within supported limits"
        case .providerUnavailable:
            return "Try again later or use a different data provider"
        case .apiKeyMissing:
            return "Configure an API key in the app settings"
        case .quotaExceeded:
            return "Wait until tomorrow or upgrade your API plan"
        case .dataQualityError:
            return "Try a different date range or report this issue"
        case .cacheError:
            return "Clear the app cache or restart the application"
        case .persistenceError:
            return "Free up storage space or restart the application"
        }
    }
}

// MARK: - Error Category and Severity

extension HistoricalDataError {
    enum Category: Sendable {
        case network
        case apiLimit
        case dataIssue
        case configuration
        case storage
    }
    
    enum Severity: Sendable {
        case low      // User can continue, functionality degraded
        case medium   // User action required but not critical
        case high     // Blocks core functionality
        case critical // App-breaking issue
    }
    
    var category: Category {
        switch self {
        case .invalidURL, .networkError:
            return .network
        case .rateLimitExceeded, .quotaExceeded:
            return .apiLimit
        case .noData, .decodingError, .invalidSymbol, .invalidDateRange, .dataQualityError:
            return .dataIssue
        case .providerUnavailable, .apiKeyMissing:
            return .configuration
        case .cacheError, .persistenceError:
            return .storage
        }
    }
    
    var severity: Severity {
        switch self {
        case .cacheError:
            return .low
        case .rateLimitExceeded, .invalidDateRange, .dataQualityError:
            return .medium
        case .noData, .invalidSymbol, .providerUnavailable, .quotaExceeded:
            return .medium
        case .networkError, .decodingError, .persistenceError:
            return .high
        case .invalidURL, .apiKeyMissing:
            return .critical
        }
    }
}

// MARK: - Error Recovery Strategies

extension HistoricalDataError {
    enum RecoveryStrategy: Sendable {
        case retry(after: TimeInterval)
        case fallbackProvider
        case useCache
        case userConfiguration
        case none
    }
    
    var recoveryStrategy: RecoveryStrategy {
        switch self {
        case .rateLimitExceeded(let retryAfter):
            return .retry(after: retryAfter ?? 60.0)
        case .networkError:
            return .retry(after: 5.0)
        case .providerUnavailable:
            return .fallbackProvider
        case .noData, .invalidSymbol:
            return .useCache
        case .apiKeyMissing:
            return .userConfiguration
        case .quotaExceeded:
            return .fallbackProvider
        default:
            return .none
        }
    }
}

// MARK: - Conversion from ProviderError

extension HistoricalDataError {
    /// Converts from existing ProviderError to HistoricalDataError
    static func from(_ providerError: ProviderError, provider: String = "Unknown") -> HistoricalDataError {
        switch providerError {
        case .invalidURL:
            return .invalidURL
        case .noData:
            return .noData
        case .decodingError(let details):
            return .decodingError(details)
        case .rateLimitExceeded:
            return .rateLimitExceeded(retryAfter: nil)
        case .networkError(let error):
            return .networkError(error)
        case .invalidSymbol(let symbol):
            return .invalidSymbol(symbol)
        case .providerUnavailable:
            return .providerUnavailable(provider)
        case .apiKeyMissing:
            return .apiKeyMissing(provider)
        }
    }
}

// MARK: - Logging Support

extension HistoricalDataError {
    /// Creates a detailed log message for debugging
    var logMessage: String {
        let categoryStr = String(describing: category)
        let severityStr = String(describing: severity)
        return "[\(severityStr.uppercased())] \(categoryStr): \(localizedDescription)"
    }
    
    /// Creates a structured dictionary for logging
    var logDictionary: [String: Any] {
        return [
            "error_type": "HistoricalDataError",
            "category": String(describing: category),
            "severity": String(describing: severity),
            "description": localizedDescription,
            "failure_reason": failureReason ?? "Unknown",
            "recovery_suggestion": recoverySuggestion ?? "None",
            "recovery_strategy": String(describing: recoveryStrategy),
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
    }
}