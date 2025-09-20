import Foundation

/**
 * Historical Data Cache Manager
 * 
 * Implements efficient memory and disk caching for historical stock data
 * with automatic expiration, size management, and thread safety.
 */
final class HistoricalDataCacheManager: HistoricalDataCache, @unchecked Sendable {
    
    // MARK: - Cache Entry Structure
    
    private struct CacheEntry {
        let symbol: String
        let startDate: Date
        let endDate: Date
        let prices: [HistoricalPrice]
        let timestamp: Date
        let accessCount: Int
        
        var isExpired: Bool {
            let expirationTime: TimeInterval = 300 // 5 minutes for historical data
            return Date().timeIntervalSince(timestamp) > expirationTime
        }
        
        var isStale: Bool {
            let staleTime: TimeInterval = 3600 // 1 hour
            return Date().timeIntervalSince(timestamp) > staleTime
        }
        
        var sizeBytes: Int64 {
            // Rough estimate of memory usage
            return Int64(prices.count * 200) // Approximate bytes per HistoricalPrice
        }
    }
    
    // MARK: - Properties
    
    private let configuration: HistoricalDataServiceConfiguration
    private var memoryCache: [String: CacheEntry] = [:]
    private let cacheQueue = DispatchQueue(label: "historical-cache", attributes: .concurrent)
    private let fileManager = FileManager.default
    private let diskCacheURL: URL
    
    // Statistics
    private var hitCount: Int64 = 0
    private var missCount: Int64 = 0
    private var currentSizeBytes: Int64 = 0
    
    // MARK: - Initialization
    
    init(configuration: HistoricalDataServiceConfiguration = .default) {
        self.configuration = configuration
        
        // Set up disk cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.diskCacheURL = documentsPath.appendingPathComponent("HistoricalDataCache")
        
        createCacheDirectory()
        
        if configuration.enableLogging {
            print("[HistoricalDataCache] Initialized with disk cache at: \(diskCacheURL.path)")
        }
        
        // Start background cleanup task
        startCleanupTask()
    }
    
    private func createCacheDirectory() {
        do {
            try fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        } catch {
            print("[HistoricalDataCache] Error creating cache directory: \(error)")
        }
    }
    
    // MARK: - Cache Operations
    
    func get(symbol: String, startDate: Date, endDate: Date) async -> [HistoricalPrice]? {
        let cacheKey = generateCacheKey(symbol: symbol, startDate: startDate, endDate: endDate)
        
        // Check memory cache first
        if let entry = await getFromMemoryCache(key: cacheKey) {
            if !entry.isExpired {
                await updateHitCount()
                
                if configuration.enableLogging && configuration.logLevel == .debug {
                    print("[HistoricalDataCache] Memory cache hit for \(symbol)")
                }
                
                return entry.prices
            } else {
                // Remove expired entry
                await removeFromMemoryCache(key: cacheKey)
            }
        }
        
        // Check disk cache if enabled
        if configuration.enableDiskCache {
            if let prices = await getFromDiskCache(key: cacheKey) {
                // Store back in memory cache
                let entry = CacheEntry(
                    symbol: symbol,
                    startDate: startDate,
                    endDate: endDate,
                    prices: prices,
                    timestamp: Date(),
                    accessCount: 1
                )
                await setInMemoryCache(key: cacheKey, entry: entry)
                await updateHitCount()
                
                if configuration.enableLogging && configuration.logLevel == .debug {
                    print("[HistoricalDataCache] Disk cache hit for \(symbol)")
                }
                
                return prices
            }
        }
        
        await updateMissCount()
        return nil
    }
    
    func set(symbol: String, prices: [HistoricalPrice], startDate: Date, endDate: Date) async {
        let cacheKey = generateCacheKey(symbol: symbol, startDate: startDate, endDate: endDate)
        
        let entry = CacheEntry(
            symbol: symbol,
            startDate: startDate,
            endDate: endDate,
            prices: prices,
            timestamp: Date(),
            accessCount: 0
        )
        
        // Store in memory cache
        await setInMemoryCache(key: cacheKey, entry: entry)
        
        // Store in disk cache if enabled
        if configuration.enableDiskCache {
            await saveToDiskCache(key: cacheKey, prices: prices)
        }
        
        if configuration.enableLogging && configuration.logLevel == .debug {
            print("[HistoricalDataCache] Cached \(prices.count) prices for \(symbol)")
        }
    }
    
    func clear(symbol: String?) async {
        if let symbol = symbol {
            // Clear specific symbol
            let keysToRemove = await getMemoryCacheKeys().filter { $0.contains(symbol) }
            for key in keysToRemove {
                await removeFromMemoryCache(key: key)
                if configuration.enableDiskCache {
                    await removeFromDiskCache(key: key)
                }
            }
        } else {
            // Clear all cache
            await clearMemoryCache()
            if configuration.enableDiskCache {
                await clearDiskCache()
            }
        }
    }
    
    func clearExpired() async {
        let expiredKeys = await getExpiredCacheKeys()
        
        for key in expiredKeys {
            await removeFromMemoryCache(key: key)
            if configuration.enableDiskCache {
                await removeFromDiskCache(key: key)
            }
        }
        
        if configuration.enableLogging && !expiredKeys.isEmpty {
            print("[HistoricalDataCache] Removed \(expiredKeys.count) expired entries")
        }
    }
    
    // MARK: - Stale Data Access
    
    func getStale(symbol: String) async -> [HistoricalPrice]? {
        // Find any cached data for the symbol, even if stale
        let allKeys = await getMemoryCacheKeys()
        let symbolKeys = allKeys.filter { $0.contains(symbol) }
        
        var mostRecentEntry: CacheEntry?
        
        for key in symbolKeys {
            if let entry = await getFromMemoryCache(key: key) {
                if mostRecentEntry == nil || entry.timestamp > mostRecentEntry!.timestamp {
                    mostRecentEntry = entry
                }
            }
        }
        
        if let entry = mostRecentEntry {
            if configuration.enableLogging {
                print("[HistoricalDataCache] Using stale data for \(symbol) (age: \(Date().timeIntervalSince(entry.timestamp))s)")
            }
            return entry.prices
        }
        
        return nil
    }
    
    // MARK: - Memory Cache Operations
    
    private func getFromMemoryCache(key: String) async -> CacheEntry? {
        return await withCheckedContinuation { continuation in
            cacheQueue.async {
                continuation.resume(returning: self.memoryCache[key])
            }
        }
    }
    
    private func setInMemoryCache(key: String, entry: CacheEntry) async {
        await withCheckedContinuation { continuation in
            cacheQueue.async(flags: .barrier) {
                // Check if we need to evict entries to stay within size limit
                self.evictIfNeeded()
                
                self.memoryCache[key] = entry
                self.currentSizeBytes += entry.sizeBytes
                continuation.resume()
            }
        }
    }
    
    private func removeFromMemoryCache(key: String) async {
        await withCheckedContinuation { continuation in
            cacheQueue.async(flags: .barrier) {
                if let entry = self.memoryCache[key] {
                    self.currentSizeBytes -= entry.sizeBytes
                    self.memoryCache.removeValue(forKey: key)
                }
                continuation.resume()
            }
        }
    }
    
    private func clearMemoryCache() async {
        await withCheckedContinuation { continuation in
            cacheQueue.async(flags: .barrier) {
                self.memoryCache.removeAll()
                self.currentSizeBytes = 0
                continuation.resume()
            }
        }
    }
    
    private func getMemoryCacheKeys() async -> [String] {
        return await withCheckedContinuation { continuation in
            cacheQueue.async {
                continuation.resume(returning: Array(self.memoryCache.keys))
            }
        }
    }
    
    private func getExpiredCacheKeys() async -> [String] {
        return await withCheckedContinuation { continuation in
            cacheQueue.async {
                let expiredKeys = self.memoryCache.compactMap { (key, entry) in
                    entry.isExpired ? key : nil
                }
                continuation.resume(returning: expiredKeys)
            }
        }
    }
    
    // MARK: - Cache Eviction
    
    private func evictIfNeeded() {
        let maxSizeBytes = Int64(configuration.maxCacheSize) * 1024 * 1024 // Convert MB to bytes
        
        while currentSizeBytes > maxSizeBytes && !memoryCache.isEmpty {
            // Find least recently used entry (simplified LRU)
            let lruKey = memoryCache.min { a, b in
                a.value.accessCount < b.value.accessCount || 
                (a.value.accessCount == b.value.accessCount && a.value.timestamp < b.value.timestamp)
            }?.key
            
            if let key = lruKey, let entry = memoryCache[key] {
                currentSizeBytes -= entry.sizeBytes
                memoryCache.removeValue(forKey: key)
                
                if configuration.enableLogging && configuration.logLevel == .debug {
                    print("[HistoricalDataCache] Evicted cache entry: \(key)")
                }
            } else {
                break
            }
        }
    }
    
    // MARK: - Disk Cache Operations
    
    private func saveToDiskCache(key: String, prices: [HistoricalPrice]) async {
        await withCheckedContinuation { continuation in
            Task.detached {
                do {
                    let data = try JSONEncoder().encode(prices)
                    let fileURL = self.diskCacheURL.appendingPathComponent("\(key).json")
                    try data.write(to: fileURL)
                } catch {
                    if self.configuration.enableLogging {
                        print("[HistoricalDataCache] Error saving to disk cache: \(error)")
                    }
                }
                continuation.resume()
            }
        }
    }
    
    private func getFromDiskCache(key: String) async -> [HistoricalPrice]? {
        return await withCheckedContinuation { continuation in
            Task.detached {
                do {
                    let fileURL = self.diskCacheURL.appendingPathComponent("\(key).json")
                    let data = try Data(contentsOf: fileURL)
                    let prices = try JSONDecoder().decode([HistoricalPrice].self, from: data)
                    
                    // Check if file is still valid (not too old)
                    let fileAttributes = try self.fileManager.attributesOfItem(atPath: fileURL.path)
                    if let modificationDate = fileAttributes[.modificationDate] as? Date {
                        let ageInSeconds = Date().timeIntervalSince(modificationDate)
                        if ageInSeconds < 3600 { // 1 hour disk cache validity
                            continuation.resume(returning: prices)
                            return
                        }
                    }
                } catch {
                    // File doesn't exist or is corrupted
                }
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func removeFromDiskCache(key: String) async {
        await withCheckedContinuation { continuation in
            Task.detached {
                let fileURL = self.diskCacheURL.appendingPathComponent("\(key).json")
                try? self.fileManager.removeItem(at: fileURL)
                continuation.resume()
            }
        }
    }
    
    private func clearDiskCache() async {
        await withCheckedContinuation { continuation in
            Task.detached {
                do {
                    let contents = try self.fileManager.contentsOfDirectory(at: self.diskCacheURL, includingPropertiesForKeys: nil)
                    for fileURL in contents {
                        try self.fileManager.removeItem(at: fileURL)
                    }
                } catch {
                    if self.configuration.enableLogging {
                        print("[HistoricalDataCache] Error clearing disk cache: \(error)")
                    }
                }
                continuation.resume()
            }
        }
    }
    
    // MARK: - Cache Key Generation
    
    private func generateCacheKey(symbol: String, startDate: Date, endDate: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let startStr = dateFormatter.string(from: startDate)
        let endStr = dateFormatter.string(from: endDate)
        return "\(symbol)_\(startStr)_\(endStr)"
    }
    
    // MARK: - Statistics
    
    private func updateHitCount() async {
        await withCheckedContinuation { continuation in
            cacheQueue.async(flags: .barrier) {
                self.hitCount += 1
                continuation.resume()
            }
        }
    }
    
    private func updateMissCount() async {
        await withCheckedContinuation { continuation in
            cacheQueue.async(flags: .barrier) {
                self.missCount += 1
                continuation.resume()
            }
        }
    }
    
    func getStats() async -> CacheStats {
        return await withCheckedContinuation { continuation in
            cacheQueue.async {
                let totalRequests = self.hitCount + self.missCount
                let hitRate = totalRequests > 0 ? Double(self.hitCount) / Double(totalRequests) : 0
                
                let oldestEntry = self.memoryCache.values.min { $0.timestamp < $1.timestamp }?.timestamp
                let newestEntry = self.memoryCache.values.max { $0.timestamp < $1.timestamp }?.timestamp
                
                let stats = CacheStats(
                    entriesCount: self.memoryCache.count,
                    totalSizeBytes: self.currentSizeBytes,
                    hitRate: hitRate,
                    oldestEntry: oldestEntry,
                    newestEntry: newestEntry
                )
                
                continuation.resume(returning: stats)
            }
        }
    }
    
    // MARK: - Background Tasks
    
    private func startCleanupTask() {
        Task {
            while true {
                try await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes
                await clearExpired()
            }
        }
    }
}