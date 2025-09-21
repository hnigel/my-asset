import Foundation

class NasdaqDividendService: DividendProvider {
    let providerName = "Nasdaq Dividends"
    let isAvailable = true
    
    private let baseURL = "https://api.nasdaq.com/api/quote"
    private let session = URLSession.shared
    
    func fetchDividendInfo(symbol: String) async throws -> DistributionInfo {
        guard let url = URL(string: "\(baseURL)/\(symbol)/dividends?assetclass=stocks") else {
            throw ProviderError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://www.nasdaq.com", forHTTPHeaderField: "Referer")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.timeoutInterval = 10.0
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProviderError.networkError(NSError(domain: "NoHTTPResponse", code: 0))
            }
            
            if httpResponse.statusCode != 200 {
                throw ProviderError.noData
            }
            
            let nasdaqResponse = try JSONDecoder().decode(NasdaqDividendResponse.self, from: data)
            
            guard nasdaqResponse.status.rCode == 200 else {
                throw ProviderError.noData
            }
            
            // Parse dividend data from Nasdaq format
            let dividendData = nasdaqResponse.data
            
            // Parse yield (e.g., "0.44%")
            let yieldString = dividendData.yield?.replacingOccurrences(of: "%", with: "") ?? "0"
            let yieldPercent = Double(yieldString) ?? 0.0
            
            // Parse annual dividend (e.g., "$1.04")
            let annualDividendString = dividendData.annualizedDividend?
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: ",", with: "") ?? "0"
            let annualDividend = Double(annualDividendString) ?? 0.0
            
            // Parse dates
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM/dd/yyyy"
            
            let exDate = dividendData.exDividendDate != nil ? dateFormatter.date(from: dividendData.exDividendDate!) : nil
            let payDate = dividendData.dividendPaymentDate != nil ? dateFormatter.date(from: dividendData.dividendPaymentDate!) : nil
            
            return DistributionInfo(
                symbol: symbol,
                distributionRate: annualDividend > 0 ? annualDividend : nil,
                distributionYieldPercent: yieldPercent > 0 ? yieldPercent : nil,
                distributionFrequency: estimateFrequencyFromSymbol(symbol), // Improved frequency estimation
                lastExDate: exDate,
                lastPaymentDate: payDate,
                fullName: nil // Will be populated from stock quote if needed
            )
            
        } catch let error as ProviderError {
            throw error
        } catch {
            throw ProviderError.networkError(error)
        }
    }
    
    // MARK: - Helper Methods
    
    private func estimateFrequencyFromSymbol(_ symbol: String) -> String {
        let symbolUpper = symbol.uppercased()
        
        // ETFs often have different distribution patterns
        if isETF(symbol: symbolUpper) {
            // Common monthly distribution ETFs
            if monthlyETFs.contains(symbolUpper) {
                return "Monthly"
            }
            // Most other ETFs are quarterly
            return "Quarterly"
        }
        
        // Most US stocks pay quarterly dividends
        return "Quarterly"
    }
    
    private func isETF(symbol: String) -> Bool {
        // Common ETF suffixes and patterns
        return symbol.hasSuffix("ETF") || 
               etfSymbols.contains(symbol) ||
               symbol.count <= 4 // Many ETFs have 3-4 character symbols
    }
    
    // Known monthly distribution ETFs
    private let monthlyETFs: Set<String> = [
        "QQQI", "QYLD", "RYLD", "XYLD", "NUSI", "JEPI", "JEPQ", "SCHD",
        "DIVO", "FDVV", "DIV", "NOBL", "SPHD", "HDV", "VYM", "DGRO"
    ]
    
    // Common ETF symbols (partial list)
    private let etfSymbols: Set<String> = [
        "SPY", "QQQ", "IWM", "VTI", "VOO", "IVV", "EFA", "EEM", "VEA", "VWO",
        "QQQI", "QYLD", "RYLD", "XYLD", "TLT", "GLD", "SLV", "USO", "XLF", "XLK"
    ]
}