import Foundation
import CoreData

// MARK: - Dividend Entity Extensions

extension Dividend {
    
    // MARK: - Computed Properties
    
    /// 格式化的配息金額顯示
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "USD"
        formatter.minimumFractionDigits = 4
        return formatter.string(from: amount as NSDecimalNumber? ?? 0) ?? "$0.0000"
    }
    
    /// 格式化的年化配息率顯示
    var formattedYield: String {
        let percentage = (yield as Decimal? ?? 0) * 100
        return String(format: "%.2f%%", percentage as NSNumber)
    }
    
    /// 配息類型本地化顯示
    var localizedDividendType: String {
        switch dividendType {
        case "DIVIDEND":
            return "股息"
        case "DISTRIBUTION":
            return "配息"
        case "SPECIAL":
            return "特殊配息"
        case "SPLIT":
            return "股票分割"
        case "BONUS":
            return "紅股"
        default:
            return dividendType ?? "未知"
        }
    }
    
    /// 配息頻率本地化顯示
    var localizedFrequency: String {
        switch frequency {
        case "MONTHLY":
            return "月配"
        case "QUARTERLY":
            return "季配"
        case "SEMI_ANNUALLY":
            return "半年配"
        case "ANNUALLY":
            return "年配"
        case "IRREGULAR":
            return "不定期"
        default:
            return frequency ?? "未知"
        }
    }
    
    /// 是否為即將到來的配息（未來30天內）
    var isUpcoming: Bool {
        guard let paymentDate = paymentDate else { return false }
        let now = Date()
        let futureLimit = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        return paymentDate > now && paymentDate <= futureLimit
    }
    
    /// 是否已支付
    var isPaid: Bool {
        guard let paymentDate = paymentDate else { return false }
        return paymentDate <= Date()
    }
    
    /// 資料來源顯示
    var dataSourceDisplay: String {
        if isUserProvided {
            return "手動輸入"
        }
        return dataSource ?? "API"
    }
    
    // MARK: - Static Methods
    
    /// 創建新的配息記錄
    static func create(
        in context: NSManagedObjectContext,
        for stock: Stock,
        amount: Decimal,
        currency: String = "USD",
        dividendType: DividendType = .dividend,
        frequency: DividendFrequency? = nil,
        paymentDate: Date?,
        exDividendDate: Date? = nil,
        recordDate: Date? = nil,
        declarationDate: Date? = nil,
        annualizedAmount: Decimal? = nil,
        yield: Decimal? = nil,
        isUserProvided: Bool = false,
        dataSource: String = "API",
        notes: String? = nil
    ) -> Dividend {
        let dividend = Dividend(context: context)
        
        dividend.id = UUID()
        dividend.amount = amount as NSDecimalNumber
        dividend.currency = currency
        dividend.dividendType = dividendType.rawValue
        dividend.frequency = frequency?.rawValue
        dividend.paymentDate = paymentDate
        dividend.exDividendDate = exDividendDate
        dividend.recordDate = recordDate
        dividend.declarationDate = declarationDate
        dividend.annualizedAmount = annualizedAmount as NSDecimalNumber?
        dividend.yield = yield as NSDecimalNumber?
        dividend.isUserProvided = isUserProvided
        dividend.dataSource = dataSource
        dividend.lastUpdated = Date()
        dividend.notes = notes
        dividend.stock = stock
        
        return dividend
    }
    
    /// 獲取股票的最新配息記錄
    static func getLatestDividend(for stock: Stock, in context: NSManagedObjectContext) -> Dividend? {
        let request: NSFetchRequest<Dividend> = Dividend.fetchRequest()
        request.predicate = NSPredicate(format: "stock == %@", stock)
        request.sortDescriptors = [NSSortDescriptor(key: "paymentDate", ascending: false)]
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
    }
    
    /// 獲取股票的年度配息總額
    static func getAnnualDividendAmount(for stock: Stock, year: Int, in context: NSManagedObjectContext) -> Decimal {
        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let endDate = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))!
        
        let request: NSFetchRequest<Dividend> = Dividend.fetchRequest()
        request.predicate = NSPredicate(
            format: "stock == %@ AND paymentDate >= %@ AND paymentDate < %@",
            stock, startDate as NSDate, endDate as NSDate
        )
        
        guard let dividends = try? context.fetch(request) else { return 0 }
        
        return dividends.reduce(0) { total, dividend in
            total + (dividend.amount as Decimal? ?? 0)
        }
    }
    
    /// 計算持股的配息收入
    func calculateDividendIncome(for holding: Holding) -> Decimal {
        guard let amount = amount as Decimal? else { return 0 }
        let quantity = Decimal(holding.quantity)
        return amount * quantity
    }
}

// MARK: - Enumerations

enum DividendType: String, CaseIterable {
    case dividend = "DIVIDEND"
    case distribution = "DISTRIBUTION"
    case special = "SPECIAL"
    case split = "SPLIT"
    case bonus = "BONUS"
    
    var localizedDescription: String {
        switch self {
        case .dividend: return "股息"
        case .distribution: return "配息"
        case .special: return "特殊配息"
        case .split: return "股票分割"
        case .bonus: return "紅股"
        }
    }
}

enum DividendFrequency: String, CaseIterable {
    case monthly = "MONTHLY"
    case quarterly = "QUARTERLY"
    case semiAnnually = "SEMI_ANNUALLY"
    case annually = "ANNUALLY"
    case irregular = "IRREGULAR"
    
    var localizedDescription: String {
        switch self {
        case .monthly: return "月配"
        case .quarterly: return "季配"
        case .semiAnnually: return "半年配"
        case .annually: return "年配"
        case .irregular: return "不定期"
        }
    }
    
    /// 每年配息次數
    var paymentsPerYear: Int {
        switch self {
        case .monthly: return 12
        case .quarterly: return 4
        case .semiAnnually: return 2
        case .annually: return 1
        case .irregular: return 1 // 預設值
        }
    }
}

// MARK: - NSFetchRequest Extensions

extension Dividend {
    
    /// 獲取指定股票的所有配息記錄
    static func fetchRequest(for stock: Stock) -> NSFetchRequest<Dividend> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "stock == %@", stock)
        request.sortDescriptors = [NSSortDescriptor(key: "paymentDate", ascending: false)]
        return request
    }
    
    /// 獲取即將到來的配息
    static func fetchUpcomingDividends() -> NSFetchRequest<Dividend> {
        let request = fetchRequest()
        let now = Date()
        let futureLimit = Calendar.current.date(byAdding: .day, value: 30, to: now)!
        
        request.predicate = NSPredicate(
            format: "paymentDate > %@ AND paymentDate <= %@",
            now as NSDate, futureLimit as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(key: "paymentDate", ascending: true)]
        return request
    }
    
    /// 獲取指定時間範圍的配息記錄
    static func fetchDividends(from startDate: Date, to endDate: Date) -> NSFetchRequest<Dividend> {
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "paymentDate >= %@ AND paymentDate <= %@",
            startDate as NSDate, endDate as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(key: "paymentDate", ascending: false)]
        return request
    }
}