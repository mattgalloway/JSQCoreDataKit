//
//  Created by Matt Galloway
//
//  Documentation
//  http://www.jessesquires.com/JSQCoreDataKit
//
//
//  GitHub
//  https://github.com/jessesquires/JSQCoreDataKit
//
//
//  License
//  Copyright © 2016 Matt Galloway
//  Released under an MIT license: http://opensource.org/licenses/MIT
//

import Foundation
import CoreData

public class CoreDataManager: CustomStringConvertible {
    
    // MARK: Properties
    
    /// The Core Data Stack to manange.
    private let stack: CoreDataStack

    /// A dictionary that maps context thread ids to contexts dedicated to the releated thread
    private var threadContexts = [String: NSManagedObjectContext]()
    
    // MARK: Initialization
    
    /**
     Constructs a new `CoreDataManager` instance with the specified CoreDataStack.
     
     - parameter stack:     The Core Data Stack to manange.
     
     - returns: A new `CoreDataManagerl` instance.
     */
    public init(stack: CoreDataStack) {
        self.stack = stack
        NSNotificationCenter.defaultCenter().addObserverForName(NSThreadWillExitNotification,
                                                                object: nil,
                                                                queue: nil,
                                                                usingBlock: { [unowned self] notification in
                                                                    self.handleExitThreadNotification(notification) })
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self);
    }
 
    
    // MARK: Thread Context Manangement
    
    public func threadContext() -> NSManagedObjectContext {
        if NSThread.isMainThread() {
            return stack.mainContext;
        } else {
            let threadDictionary = NSThread.currentThread().threadDictionary;
            var threadContextId = threadDictionary["JSQThreadContextId"] as! String?
            if  threadContextId == nil {
                threadContextId = NSUUID().UUIDString;
                threadDictionary["JSQThreadContextId"] = threadContextId
                threadContexts[threadContextId!] = stack.backgroundContext
            }
            return threadContexts[threadContextId!]!
        }
    }

    private func handleExitThreadNotification(notification: NSNotification) {
        dismissThreadContext()
    }

    
    private func dismissThreadContext() {
        guard NSThread.isMainThread() == false else {
            return
        }
        
        let threadDictionary = NSThread.currentThread().threadDictionary;
        guard let threadContextId = threadDictionary["JSQThreadContextId"] as! String? else {
            return
        }
        threadDictionary.removeObjectForKey("JSQThreadContextId")
        threadContexts.removeValueForKey(threadContextId)
    }
    
    // MARK: Pass-Thru Context Dependent Mathods
    
    public func saveContext(context: NSManagedObjectContext? = nil, wait: Bool = true, completion: ((SaveResult) -> Void)? = nil) {
        var realizedContext = context
        if realizedContext == nil {
            realizedContext = threadContext()
        }
        saveContext(realizedContext!, wait: wait, completion: completion)
    }
    
    public func entity(name name: String, context: NSManagedObjectContext? = nil) -> NSEntityDescription {
        var realizedContext = context
        if realizedContext == nil {
            realizedContext = threadContext()
        }
        return entity(name: name, context: realizedContext!)
    }
    
    public func fetch <T: NSManagedObject>(request request: FetchRequest<T>, inContext context: NSManagedObjectContext? = nil) throws -> [T] {
        var realizedContext = context
        if realizedContext == nil {
            realizedContext = threadContext()
        }
        
        var results = [AnyObject]()
        var caughtError: NSError?
        
        do{
            results = try fetch(request: request, inContext: realizedContext!)
        } catch {
            caughtError = error as NSError
        }
        guard caughtError == nil else { throw caughtError! }
        return results as! [T]
    }
    
    public func deleteObjects <T: NSManagedObject>(objects: [T], inContext context: NSManagedObjectContext? = nil) {
        var realizedContext = context
        if realizedContext == nil {
            realizedContext = threadContext()
        }
        deleteObjects(objects, inContext: realizedContext!)
    }
    
    // MARK: CustomStringConvertible
    
    /// :nodoc:
    public var description: String {
        get {
            return "Hello"
            //return "<\(CoreDataModel.self): name=\(name); storeType=\(storeType); needsMigration=\(needsMigration); "
            //    + "modelURL=\(modelURL); storeURL=\(storeURL)>"
        }
    }
}