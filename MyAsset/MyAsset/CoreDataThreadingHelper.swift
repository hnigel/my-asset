import Foundation
import CoreData
import os.log

/// Thread-safe helper for Core Data operations to prevent threading violations and deadlocks
final class CoreDataThreadingHelper {
    
    /// Safely performs a read operation on the main context
    static func safeRead<T>(
        context: NSManagedObjectContext,
        operation: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let result = try operation(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Safely performs a write operation on a background context
    static func safeWrite<T>(
        backgroundContext: NSManagedObjectContext,
        operation: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    let result = try operation(backgroundContext)
                    
                    // Only save if there are changes
                    if backgroundContext.hasChanges {
                        try backgroundContext.save()
                    }
                    
                    continuation.resume(returning: result)
                } catch {
                    backgroundContext.rollback()
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Safely transfers managed objects between contexts
    static func transferToContext<T: NSManagedObject>(
        _ objects: [T],
        destinationContext: NSManagedObjectContext
    ) -> [T] {
        return objects.compactMap { object in
            guard !object.objectID.isTemporaryID else { return nil }
            do {
                return try destinationContext.existingObject(with: object.objectID) as? T
            } catch {
                os_log("Failed to transfer object to context: %@", 
                       log: .default, type: .error, error.localizedDescription)
                return nil
            }
        }
    }
    
    /// Safely checks if an object is valid and accessible
    static func isObjectValid<T: NSManagedObject>(_ object: T) -> Bool {
        return !object.isDeleted && 
               object.managedObjectContext != nil &&
               !object.objectID.isTemporaryID
    }
    
    /// Creates a thread-safe notification publisher for Core Data changes
    static func createChangeNotificationPublisher(
        for entityNames: [String]? = nil
    ) -> Publishers.Filter<NotificationCenter.Publisher> {
        return NotificationCenter.default
            .publisher(for: .NSManagedObjectContextDidSave)
            .filter { notification in
                guard let userInfo = notification.userInfo else { return false }
                
                // If specific entities are specified, only notify for those
                if let entityNames = entityNames {
                    let hasRelevantChanges = entityNames.contains { entityName in
                        return userInfo.keys.contains { key in
                            guard let key = key as? String else { return false }
                            return key.contains(entityName)
                        }
                    }
                    return hasRelevantChanges
                }
                
                return true
            }
    }
    
    /// Safely merges changes from remote contexts with debouncing
    static func setupAutoMerging(
        for mainContext: NSManagedObjectContext,
        debounceInterval: TimeInterval = 0.1
    ) {
        NotificationCenter.default
            .publisher(for: .NSManagedObjectContextDidSave)
            .compactMap { notification -> [String: Any]? in
                guard let context = notification.object as? NSManagedObjectContext,
                      context !== mainContext,
                      let userInfo = notification.userInfo else { return nil }
                return userInfo as? [String: Any]
            }
            .debounce(for: .seconds(debounceInterval), scheduler: DispatchQueue.main)
            .sink { userInfo in
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: userInfo, into: [mainContext])
            }
            .store(in: &cancellables)
    }
    
    private static var cancellables: Set<AnyCancellable> = []
}

import Combine

// Extension to handle Combine publishers
extension CoreDataThreadingHelper {
    
    /// Creates a safe publisher for monitoring specific managed objects
    static func createObjectChangePublisher<T: NSManagedObject>(
        for object: T
    ) -> AnyPublisher<T?, Never> {
        return NotificationCenter.default
            .publisher(for: .NSManagedObjectContextObjectsDidChange)
            .compactMap { notification -> T? in
                guard let context = notification.object as? NSManagedObjectContext,
                      context == object.managedObjectContext else { return nil }
                
                // Check if our object was updated
                if let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>,
                   updatedObjects.contains(object) {
                    return isObjectValid(object) ? object : nil
                }
                
                // Check if our object was deleted
                if let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject>,
                   deletedObjects.contains(object) {
                    return nil
                }
                
                return object
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}