import Foundation
import SwiftUI
import Combine

/**
 * Comprehensive Historical Data Manager
 * 
 * This is the main ViewModel for historical stock data functionality.
 * It provides a UI-friendly interface to the HistoricalDataService actor,
 * handling @Published properties and UI state management.
 * 
 * Designed for Swift 6.0 strict concurrency compliance.
 */
@MainActor
class ComprehensiveHistoricalDataManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var lastError: HistoricalDataError?
    @Published var loadingProgress: Double = 0.0
    @Published var loadingStatus: String = ""
    
    // MARK: - Core Component
    
    private var dataService: HistoricalDataService?
    private let configuration: HistoricalDataServiceConfiguration
    
    // MARK: - Statistics
    
    @Published var cacheStats: CacheStats?
    @Published var storageStats: HistoricalDataStorageStats?
    
    // MARK: - Initialization
    
    init(configuration: HistoricalDataServiceConfiguration = .default) {
        self.configuration = configuration
        
        if configuration.enableLogging {
            print("[ComprehensiveHistoricalDataManager] Initialized with configuration: \(configuration.logLevel.rawValue)")
        }
        
        // Initialize dataService asynchronously
        Task {
            self.dataService = await HistoricalDataService(configuration: configuration)
        }
    }
    
    // No longer needed - direct actor communication
    
    // MARK: - Public API
    
    /// Fetch historical prices with full fallback chain: Cache -> Core Data -> API
    func fetchHistoricalPrices(
        symbol: String,
        period: HistoricalPrice.TimePeriod,
        forceRefresh: Bool = false
    ) async throws -> [HistoricalPrice] {
        
        return try await fetchHistoricalPrices(
            symbol: symbol,
            startDate: period.startDate,
            endDate: period.endDate,
            forceRefresh: forceRefresh
        )
    }
    
    /// Fetch historical prices with custom date range
    func fetchHistoricalPrices(
        symbol: String,
        startDate: Date,
        endDate: Date,
        forceRefresh: Bool = false
    ) async throws -> [HistoricalPrice] {
        
        let cleanSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        isLoading = true
        loadingStatus = "Fetching historical data for \(cleanSymbol)..."
        
        do {
            guard let dataService = dataService else {
                throw HistoricalDataError.providerUnavailable("Data service not initialized")
            }
            
            let result = try await dataService.fetchHistoricalPrices(
                symbol: cleanSymbol,
                startDate: startDate,
                endDate: endDate,
                forceRefresh: forceRefresh
            )
            
            loadingStatus = "Complete"
            isLoading = false
            lastError = nil
            
            return result
            
        } catch {
            isLoading = false
            loadingStatus = "Failed to fetch data"
            let wrappedError = error as? HistoricalDataError ?? HistoricalDataError.networkError(error)
            lastError = wrappedError
            throw wrappedError
        }
    }
    
    /// Fetch multiple symbols with progress tracking
    func fetchMultipleHistoricalPrices(
        symbols: [String],
        period: HistoricalPrice.TimePeriod,
        forceRefresh: Bool = false
    ) async -> [String: [HistoricalPrice]] {
        
        let _ = Double(symbols.count) // Total symbols count for potential progress tracking
        
        isLoading = true
        loadingProgress = 0.0
        loadingStatus = "Fetching multiple symbols..."
        
        guard let dataService = dataService else {
            return [:]
        }
        
        // Delegate to the actor which handles all concurrency safely
        let results = await dataService.fetchMultipleHistoricalPrices(
            symbols: symbols,
            period: period,
            forceRefresh: forceRefresh
        )
        
        // Update UI state
        loadingProgress = 1.0
        loadingStatus = "Completed fetching \(results.count)/\(symbols.count) symbols"
        isLoading = false
        
        return results
    }
    
    /// Get latest price for a symbol
    func fetchLatestPrice(for symbol: String) async throws -> HistoricalPrice {
        isLoading = true
        loadingStatus = "Fetching latest price for \(symbol)..."
        
        do {
            guard let dataService = dataService else {
                throw HistoricalDataError.providerUnavailable("Data service not initialized")
            }
            
            let result = try await dataService.fetchLatestPrice(for: symbol)
            isLoading = false
            loadingStatus = "Complete"
            lastError = nil
            return result
        } catch {
            isLoading = false
            loadingStatus = "Failed to fetch latest price"
            let wrappedError = error as? HistoricalDataError ?? HistoricalDataError.networkError(error)
            lastError = wrappedError
            throw wrappedError
        }
    }
    
    // MARK: - Data Management
    
    /// Clear all cached data
    func clearAllCache() async {
        guard let dataService = dataService else { return }
        
        await dataService.clearAllCache()
        await refreshStats()
        
        if configuration.enableLogging {
            print("[ComprehensiveHistoricalDataManager] All cache cleared")
        }
    }
    
    /// Clear data for specific symbol
    func clearData(for symbol: String) async {
        guard let dataService = dataService else { return }
        
        await dataService.clearData(for: symbol)
        await refreshStats()
        
        if configuration.enableLogging {
            print("[ComprehensiveHistoricalDataManager] Cleared all data for \(symbol)")
        }
    }
    
    /// Cleanup old data beyond retention period
    func cleanupOldData(retentionDays: Int = 365) async {
        guard let dataService = dataService else { return }
        
        await dataService.cleanupOldData(retentionDays: retentionDays)
        await refreshStats()
        
        if configuration.enableLogging {
            print("[ComprehensiveHistoricalDataManager] Cleaned up data older than \(retentionDays) days")
        }
    }
    
    // MARK: - Statistics and Health
    
    func refreshStats() async {
        guard let dataService = dataService else { return }
        
        await dataService.refreshStats()
        
        async let cacheStatsTask = dataService.getCacheStats()
        async let storageStatsTask = dataService.getStorageStats()
        async let errorTask = dataService.getLastError()
        
        let (newCacheStats, newStorageStats, error) = await (cacheStatsTask, storageStatsTask, errorTask)
        
        cacheStats = newCacheStats
        storageStats = newStorageStats
        if let error = error {
            lastError = error
        }
    }
    
    func performHealthCheck() async -> ComprehensiveHealthReport {
        guard let dataService = dataService else {
            return ComprehensiveHealthReport(
                overallHealthy: false,
                apiHealth: HistoricalDataHealthReport(
                    overallHealthy: false,
                    providerHealth: [:],
                    cacheStats: CacheStats(entriesCount: 0, totalSizeBytes: 0, hitRate: 0, oldestEntry: nil, newestEntry: nil),
                    timestamp: Date()
                ),
                cacheStats: CacheStats(entriesCount: 0, totalSizeBytes: 0, hitRate: 0, oldestEntry: nil, newestEntry: nil),
                storageStats: HistoricalDataStorageStats(totalRecords: 0, symbolsWithHistory: 0, oldestRecord: nil, newestRecord: nil, estimatedSizeBytes: 0),
                timestamp: Date()
            )
        }
        
        return await dataService.performHealthCheck()
    }
    
    // MARK: - Provider Information
    
    func getProviderStatus() async -> [(name: String, available: Bool, priority: String, stats: Any?)] {
        guard let dataService = dataService else { return [] }
        return await dataService.getProviderStatus()
    }
    
    func getUsageStats() async -> [String: ProviderUsageStats] {
        guard let dataService = dataService else { return [:] }
        return await dataService.getUsageStats()
    }
    
    func getEstimatedCost(symbols: [String], period: HistoricalPrice.TimePeriod) async -> Decimal {
        guard let dataService = dataService else { return 0 }
        return await dataService.getEstimatedCost(symbols: symbols, period: period)
    }
    
    // MARK: - Configuration
    
    func updateConfiguration(_ newConfiguration: HistoricalDataServiceConfiguration) {
        // This would require reinitializing components if needed
        // For now, just log the change
        if configuration.enableLogging {
            print("[ComprehensiveHistoricalDataManager] Configuration update requested - restart may be required")
        }
    }
    
    // MARK: - Private Helper Methods
    // All UI state updates are now handled directly in @MainActor methods
}

// MARK: - Comprehensive Health Report

struct ComprehensiveHealthReport: Sendable {
    let overallHealthy: Bool
    let apiHealth: HistoricalDataHealthReport
    let cacheStats: CacheStats
    let storageStats: HistoricalDataStorageStats
    let timestamp: Date
    
    var summary: String {
        return """
        Historical Data System Health Report
        Overall Status: \(overallHealthy ? "✓ Healthy" : "✗ Issues Detected")
        
        API System: \(apiHealth.summary)
        
        Cache: \(cacheStats.entriesCount) entries, \(String(format: "%.1f", cacheStats.hitRate * 100))% hit rate
        
        Storage: \(storageStats.totalRecords) records for \(storageStats.symbolsWithHistory) symbols (\(storageStats.formattedSize))
        Date Range: \(storageStats.dateRangeDescription)
        
        Generated: \(DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short))
        """
    }
}

// MARK: - Concurrency Control
// AsyncSemaphore is now handled in HistoricalDataService actor

// MARK: - Combine Support

extension ComprehensiveHistoricalDataManager {
    /// Publisher for cache statistics updates
    var cacheStatsPublisher: AnyPublisher<CacheStats?, Never> {
        $cacheStats.eraseToAnyPublisher()
    }
    
    /// Publisher for storage statistics updates
    var storageStatsPublisher: AnyPublisher<HistoricalDataStorageStats?, Never> {
        $storageStats.eraseToAnyPublisher()
    }
    
    /// Publisher for loading state
    var loadingStatePublisher: AnyPublisher<(isLoading: Bool, progress: Double, status: String), Never> {
        Publishers.CombineLatest3($isLoading, $loadingProgress, $loadingStatus)
            .map { (isLoading: $0, progress: $1, status: $2) }
            .eraseToAnyPublisher()
    }
}