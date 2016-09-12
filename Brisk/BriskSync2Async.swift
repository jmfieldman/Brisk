//
//  BriskSync2Async.swift
//  Brisk
//
//  Copyright (c) 2016-Present Jason Fieldman - https://github.com/jmfieldman/Brisk
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation




// MARK: - Routing Object


public class __BriskRoutingObj<I, O> {
    
    // ---------- Properties ----------
    
    // The dispatch group used in various synchronizing routines
    fileprivate let dispatchGroup = DispatchGroup()
    
    // This is the actual function that we are routing
    fileprivate let wrappedFunction: (I) -> O
    
    // If we are routing the response, this catches the value
    fileprivate var response: O? = nil
    
    // This is the queue that the function will be executed on
    fileprivate var opQueue: DispatchQueue? = nil
    
    // This is the queue that the handler will execute on (if needed)
    fileprivate var handlerQueue: DispatchQueue? = nil
    
    // The lock used to synchronize various accesses
    fileprivate var lock: NSLock = NSLock()
    
    // Is this routing object available to perform its operation?
    // The routing objects may only perform their operations once, they should
    // NOT be retained and called a second time.
    fileprivate var operated: Bool = false
    
    
    
    // ---------- Init ------------
    
    // Instantiate ourselves with a function
    fileprivate init(function: @escaping (I) -> O, defaultOpQueue: DispatchQueue? = nil) {
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
    @inline(__always) public func on(_ queue: DispatchQueue) -> __BriskRoutingObj<I, O> {
        self.opQueue = queue
        return self
    }
 
    
    
    // ----------- Execution -------------
    
    
    /// The sync property returns a function with the same input/output
    /// parameters of the original function.  It is executed asynchronously
    /// on the specified queue.  The calling thread is blocked until the
    /// called function completes.  Not compatible with functions that throw
    /// errors.
    public var sync: (I) -> O {
        guard let opQ = opQueue else {
            brisk_raise("You must specify a queue for this function to operate on")
        }
        
        // If we're synchronous on the main thread already, just run the function immediately.
        if opQ === mainQueue && Thread.current.isMainThread {
            return { i in
                return self.wrappedFunction(i)
            }
        }
                
        guard !synchronized(lock, block: { let o = self.operated; self.operated = false; return o }) else {
            brisk_raise("You may not retain or use this routing object in a way that it can be executed more than once.")
        }
        
        return { i in
            self.dispatchGroup.enter()
            opQ.async {
                self.response = self.wrappedFunction(i)
                self.dispatchGroup.leave()
            }
            _ = self.dispatchGroup.wait(timeout: DispatchTime.distantFuture)
            return self.response! // Will be set in the async call above
        }
    }
    
    
    /// Processes the async handler applied to this routing object.
    fileprivate func processAsyncHandler(_ handler: @escaping (O) -> Void) {
        guard let hQ = self.handlerQueue else {
            brisk_raise("The handler queue was not specified before routing the async response")
        }
        
        backgroundQueue.async {
            _ = self.dispatchGroup.wait(timeout: DispatchTime.distantFuture)
            hQ.async {
                handler(self.response!) // Will be set in the async call before wait completes
            }
        }
    }
}


public final class __BriskRoutingObjVoid<I>: __BriskRoutingObj<I, Void> {
    
    // Instantiate ourselves with a function
    override fileprivate init(function: @escaping (I) -> Void, defaultOpQueue: DispatchQueue? = nil) {
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
    public var async: (I) -> Void {
        guard let opQ = opQueue else {
            brisk_raise("You must specify a queue for this function to operate on")
        }
        
        guard !synchronized(lock, block: { let o = self.operated; self.operated = false; return o }) else {
            brisk_raise("You may not retain or use this routing object in a way that it can be executed more than once.")
        }
        
        return { i in
            self.dispatchGroup.enter()
            opQ.async {
                self.response = self.wrappedFunction(i)
                self.dispatchGroup.leave()
            }
        }
    }
}

public final class __BriskRoutingObjNonVoid<I, O>: __BriskRoutingObj<I, O> {
    
    // Instantiate ourselves with a function
    override fileprivate init(function: @escaping (I) -> O, defaultOpQueue: DispatchQueue? = nil) {
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
    public var async: (I) -> __BriskRoutingObjNonVoid<I, O> {
        guard let opQ = opQueue else {
            brisk_raise("You must specify a queue for this function to operate on")
        }
        
        guard !synchronized(lock, block: { let o = self.operated; self.operated = false; return o }) else {
            brisk_raise("You may not retain or use this routing object in a way that it can be executed more than once.")
        }
        
        return { i in
            self.dispatchGroup.enter()
            opQ.async {
                self.response = self.wrappedFunction(i)
                self.dispatchGroup.leave()
            }
            return self
        }
    }
}



// MARK: - Operators

postfix operator ->>
postfix operator ~>>
postfix operator +>>

postfix operator ?->>
postfix operator ?~>>
postfix operator ?+>>


/// The ```->>``` postfix operator generates an internal routing object that
/// requires you to specify the operation queue.  An example of this
/// would be:
///
/// ```handler->>.main.async(result: nil)```
@inline(__always) public postfix func ->><I>(function: @escaping (I) -> Void) -> __BriskRoutingObjVoid<I> {
    return __BriskRoutingObjVoid(function: function)
}

/// The ```->>``` postfix operator generates an internal routing object that
/// requires you to specify the operation queue.  An example of this
/// would be:
///
/// ```handler->>.main.async(result: nil)```
@inline(__always) public postfix func ->><I, O>(function: @escaping (I) -> O) -> __BriskRoutingObjNonVoid<I,O> {
    return __BriskRoutingObjNonVoid(function: function)
}

/// The ```->>``` postfix operator generates an internal routing object that
/// requires you to specify the operation queue.  An example of this
/// would be:
///
/// ```handler->>.main.async(result: nil)```
@inline(__always) public postfix func ?->><I>(function: ((I) -> Void)?) -> __BriskRoutingObjVoid<I>? {
    return (function == nil) ? nil : __BriskRoutingObjVoid(function: function!)
}

/// The ```->>``` postfix operator generates an internal routing object that
/// requires you to specify the operation queue.  An example of this
/// would be:
///
/// ```handler->>.main.async(result: nil)```
@inline(__always) public postfix func ?->><I, O>(function: ((I) -> O)?) -> __BriskRoutingObjNonVoid<I,O>? {
    return (function == nil) ? nil : __BriskRoutingObjNonVoid(function: function!)
}




/// The ```~>>``` postfix operator generates an internal routing object that
/// defaults to the concurrent background queue.  An example of this
/// would be:
///
/// ```handler~>>.async(result: nil)```
@inline(__always) public postfix func ~>><I>(function: @escaping (I) -> Void) -> __BriskRoutingObjVoid<I> {
    return __BriskRoutingObjVoid(function: function, defaultOpQueue: backgroundQueue)
}

/// The ```~>>``` postfix operator generates an internal routing object that
/// defaults to the concurrent background queue.  An example of this
/// would be:
///
/// ```handler~>>.async(result: nil)```
@inline(__always) public postfix func ~>><I, O>(function: @escaping (I) -> O) -> __BriskRoutingObjNonVoid<I,O> {
    return __BriskRoutingObjNonVoid(function: function, defaultOpQueue: backgroundQueue)
}

/// The ```~>>``` postfix operator generates an internal routing object that
/// defaults to the concurrent background queue.  An example of this
/// would be:
///
/// ```handler~>>.async(result: nil)```
@inline(__always) public postfix func ?~>><I>(function: ((I) -> Void)?) -> __BriskRoutingObjVoid<I>? {
    return (function == nil) ? nil : __BriskRoutingObjVoid(function: function!, defaultOpQueue: backgroundQueue)
}

/// The ```~>>``` postfix operator generates an internal routing object that
/// defaults to the concurrent background queue.  An example of this
/// would be:
///
/// ```handler~>>.async(result: nil)```
@inline(__always) public postfix func ?~>><I, O>(function: ((I) -> O)?) -> __BriskRoutingObjNonVoid<I,O>? {
    return (function == nil) ? nil : __BriskRoutingObjNonVoid(function: function!, defaultOpQueue: backgroundQueue)
}




/// The ```+>>``` postfix operator generates an internal routing object that
/// defaults to the main queue.  An example of this would be:
///
/// ```handler+>>.async(result: nil)```
@inline(__always) public postfix func +>><I>(function: @escaping (I) -> Void) -> __BriskRoutingObjVoid<I> {
    return __BriskRoutingObjVoid(function: function, defaultOpQueue: mainQueue)
}

/// The ```+>>``` postfix operator generates an internal routing object that
/// defaults to the main queue.  An example of this would be:
///
/// ```handler+>>.async(result: nil)```
@inline(__always) public postfix func +>><I, O>(function: @escaping (I) -> O) -> __BriskRoutingObjNonVoid<I,O> {
    return __BriskRoutingObjNonVoid(function: function, defaultOpQueue: mainQueue)
}

/// The ```+>>``` postfix operator generates an internal routing object that
/// defaults to the main queue.  An example of this would be:
///
/// ```handler+>>.async(result: nil)```
@inline(__always) public postfix func ?+>><I>(function: ((I) -> Void)?) -> __BriskRoutingObjVoid<I>? {
    return (function == nil) ? nil : __BriskRoutingObjVoid(function: function!, defaultOpQueue: mainQueue)
}

/// The ```+>>``` postfix operator generates an internal routing object that
/// defaults to the main queue.  An example of this would be:
///
/// ```handler+>>.async(result: nil)```
@inline(__always) public postfix func ?+>><I, O>(function: ((I) -> O)?) -> __BriskRoutingObjNonVoid<I,O>? {
    return (function == nil) ? nil : __BriskRoutingObjNonVoid(function: function!, defaultOpQueue: mainQueue)
}


/* -- old precendence = 140 -- */
precedencegroup AsyncRedirectPrecendence {
    higherThan: RangeFormationPrecedence
    lowerThan:  MultiplicationPrecedence
    associativity: left
}

infix operator +>>  : AsyncRedirectPrecendence
infix operator ~>>  : AsyncRedirectPrecendence
infix operator ?+>> : AsyncRedirectPrecendence
infix operator ?~>> : AsyncRedirectPrecendence


/// The ```~>>``` infix operator allows for shorthand creation of a routing object
/// that operates asynchronously on the global concurrent background queue.
///
/// - e.g.: ```handler~>>(param: nil)```
public func ~>><I>(lhs: @escaping (I) -> Void, rhs: I) -> Void {
    return __BriskRoutingObjVoid(function: lhs, defaultOpQueue: backgroundQueue).async(rhs)
}

/// The ```~>>``` infix operator allows for shorthand creation of a routing object
/// that operates asynchronously on the global concurrent background queue.
///
/// - e.g.: ```handler~>>(param: nil)```
@discardableResult public func ~>><I, O>(lhs: @escaping (I) -> O, rhs: I) -> __BriskRoutingObjNonVoid<I, O> {
    return __BriskRoutingObjNonVoid(function: lhs, defaultOpQueue: backgroundQueue).async(rhs)
}

/// The ```~>>``` infix operator allows for shorthand execution of the wrapped function
/// on its defined operation queue.
///
/// - e.g.: ```handler~>>(param: nil)```
public func ~>><I>(lhs: __BriskRoutingObjVoid<I>, rhs: I) -> Void {
    return lhs.async(rhs)
}

/// The ```~>>``` infix operator allows for shorthand execution of the wrapped function
/// on its defined operation queue.
///
/// - e.g.: ```handler~>>(param: nil)```
@discardableResult public func ~>><I, O>(lhs: __BriskRoutingObjNonVoid<I, O>, rhs: I) -> __BriskRoutingObjNonVoid<I, O> {
    return lhs.async(rhs)
}



/// The ```~>>``` infix operator allows for shorthand creation of a routing object
/// that operates asynchronously on the global concurrent background queue.
///
/// - e.g.: ```handler~>>(param: nil)```
public func ?~>><I>(lhs: ((I) -> Void)?, rhs: I) -> Void {
    if let lhs = lhs { __BriskRoutingObjVoid(function: lhs, defaultOpQueue: backgroundQueue).async(rhs) }
}

/// The ```~>>``` infix operator allows for shorthand creation of a routing object
/// that operates asynchronously on the global concurrent background queue.
///
/// - e.g.: ```handler~>>(param: nil)```
@discardableResult public func ?~>><I, O>(lhs: ((I) -> O)?, rhs: I) -> __BriskRoutingObjNonVoid<I, O>? {
    return (lhs == nil) ? nil : __BriskRoutingObjNonVoid(function: lhs!, defaultOpQueue: backgroundQueue).async(rhs)
}

/// The ```~>>``` infix operator allows for shorthand execution of the wrapped function
/// on its defined operation queue.
///
/// - e.g.: ```handler~>>(param: nil)```
public func ?~>><I>(lhs: __BriskRoutingObjVoid<I>?, rhs: I) -> Void {
    lhs?.async(rhs)
}

/// The ```~>>``` infix operator allows for shorthand execution of the wrapped function
/// on its defined operation queue.
///
/// - e.g.: ```handler~>>(param: nil)```
@discardableResult public func ?~>><I, O>(lhs: __BriskRoutingObjNonVoid<I, O>?, rhs: I) -> __BriskRoutingObjNonVoid<I, O>? {
    return lhs?.async(rhs)
}





/// The ```+>>``` infix operator allows for shorthand creation of a routing object
/// that operates asynchronously on the main queue.
///
/// - e.g.: ```handler+>>(param: nil)```
public func +>><I>(lhs: @escaping (I) -> Void, rhs: I) -> Void {
    return __BriskRoutingObjVoid(function: lhs, defaultOpQueue: mainQueue).async(rhs)
}

/// The ```+>>``` infix operator allows for shorthand creation of a routing object
/// that operates asynchronously on the main queue.
///
/// - e.g.: ```handler+>>(param: nil)```
@discardableResult public func +>><I, O>(lhs: @escaping (I) -> O, rhs: I) -> __BriskRoutingObjNonVoid<I, O> {
    return __BriskRoutingObjNonVoid(function: lhs, defaultOpQueue: mainQueue).async(rhs)
}

/// The ```+>>``` infix operator allows for shorthand creation of a routing object
/// that operates asynchronously on the main queue.
///
/// - e.g.: ```handler+>>(param: nil)```
public func ?+>><I>(lhs: ((I) -> Void)?, rhs: I) -> Void {
    if let lhs = lhs { __BriskRoutingObjVoid(function: lhs, defaultOpQueue: mainQueue).async(rhs) }
}

/// The ```+>>``` infix operator allows for shorthand creation of a routing object
/// that operates asynchronously on the main queue.
///
/// - e.g.: ```handler+>>(param: nil)```
@discardableResult public func ?+>><I, O>(lhs: ((I) -> O)?, rhs: I) -> __BriskRoutingObjNonVoid<I, O>? {
    return (lhs == nil) ? nil : __BriskRoutingObjNonVoid(function: lhs!, defaultOpQueue: mainQueue).async(rhs)
}





/// The special ```~>>``` infix operator between a function and a queue creates a
/// routing object that will call its operation on that queue.
///
/// - e.g.: ```handler +>> (param: nil) ~>> myQueue ~>> { result in ... }```
/// - e.g.: ```handler ~>> myQueue ~>> (param: nil) ~>> myOtherQueue ~>> { result in ... }```
public func ~>><I>(lhs: @escaping (I) -> Void, rhs: DispatchQueue) -> __BriskRoutingObjVoid<I> {
    return __BriskRoutingObjVoid(function: lhs, defaultOpQueue: rhs)
}

/// The special ```~>>``` infix operator between a function and a queue creates a
/// routing object that will call its operation on that queue.
///
/// - e.g.: ```handler +>> (param: nil) ~>> myQueue ~>> { result in ... }```
/// - e.g.: ```handler ~>> myQueue ~>> (param: nil) ~>> myOtherQueue ~>> { result in ... }```
public func ~>><I, O>(lhs: @escaping (I) -> O, rhs: DispatchQueue) -> __BriskRoutingObjNonVoid<I, O> {
    return __BriskRoutingObjNonVoid(function: lhs, defaultOpQueue: rhs)
}

/// The special ```~>>``` infix operator allows you to specify the queues for the
/// routing operations.  This sets the initial operation queue if it hasn't already
/// been defined by on().  If the initial operation queue has already been defined,
/// this sets the response handler queue.
///
/// - e.g.: ```handler +>> (param: nil) ~>> myQueue ~>> { result in ... }```
/// - e.g.: ```handler ~>> myQueue ~>> (param: nil) ~>> myOtherQueue ~>> { result in ... }```
public func ~>><I, O>(lhs: __BriskRoutingObjNonVoid<I, O>, rhs: DispatchQueue) -> __BriskRoutingObjNonVoid<I, O> {
    lhs.handlerQueue = rhs
    return lhs
}

/// The special ```~>>``` infix operator between a function and a queue creates a
/// routing object that will call its operation on that queue.
///
/// - e.g.: ```handler +>> (param: nil) ~>> myQueue ~>> { result in ... }```
/// - e.g.: ```handler ~>> myQueue ~>> (param: nil) ~>> myOtherQueue ~>> { result in ... }```
public func ?~>><I>(lhs: ((I) -> Void)?, rhs: DispatchQueue) -> __BriskRoutingObjVoid<I>? {
    return (lhs == nil) ? nil : __BriskRoutingObjVoid(function: lhs!, defaultOpQueue: rhs)
}

/// The special ```~>>``` infix operator between a function and a queue creates a
/// routing object that will call its operation on that queue.
///
/// - e.g.: ```handler +>> (param: nil) ~>> myQueue ~>> { result in ... }```
/// - e.g.: ```handler ~>> myQueue ~>> (param: nil) ~>> myOtherQueue ~>> { result in ... }```
public func ?~>><I, O>(lhs: ((I) -> O)?, rhs: DispatchQueue) -> __BriskRoutingObjNonVoid<I, O>? {
    return (lhs == nil) ? nil : __BriskRoutingObjNonVoid(function: lhs!, defaultOpQueue: rhs)
}

/// The special ```~>>``` infix operator allows you to specify the queues for the
/// routing operations.  This sets the initial operation queue if it hasn't already
/// been defined by on().  If the initial operation queue has already been defined,
/// this sets the response handler queue.
///
/// - e.g.: ```handler +>> (param: nil) ~>> myQueue ~>> { result in ... }```
/// - e.g.: ```handler ~>> myQueue ~>> (param: nil) ~>> myOtherQueue ~>> { result in ... }```
public func ~>><I, O>(lhs: __BriskRoutingObjNonVoid<I, O>?, rhs: DispatchQueue) -> __BriskRoutingObjNonVoid<I, O>? {
    lhs?.handlerQueue = rhs
    return lhs
}




/// The ```~>>``` infix operator routes the result of your asynchronous operation
/// to a completion handler that is executed on the predefined queue, or the global
/// concurrent background queue by default if none was specified.
///
/// -e.g.: ```handler~>>(param: nil) ~>> { result in ... }```
public func ~>><I, O>(lhs: __BriskRoutingObjNonVoid<I, O>, rhs: @escaping (O) -> Void) {
    if lhs.handlerQueue == nil { lhs.handlerQueue = backgroundQueue }
    lhs.processAsyncHandler(rhs)
}

/// The ```+>>``` infix operator routes the result of your asynchronous operation
/// to a completion handler that is executed on the main queue.
///
/// -e.g.: ```handler~>>(param: nil) +>> { result in ... }```
public func +>><I, O>(lhs: __BriskRoutingObjNonVoid<I, O>, rhs: @escaping (O) -> Void) {
    lhs.handlerQueue = mainQueue
    lhs.processAsyncHandler(rhs)
}

/// The ```~>>``` infix operator routes the result of your asynchronous operation
/// to a completion handler that is executed on the predefined queue, or the global
/// concurrent background queue by default if none was specified.
///
/// -e.g.: ```handler~>>(param: nil) ~>> { result in ... }```
public func ~>><I, O>(lhs: __BriskRoutingObjNonVoid<I, O>?, rhs: @escaping (O) -> Void) {
    if let lhs = lhs {
        if lhs.handlerQueue == nil { lhs.handlerQueue = backgroundQueue }
        lhs.processAsyncHandler(rhs)
    }
}

/// The ```+>>``` infix operator routes the result of your asynchronous operation
/// to a completion handler that is executed on the main queue.
///
/// -e.g.: ```handler~>>(param: nil) +>> { result in ... }```
public func +>><I, O>(lhs: __BriskRoutingObjNonVoid<I, O>?, rhs: @escaping (O) -> Void) {
    lhs?.handlerQueue = mainQueue
    lhs?.processAsyncHandler(rhs)
}






