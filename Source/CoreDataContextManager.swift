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

public class CoreDataContextManager: CustomStringConvertible {
    
    // MARK: Properties
    
    /// The Core Data Stack to manange.
    private let stack: CoreDataStack

    /// A dictionary that maps context thread ids to contexts dedicated to the releated thread
    private var threadContexts = [String: NSManagedObjectContext]()
    
    // MARK: Initialization
    
    /**
     Constructs a new `CoreDataContextManager` instance with the specified CoreDataStack.  The 
     CoreDataContextManager object will create one NSManagedContext for each background thread 
     or return the main context if called on the main thread. Each thread context is mapped to
     it's thread and is retained for the life of the thread. When the thread dies, the reference 
     to the associated context is removed. 
     
     Conveinence methods are provided for saving, creating entities descriptions, performing 
     fetches and deleting objects without the need to specify a context.
     
     - parameter stack: The Core Data Stack to for which the contexts will be mananged.
     
     - returns: A new `CoreDataContextManager` instance.
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
            print ("returning main thread context")
            return stack.mainContext;
        } else {
            let threadDictionary = NSThread.currentThread().threadDictionary;
            var threadContextId = threadDictionary["JSQThreadContextId"] as! String?
            if  threadContextId == nil {
                threadContextId = NSUUID().UUIDString;
                threadDictionary["JSQThreadContextId"] = threadContextId
                threadContexts[threadContextId!] = stack.backgroundContext
            }
            print ("returning context with id \(threadContextId)")
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
        JSQCoreDataKit.saveContext(realizedContext!, wait: wait, completion: completion)
    }
    
    public func entity(name name: String, context: NSManagedObjectContext? = nil) -> NSEntityDescription {
        var realizedContext = context
        if realizedContext == nil {
            realizedContext = threadContext()
        }
        return JSQCoreDataKit.entity(name: name, context: realizedContext!)
    }
    
    public func fetch <T: NSManagedObject>(request request: FetchRequest<T>, inContext context: NSManagedObjectContext? = nil) throws -> [T] {
        var realizedContext = context
        if realizedContext == nil {
            realizedContext = threadContext()
        }
        
        var results = [AnyObject]()
        var caughtError: NSError?
        
        do {
            results = try JSQCoreDataKit.fetch(request: request, inContext: realizedContext!)
        } catch {
            caughtError = error as NSError
        }
        guard caughtError == nil else {throw caughtError!}
        return results as! [T]
    }
    
    public func deleteObjects <T: NSManagedObject>(objects: [T], inContext context: NSManagedObjectContext? = nil) {
        var realizedContext = context
        if realizedContext == nil {
            realizedContext = threadContext()
        }
        JSQCoreDataKit.deleteObjects(objects, inContext: realizedContext!)
    }
    
    public func existingObjectWithID(objectID: NSManagedObjectID) throws -> NSManagedObject {
        var managedObject: NSManagedObject? = nil
        var caughtError: NSError?
        
        do {
            managedObject = try threadContext().existingObjectWithID(objectID)
        } catch  {
            caughtError = error as NSError
        }
        guard caughtError == nil else {throw caughtError!}
        return managedObject as NSManagedObject!
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