//
//  BriskAsync2Sync.swift
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

// let .. = <<-{ func(i, handler: $0) }              call func on current queue
// let .. = <<~{ func(i, handler: $0) }              call func on bg queue
// let .. = <<+{ func(i, handler: $0) }              call func on main queue
// let .. = <<~myQueue ~~~ { func(i, handler: $0) }   call func on specified queue

prefix operator <<-
prefix operator <<~
prefix operator <<+

/* -- old precendence = 95 -- */
precedencegroup QueueRedirectionPrecendence {
    higherThan: AssignmentPrecedence
    lowerThan:  TernaryPrecedence
}

infix  operator ~~~ : QueueRedirectionPrecendence


/// Returns the queue this prefix is applied to.  This is used to prettify the
/// syntax:
///
/// - e.g.: let x = <<~myQueue ~~~ { func(i, handler: $0) }
@inline(__always) public prefix func <<~(q: DispatchQueue) -> DispatchQueue {
    return q
}

/// Executes the attached operation synchronously on the current queue
/// and waits for it to complete.  Returns the result of the callback handler that
/// $0 was attached to.
///
/// - e.g.: ```let x = <<-{ func(i, callback: $0)``` }
public prefix func <<-<O>(operation: (_ callbackHandler: @escaping (_ param: O) -> Void) -> Void) -> O {
    
    // Our gating mechanism
    let gate = BriskGate()
    
    // This value will eventually hold the response from the async function
    var handledResponse: O?
    
    let theHandler: (_ p: O) -> Void = { responseFromCallback in
        handledResponse = responseFromCallback
        gate.signal()
    }
    
    operation(theHandler)
    gate.wait()
    
    // It's ok to use ! -- theoretically we are garanteed that handledResponse
    // has been set by this point (inside theHandler)
    return handledResponse!
}

/// This protects against optional functions being placed inside a sync-to-async block.
public prefix func <<-<O>(operation: @escaping (_ callbackHandler: @escaping (_ param: O) -> Void) -> Void?) -> O {
    fatalError("You cannot put an optional call inside of a brisk sync-to-async block, since it must be guaranteed to call and return.")
}


/// Using a generic handler for the non-noescape versions
@inline(__always) private func processAsync2Sync<O>(_ operation: @escaping (_ callbackHandler: @escaping (_ param: O) -> Void) -> Void,
                                                          queue: DispatchQueue) -> O {
    
    // Our gating mechanism
    let gate = BriskGate()
    
    // This value will eventually hold the response from the async function
    var handledResponse: O?
    
    let theHandler: (_ p: O) -> Void = { responseFromCallback in
        handledResponse = responseFromCallback
        gate.signal()
    }
    
    queue.async {
        operation(theHandler)
    }
    
    gate.wait()
    
    // It's ok to use ! -- theoretically we are garanteed that handledResponse
    // has been set by this point (inside theHandler)
    return handledResponse!
}


/// Executes the attached operation on the general concurrent background queue
/// and waits for it to complete.  Returns the result of the callback handler that
/// $0 was attached to.
///
/// - e.g.: ```let x = <<~{ func(i, callback: $0)``` }
public prefix func <<~<O>(operation: @escaping (_ callbackHandler: @escaping (_ param: O) -> Void) -> Void) -> O {
    return processAsync2Sync(operation, queue: backgroundQueue)
}

/// This protects against optional functions being placed inside a sync-to-async block.
public prefix func <<~<O>(operation: @escaping (_ callbackHandler: @escaping (_ param: O) -> Void) -> Void?) -> O {
    fatalError("You cannot put an optional call inside of a brisk sync-to-async block, since it must be guaranteed to call and return.")
}

/// Executes the attached operation on the main queue
/// and waits for it to complete.  Returns the result of the callback handler that
/// $0 was attached to.
///
/// - e.g.: ```let x = <<+{ func(i, callback: $0)``` }
public prefix func <<+<O>(operation: @escaping (_ callbackHandler: @escaping (_ param: O) -> Void) -> Void) -> O {
    return processAsync2Sync(operation, queue: mainQueue)
}

/// This protects against optional functions being placed inside a sync-to-async block.
public prefix func <<+<O>(operation: @escaping (_ callbackHandler: @escaping (_ param: O) -> Void) -> Void?) -> O {
    fatalError("You cannot put an optional call inside of a brisk sync-to-async block, since it must be guaranteed to call and return.")
}


/// Executes the attached operation on the supplied queue from the left side
/// and waits for it to complete.  Returns the result of the callback handler that
/// $0 was attached to.
///
/// - e.g.: ```let x = <<~myQueue ~~~ { func(i, callback: $0)``` }
public func ~~~<O>(lhs: DispatchQueue, rhs: @escaping (_ callbackHandler: @escaping (_ param: O) -> Void) -> Void) -> O {
    return processAsync2Sync(rhs, queue: lhs)
}

/// This protects against optional functions being placed inside a sync-to-async block.
public func ~~~<O>(lhs: DispatchQueue, rhs: @escaping (_ callbackHandler: @escaping (_ param: O) -> Void) -> Void?) -> O {
    fatalError("You cannot put an optional call inside of a brisk sync-to-async block, since it must be guaranteed to call and return.")
}


