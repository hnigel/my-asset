import Foundation

// MARK: - Health Report Structures
struct HistoricalDataHealthReport {
    let totalSymbols: Int
    let symbolsWithData: Int
    let averageDataPoints: Double
    let oldestDate: Date?
    let newestDate: Date?
    let dataGaps: [String]
    let inconsistencies: [String]
    
    init(totalSymbols: Int = 0, symbolsWithData: Int = 0, averageDataPoints: Double = 0.0, oldestDate: Date? = nil, newestDate: Date? = nil, dataGaps: [String] = [], inconsistencies: [String] = []) {
        self.totalSymbols = totalSymbols
        self.symbolsWithData = symbolsWithData
        self.averageDataPoints = averageDataPoints
        self.oldestDate = oldestDate
        self.newestDate = newestDate
        self.dataGaps = dataGaps
        self.inconsistencies = inconsistencies
    }
}

struct CacheStats {
    let hitRate: Double
    let missRate: Double
    let totalRequests: Int
    let totalHits: Int
    let totalMisses: Int
    let cacheSize: Int
    let memoryUsage: Int64
    
    init(hitRate: Double = 0.0, missRate: Double = 0.0, totalRequests: Int = 0, totalHits: Int = 0, totalMisses: Int = 0, cacheSize: Int = 0, memoryUsage: Int64 = 0) {
        self.hitRate = hitRate
        self.missRate = missRate
        self.totalRequests = totalRequests
        self.totalHits = totalHits
        self.totalMisses = totalMisses
        self.cacheSize = cacheSize
        self.memoryUsage = memoryUsage
    }
}

struct HistoricalDataStorageStats {
    let totalSize: Int64
    let numberOfFiles: Int
    let compressionRatio: Double
    let lastBackup: Date?
    let integrityCheckPassed: Bool
    
    init(totalSize: Int64 = 0, numberOfFiles: Int = 0, compressionRatio: Double = 1.0, lastBackup: Date? = nil, integrityCheckPassed: Bool = true) {
        self.totalSize = totalSize
        self.numberOfFiles = numberOfFiles
        self.compressionRatio = compressionRatio
        self.lastBackup = lastBackup
        self.integrityCheckPassed = integrityCheckPassed
    }
}

// MARK: - Price History Structure
struct PriceHistory {
    let symbol: String
    let prices: [HistoricalPrice]
    let lastUpdated: Date
    
    init(symbol: String, prices: [HistoricalPrice] = [], lastUpdated: Date = Date()) {
        self.symbol = symbol
        self.prices = prices
        self.lastUpdated = lastUpdated
    }
}