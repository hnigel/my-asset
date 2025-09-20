import Foundation
import CoreData
import os.log

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "AssetModel")
        
        // Configure persistent store options for better performance and migration support
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Enable WAL mode for better concurrency
        description?.setOption(["journal_mode": "WAL"] as NSDictionary, forKey: NSSQLitePragmasOption)
        
        container.loadPersistentStores { _, error in
            if let error = error {
                os_log("Core Data error: %@", log: .default, type: .error, error.localizedDescription)
                fatalError("Core Data error: \(error.localizedDescription)")
            }
        }
        
        // Configure main context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    // Main context for UI operations
    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    // Background context for heavy operations - reuse to prevent thread conflicts
    lazy var backgroundContext: NSManagedObjectContext = {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }()
    
    // MARK: - Save Operations
    
    func save() {
        save(context: context)
    }
    
    func save(context: NSManagedObjectContext) {
        // Ensure we're saving on the context's queue to prevent threading violations
        guard context.hasChanges else { return }
        
        context.performAndWait {
            do {
                try context.save()
            } catch {
                os_log("Save error: %@", log: .default, type: .error, error.localizedDescription)
                
                // Attempt to rollback on error
                context.rollback()
                
                // Re-throw for caller to handle
                assertionFailure("Core Data save error: \(error)")
            }
        }
    }
    
    // Save with completion handler for background contexts
    func saveInBackground(context: NSManagedObjectContext? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        let contextToUse = context ?? backgroundContext
        
        contextToUse.perform {
            guard contextToUse.hasChanges else {
                DispatchQueue.main.async {
                    completion(.success(()))
                }
                return
            }
            
            do {
                try contextToUse.save()
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                os_log("Background save error: %@", log: .default, type: .error, error.localizedDescription)
                contextToUse.rollback()
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Batch Operations
    
    func batchDelete<T: NSManagedObject>(
        fetchRequest: NSFetchRequest<T>,
        context: NSManagedObjectContext? = nil
    ) throws {
        let contextToUse = context ?? backgroundContext
        
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)
        batchDeleteRequest.resultType = .resultTypeObjectIDs
        
        let result = try contextToUse.execute(batchDeleteRequest) as! NSBatchDeleteResult
        let objectIDArray = result.result as! [NSManagedObjectID]
        let changes = [NSDeletedObjectsKey: objectIDArray]
        
        // Merge changes on main queue to prevent threading violations
        DispatchQueue.main.async {
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.context])
        }
    }
    
    func batchUpdate(
        request: NSBatchUpdateRequest,
        context: NSManagedObjectContext? = nil
    ) throws {
        let contextToUse = context ?? backgroundContext
        
        request.resultType = .updatedObjectIDsResultType
        let result = try contextToUse.execute(request) as! NSBatchUpdateResult
        let objectIDArray = result.result as! [NSManagedObjectID]
        let changes = [NSUpdatedObjectsKey: objectIDArray]
        
        // Merge changes on main queue to prevent threading violations
        DispatchQueue.main.async {
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.context])
        }
    }
    
    // MARK: - Fetch Utilities
    
    func count<T: NSManagedObject>(
        for fetchRequest: NSFetchRequest<T>,
        in context: NSManagedObjectContext? = nil
    ) -> Int {
        let contextToUse = context ?? self.context
        
        do {
            return try contextToUse.count(for: fetchRequest)
        } catch {
            os_log("Count fetch error: %@", log: .default, type: .error, error.localizedDescription)
            return 0
        }
    }
    
    func performAndWait<T>(_ block: (NSManagedObjectContext) throws -> T) rethrows -> T {
        return try context.performAndWait {
            try block(context)
        }
    }
    
    func performInBackground<T>(
        _ block: @escaping (NSManagedObjectContext) throws -> T,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let bgContext = backgroundContext
        bgContext.perform {
            do {
                let result = try block(bgContext)
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Migration Support
    
    /// Validates and fixes any data integrity issues after model changes
    func validateAndFixDataIntegrity() {
        performInBackground({ context in
            // Fix any stocks with missing required fields
            let stockRequest: NSFetchRequest<Stock> = Stock.fetchRequest()
            let stocks = try context.fetch(stockRequest)
            
            for stock in stocks {
                // Ensure symbol is not empty (it should be unique and non-optional now)
                if stock.symbol?.isEmpty ?? true {
                    context.delete(stock)
                    os_log("Deleted stock with empty symbol", log: .default, type: .info)
                    continue
                }
                
                // Ensure current price is valid
                if let currentPrice = stock.currentPrice, currentPrice.decimalValue < 0 {
                    stock.currentPrice = NSDecimalNumber.zero
                } else if stock.currentPrice == nil {
                    stock.currentPrice = NSDecimalNumber.zero
                }
            }
            
            // Fix any holdings with invalid data
            let holdingRequest: NSFetchRequest<Holding> = Holding.fetchRequest()
            let holdings = try context.fetch(holdingRequest)
            
            for holding in holdings {
                // Ensure quantity is positive
                if holding.quantity <= 0 {
                    context.delete(holding)
                    os_log("Deleted holding with invalid quantity", log: .default, type: .info)
                    continue
                }
                
                // Ensure price per share is valid
                if let pricePerShare = holding.pricePerShare {
                    if pricePerShare.decimalValue <= 0 {
                        context.delete(holding)
                        os_log("Deleted holding with invalid price", log: .default, type: .info)
                    }
                } else {
                    context.delete(holding)
                    os_log("Deleted holding with nil price", log: .default, type: .info)
                }
            }
            
            try context.save()
        }) { result in
            switch result {
            case .success:
                os_log("Data integrity validation completed successfully", log: .default, type: .info)
            case .failure(let error):
                os_log("Data integrity validation failed: %@", log: .default, type: .error, error.localizedDescription)
            }
        }
    }
    
    private init() {}
}