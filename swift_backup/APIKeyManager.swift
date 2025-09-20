import Foundation

/**
 * Secure API Key Management
 * 
 * This class provides secure storage and retrieval of API keys using iOS Keychain.
 * In production, API keys should never be hardcoded in source code.
 */
class APIKeyManager {
    static let shared = APIKeyManager()
    
    private init() {}
    
    private let keychainService = "com.myasset.apikeys"
    
    enum APIProvider: String {
        case alphaVantage = "alphavantage_api_key"
        case finnhub = "finnhub_api_key"
        case eodhd = "eodhd_api_key"
        case gemini = "gemini_api_key"
    }
    
    // MARK: - Keychain Operations
    
    func setAPIKey(_ key: String, for provider: APIProvider) -> Bool {
        let data = Data(key.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: provider.rawValue,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func getAPIKey(for provider: APIProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else { return nil }
        guard let data = item as? Data else { return nil }
        
        return String(data: data, encoding: .utf8)
    }
    
    func removeAPIKey(for provider: APIProvider) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: provider.rawValue
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
    
    // MARK: - Convenience Methods
    
    func hasAPIKey(for provider: APIProvider) -> Bool {
        return getAPIKey(for: provider) != nil
    }
    
    func setupDefaultKeys() {
        // Set up default API keys for development/demo
        // In production, these would be set through user input or secure provisioning
        
        if !hasAPIKey(for: .alphaVantage) {
            // Using the provided key for development
            _ = setAPIKey("QCYXJ1BYPYXG8BUY", for: .alphaVantage)
        }
        
        if !hasAPIKey(for: .eodhd) {
            // Using the provided key for development
            _ = setAPIKey("68c2e2273ae499.81958135", for: .eodhd)
        }
        
        if !hasAPIKey(for: .finnhub) {
            // Using the provided key for development
            _ = setAPIKey("d31e7u9r01qsprr0ibvgd31e7u9r01qsprr0ic00", for: .finnhub)
        }
        
    }
    
    // MARK: - API Key Validation
    
    func validateAPIKey(_ key: String, for provider: APIProvider) async -> Bool {
        switch provider {
        case .alphaVantage:
            return await validateAlphaVantageKey(key)
        case .finnhub:
            return await validateFinnhubKey(key)
        case .eodhd:
            return await validateEODHDKey(key)
        case .gemini:
            return await validateGeminiKey(key)
        }
    }
    
    private func validateAlphaVantageKey(_ key: String) async -> Bool {
        guard let url = URL(string: "https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=AAPL&apikey=\(key)") else {
            return false
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json?["Global Quote"] != nil
            
        } catch {
            return false
        }
    }
    
    
    private func validateFinnhubKey(_ key: String) async -> Bool {
        guard let url = URL(string: "https://finnhub.io/api/v1/quote?symbol=AAPL&token=\(key)") else {
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
    
    private func validateEODHDKey(_ key: String) async -> Bool {
        // Test with a simple API call to validate the key
        guard let url = URL(string: "https://eodhistoricaldata.com/api/eod/AAPL.US?api_token=\(key)&fmt=json&period=d&limit=1") else {
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
    
    private func validateGeminiKey(_ key: String) async -> Bool {
        // Test with a simple API call to validate the Gemini API key
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
}