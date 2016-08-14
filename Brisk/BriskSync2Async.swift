//
//  BriskSync2Async.swift
//  Brisk
//
//  Created by Jason Fieldman on 8/12/16.
//  Copyright © 2016 Jason Fieldman. All rights reserved.
//

import Foundation



// handler+>(result: nil)
// handler>>.main.async(result: nil)
// handler+>.async(result: nil)
// handler>>.on(queue).async(result: nil)
// handler~>.async(result: nil)
// handler+>(result: nil)+>{ i in }
// handler+>(result: nil)~~queue~>{ i in }


public class __BriskRoutingObj<I, O> {
    
    // ---------- Properties ----------
    
    // The dispatch group used in various synchronizing routines
    private let dispatchGroup = dispatch_group_create()
    
    // This is the actual function that we are routing
    private let wrappedFunction: I -> O
    
    // If we are routing the response, this catches the value
    private var response: O? = nil
    
    // This is the queue that the function will be executed on
    private var opQueue: dispatch_queue_t? = nil
    
    // This is the queue that the handler will execute on (if needed)
    private var handlerQueue: dispatch_queue_t? = nil
    
    // The lock used to synchronize various accesses
    private var lock: OSSpinLock = OS_SPINLOCK_INIT
    
    // Is this routing object available to perform its operation?
    // The routing objects may only perform their operations once, they should
    // NOT be retained and called a second time.
    private var operated: Bool = false
    
    
    
    // ---------- Init ------------
    
    // Instantiate ourselves with a function
    private init(function: I -> O, defaultOpQueue: dispatch_queue_t? = nil) {
        wrappedFunction = function
        opQueue = defaultOpQueue
    }
    
    
    
    // ---------- Queue Adjustments -------------
    
    /// Returns the current routing object set to execute its
    /// function on the main queue
    public var main: __BriskRoutingObj<I, O> {
        self.opQueue = mainQueue
        return self
    }
    
    /// Returns the current routing object set to execute its
    /// function on the generic concurrent background queue
    public var background: __BriskRoutingObj<I, O> {
        self.opQueue = backgroundQueue
        return self
    }
    
    /// Returns the current routing object set to execute its
    /// function on the specified queue
    @inline(__always) public func on(queue: dispatch_queue_t) -> __BriskRoutingObj<I, O> {
        self.opQueue = queue
        return self
    }
 
    
    
    // ----------- Execution -------------
    
    
    /// The sync property returns a function with the same input/output
    /// parameters of the original function.  It is executed asynchronously
    /// on the specified queue.  The calling thread is blocked until the
    /// called function completes.  Not compatible with functions that throw
    /// errors.
    public var sync: I -> O {
        guard let opQ = opQueue else {
            fatalError("You must specify a queue for this function to operate on")
        }
        
        guard !synchronized(&lock, block: { let o = self.operated; self.operated = false; return o }) else {
            fatalError("You may not retain or use this routing object in a way that it can be executed more than once.")
        }
        
        return { i in
            dispatch_group_enter(self.dispatchGroup)
            dispatch_async(opQ) {
                self.response = self.wrappedFunction(i)
                dispatch_group_leave(self.dispatchGroup)
            }
            dispatch_group_wait(self.dispatchGroup, DISPATCH_TIME_FOREVER)
            return self.response! // Will be set in the async call above
        }
    }
    
    
    /// Processes the async handler applied to this routing object.
    private func processAsyncHandler(handler: O -> Void) {
        guard let hQ = self.handlerQueue else {
            fatalError("The handler queue was not specified before routing the async response")
        }
        
        dispatch_async(backgroundQueue) {
            dispatch_group_wait(self.dispatchGroup, DISPATCH_TIME_FOREVER)
            dispatch_async(hQ) {
                handler(self.response!) // Will be set in the async call before wait completes
            }
        }
    }
}


public class __BriskRoutingObjVoid<I>: __BriskRoutingObj<I, Void> {
    
    // Instantiate ourselves with a function
    override private init(function: I -> Void, defaultOpQueue: dispatch_queue_t? = nil) {
        super.init(function: function, defaultOpQueue: defaultOpQueue)
    }
    
    /// The async property returns a function that takes the parameters
    /// from the original function, executes the function with those
    /// parameters in the desired queue, then returns Void back to the
    /// originating thread. (for functions that originally return Void)
    ///
    /// When calling the wrapped function, the internal dispatchQueue
    /// is not exited until the wrapped function completes.  This
    /// internal dispatchQueue can be waited on to funnel the response
    /// of the wrapped function to yet another async dispatch.
    public var async: I -> Void {
        guard let opQ = opQueue else {
            fatalError("You must specify a queue for this function to operate on")
        }
        
        guard !synchronized(&lock, block: { let o = self.operated; self.operated = false; return o }) else {
            fatalError("You may not retain or use this routing object in a way that it can be executed more than once.")
        }
        
        return { i in
            dispatch_group_enter(self.dispatchGroup)
            dispatch_async(opQ) {
                self.response = self.wrappedFunction(i)
                dispatch_group_leave(self.dispatchGroup)
            }
        }
    }
}

public class __BriskRoutingObjNonVoid<I, O>: __BriskRoutingObj<I, O> {
    
    // Instantiate ourselves with a function
    override private init(function: I -> O, defaultOpQueue: dispatch_queue_t? = nil) {
        super.init(function: function, defaultOpQueue: defaultOpQueue)
    }
    
    /// The async property returns a function that takes the parameters
    /// from the original function, executes the function with those
    /// parameters in the desired queue, then returns the original
    /// routing object back to the originating thread.
    ///
    /// When calling the wrapped function, the internal dispatchQueue
    /// is not exited until the wrapped function completes.  This
    /// internal dispatchQueue can be waited on to funnel the response
    /// of the wrapped function to yet another async dispatch.
    public var async: I -> __BriskRoutingObjNonVoid<I, O> {
        guard let opQ = opQueue else {
            fatalError("You must specify a queue for this function to operate on")
        }
        
        guard !synchronized(&lock, block: { let o = self.operated; self.operated = false; return o }) else {
            fatalError("You may not retain or use this routing object in a way that it can be executed more than once.")
        }
        
        return { i in
            dispatch_group_enter(self.dispatchGroup)
            dispatch_async(opQ) {
                self.response = self.wrappedFunction(i)
                dispatch_group_leave(self.dispatchGroup)
            }
            return self
        }
    }
}



// MARK: - Operators

postfix operator >> {}
postfix operator ~> {}
postfix operator +> {}


/// The ```>>``` postfix operator generates an internal routing object that
/// requires you to specify the operation queue.  An example of this
/// would be:
///
/// ```handler>>.main.async(result: nil)```
@inline(__always) public postfix func >><I>(function: I -> Void) -> __BriskRoutingObjVoid<I> {
    return __BriskRoutingObjVoid(function: function)
}

/// The ```>>``` postfix operator generates an internal routing object that
/// requires you to specify the operation queue.  An example of this
/// would be:
///
/// ```handler>>.main.async(result: nil)```
@inline(__always) public postfix func >><I, O>(function: I -> O) -> __BriskRoutingObjNonVoid<I,O> {
    return __BriskRoutingObjNonVoid(function: function)
}



/// The ```~>``` postfix operator generates an internal routing object that
/// defaults to the concurrent background queue.  An example of this
/// would be:
///
/// ```handler~>.async(result: nil)```
@inline(__always) public postfix func ~><I>(function: I -> Void) -> __BriskRoutingObjVoid<I> {
    return __BriskRoutingObjVoid(function: function, defaultOpQueue: backgroundQueue)
}

/// The ```~>``` postfix operator generates an internal routing object that
/// defaults to the concurrent background queue.  An example of this
/// would be:
///
/// ```handler~>.async(result: nil)```
@inline(__always) public postfix func ~><I, O>(function: I -> O) -> __BriskRoutingObjNonVoid<I,O> {
    return __BriskRoutingObjNonVoid(function: function, defaultOpQueue: backgroundQueue)
}



/// The ```+>``` postfix operator generates an internal routing object that
/// defaults to the main queue.  An example of this would be:
///
/// ```handler+>.async(result: nil)```
@inline(__always) public postfix func +><I>(function: I -> Void) -> __BriskRoutingObjVoid<I> {
    return __BriskRoutingObjVoid(function: function, defaultOpQueue: mainQueue)
}

/// The ```+>``` postfix operator generates an internal routing object that
/// defaults to the main queue.  An example of this would be:
///
/// ```handler+>.async(result: nil)```
@inline(__always) public postfix func +><I, O>(function: I -> O) -> __BriskRoutingObjNonVoid<I,O> {
    return __BriskRoutingObjNonVoid(function: function, defaultOpQueue: mainQueue)
}



infix operator ~> { associativity left precedence 140 }
infix operator +> { associativity left precedence 140 }
infix operator ~~ { associativity left precedence 140 }


/// The ```~>``` infix operator allows for shorthand creation of a routing object
/// that operates asynchronously on the global concurrent background queue.
///
/// - e.g.: ```handler~>(param: nil)```
public func ~><I>(lhs: I -> Void, rhs: I) -> Void {
    return __BriskRoutingObjVoid(function: lhs, defaultOpQueue: backgroundQueue).async(rhs)
}

/// The ```~>``` infix operator allows for shorthand creation of a routing object
/// that operates asynchronously on the global concurrent background queue.
///
/// - e.g.: ```handler~>(param: nil)```
public func ~><I, O>(lhs: I -> O, rhs: I) -> __BriskRoutingObjNonVoid<I, O> {
    return __BriskRoutingObjNonVoid(function: lhs, defaultOpQueue: backgroundQueue).async(rhs)
}




/// The ```+>``` infix operator allows for shorthand creation of a routing object
/// that operates asynchronously on the main queue.
///
/// - e.g.: ```handler+>(param: nil)```
public func +><I>(lhs: I -> Void, rhs: I) -> Void {
    return __BriskRoutingObjVoid(function: lhs, defaultOpQueue: mainQueue).async(rhs)
}

/// The ```+>``` infix operator allows for shorthand creation of a routing object
/// that operates asynchronously on the main queue.
///
/// - e.g.: ```handler+>(param: nil)```
public func +><I, O>(lhs: I -> O, rhs: I) -> __BriskRoutingObjNonVoid<I, O> {
    return __BriskRoutingObjNonVoid(function: lhs, defaultOpQueue: mainQueue).async(rhs)
}




/// The special ```~~``` infix operator allows you to specify the queue that the
/// completion handler will be called with the result of your asynchronous operation.
///
/// - e.g.: ```handler~>(param: nil) ~~ myQueue ~> { result in ... }```
public func ~~<I, O>(lhs: __BriskRoutingObjNonVoid<I, O>, rhs: dispatch_queue_t) -> __BriskRoutingObjNonVoid<I, O> {
    lhs.handlerQueue = rhs
    return lhs
}


/// The ```~>``` infix operator routes the result of your asynchronous operation
/// to a completion handler that is executed on the global concurrent background queue.
///
/// -e.g.: ```handler~>(param: nil) ~> { result in ... }```
public func ~><I, O>(lhs: __BriskRoutingObjNonVoid<I, O>, rhs: (O -> Void)) {
    if lhs.handlerQueue == nil { lhs.handlerQueue = backgroundQueue }
    lhs.processAsyncHandler(rhs)
}

/// The ```+>``` infix operator routes the result of your asynchronous operation
/// to a completion handler that is executed on the main queue.
///
/// -e.g.: ```handler~>(param: nil) +> { result in ... }```
public func +><I, O>(lhs: __BriskRoutingObjNonVoid<I, O>, rhs: (O -> Void)) {
    lhs.handlerQueue = mainQueue
    lhs.processAsyncHandler(rhs)
}







