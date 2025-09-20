import Foundation
import CoreData

// MARK: - StockQuote
struct StockQuote: Codable {
    let symbol: String
    let price: Double
    let change: Double
    let changePercent: Double
    let volume: Int64?
    let timestamp: Date
    let companyName: String?
    let lastUpdated: Date
    
    init(symbol: String, price: Double, change: Double = 0.0, changePercent: Double = 0.0, volume: Int64? = nil, timestamp: Date = Date(), companyName: String? = nil, lastUpdated: Date = Date()) {
        self.symbol = symbol.uppercased()
        self.price = price
        self.change = change
        self.changePercent = changePercent
        self.volume = volume
        self.timestamp = timestamp
        self.companyName = companyName
        self.lastUpdated = lastUpdated
    }
    
    // For JSON decoding when needed
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: String].self)
        
        self.symbol = dict["symbol"] ?? ""
        self.price = Double(dict["price"] ?? "0") ?? 0
        self.change = Double(dict["change"] ?? "0") ?? 0
        self.changePercent = Double(dict["changePercent"] ?? "0") ?? 0
        self.volume = Int64(dict["volume"] ?? "0")
        self.companyName = dict["companyName"]
        self.timestamp = Date()
        self.lastUpdated = Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(price, forKey: .price)
        try container.encode(change, forKey: .change)
        try container.encode(changePercent, forKey: .changePercent)
        try container.encode(volume, forKey: .volume)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(companyName, forKey: .companyName)
        try container.encode(lastUpdated, forKey: .lastUpdated)
    }
    
    private enum CodingKeys: String, CodingKey {
        case symbol, price, change, changePercent, volume, timestamp, companyName, lastUpdated
    }
}

// MARK: - PortfolioDividendInfo
struct PortfolioDividendInfo {
    let totalAnnualDividend: Double
    let totalMonthlyDividend: Double
    let averageYield: Double
    let totalYearlyIncome: Double
    
    init(totalAnnualDividend: Double = 0.0, totalMonthlyDividend: Double = 0.0, averageYield: Double = 0.0, totalYearlyIncome: Double = 0.0) {
        self.totalAnnualDividend = totalAnnualDividend
        self.totalMonthlyDividend = totalMonthlyDividend
        self.averageYield = averageYield
        self.totalYearlyIncome = totalYearlyIncome
    }
}

// MARK: - Portfolio Entity
@objc(Portfolio)
public class Portfolio: NSManagedObject {
    
}

extension Portfolio {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Portfolio> {
        return NSFetchRequest<Portfolio>(entityName: "Portfolio")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var portfolioID: UUID?
    @NSManaged public var name: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var createdDate: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var holdings: NSSet?
    
    public var wrappedName: String {
        name ?? "Unknown Portfolio"
    }
    
    public var holdingsArray: [Holding] {
        let set = holdings as? Set<Holding> ?? []
        return set.sorted {
            ($0.stock?.symbol ?? "") < ($1.stock?.symbol ?? "")
        }
    }
    
    public var totalValue: Double {
        holdingsArray.reduce(0) { total, holding in
            total + (holding.currentValue)
        }
    }
    
    public var totalCost: Double {
        holdingsArray.reduce(0) { total, holding in
            total + holding.totalCost
        }
    }
    
    public var totalGainLoss: Double {
        totalValue - totalCost
    }
    
    public var totalGainLossPercent: Double {
        guard totalCost > 0 else { return 0 }
        return (totalGainLoss / totalCost) * 100
    }
}

// MARK: - Holding Entity
@objc(Holding)
public class Holding: NSManagedObject {
    
}

extension Holding {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Holding> {
        return NSFetchRequest<Holding>(entityName: "Holding")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var quantity: Double
    @NSManaged public var averageCost: Double
    @NSManaged public var purchaseDate: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var portfolio: Portfolio?
    @NSManaged public var stock: Stock?
    
    public var totalCost: Double {
        quantity * averageCost
    }
    
    public var currentValue: Double {
        quantity * (stock?.currentPrice ?? 0)
    }
    
    public var gainLoss: Double {
        currentValue - totalCost
    }
    
    public var gainLossPercent: Double {
        guard totalCost > 0 else { return 0 }
        return (gainLoss / totalCost) * 100
    }
}

// MARK: - Stock Entity
@objc(Stock)
public class Stock: NSManagedObject {
    
}

extension Stock {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Stock> {
        return NSFetchRequest<Stock>(entityName: "Stock")
    }
    
    @NSManaged public var symbol: String?
    @NSManaged public var name: String?
    @NSManaged public var currentPrice: Double
    @NSManaged public var previousClose: Double
    @NSManaged public var change: Double
    @NSManaged public var changePercent: Double
    @NSManaged public var volume: Int64
    @NSManaged public var marketCap: Double
    @NSManaged public var sector: String?
    @NSManaged public var industry: String?
    @NSManaged public var lastUpdated: Date?
    @NSManaged public var holdings: NSSet?
    @NSManaged public var dividends: NSSet?
    
    public var wrappedSymbol: String {
        symbol ?? "UNKNOWN"
    }
    
    public var wrappedName: String {
        name ?? "Unknown Company"
    }
    
    public var holdingsArray: [Holding] {
        let set = holdings as? Set<Holding> ?? []
        return set.sorted {
            ($0.portfolio?.name ?? "") < ($1.portfolio?.name ?? "")
        }
    }
}

// MARK: - Dividend Entity
@objc(Dividend)
public class Dividend: NSManagedObject {
    
}

extension Dividend {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Dividend> {
        return NSFetchRequest<Dividend>(entityName: "Dividend")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var amount: Double
    @NSManaged public var exDate: Date?
    @NSManaged public var payDate: Date?
    @NSManaged public var declarationDate: Date?
    @NSManaged public var frequency: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var stock: Stock?
    
    public var wrappedFrequency: String {
        frequency ?? "Unknown"
    }
}