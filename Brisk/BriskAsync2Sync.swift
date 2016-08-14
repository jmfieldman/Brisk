//
//  BriskAsync2Sync.swift
//  Brisk
//
//  Created by Jason Fieldman on 8/12/16.
//  Copyright © 2016 Jason Fieldman. All rights reserved.
//

import Foundation

// let .. = <-{ func(i, handler: $0) }              call func on current queue
// let .. = <~{ func(i, handler: $0) }              call func on bg queue
// let .. = <+{ func(i, handler: $0) }              call func on main queue
// let .. = <~myQueue ~~ { func(i, handler: $0) }   call func on specified queue

prefix operator <- {}
prefix operator <~ {}
prefix operator <+ {}
infix  operator ~~ { precedence 95 }


/// Returns the queue this prefix is applied to.  This is used to prettify the
/// syntax:
///
/// - e.g.: let x = <~myQueue ~~ { func(i, handler: $0) }
@inline(__always) public prefix func <~(q: dispatch_queue_t) -> dispatch_queue_t {
    return q
}

/// Executes the attached operation synchronously on the current queue
/// and waits for it to complete.  Returns the result of the callback handler that
/// $0 was attached to.
///
/// - e.g.: ```let x = <-{ func(i, callback: $0)``` }
public prefix func <-<O>(@noescape operation: (callbackHandler: (param: O) -> ()) -> ()) -> O {
    
    // This value will eventually hold the response from the async function
    var handledResponse: O?
    
    // This is the async group we'll use to wait for a response
    let group = dispatch_group_create()
    
    let theHandler: (p: O) -> () = { responseFromCallback in
        handledResponse = responseFromCallback
        dispatch_group_leave(group)
    }
    
    dispatch_group_enter(group)
    operation(callbackHandler: theHandler)
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
    
    // It's ok to use ! -- theoretically we are garanteed that handledResponse
    // has been set by this point (inside theHandler)
    return handledResponse!
}

/// Using a generic handler for the non-noescape versions
@inline(__always) private func processAsync2Sync<O>(operation: (callbackHandler: (param: O) -> ()) -> (),
                                                        queue: dispatch_queue_t) -> O {
    
    // This value will eventually hold the response from the async function
    var handledResponse: O?
    
    // This is the async group we'll use to wait for a response
    let group = dispatch_group_create()
    
    let theHandler: (p: O) -> () = { responseFromCallback in
        handledResponse = responseFromCallback
        dispatch_group_leave(group)
    }
    
    dispatch_group_enter(group)
    
    dispatch_async(queue) {
        operation(callbackHandler: theHandler)
    }
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
    
    // It's ok to use ! -- theoretically we are garanteed that handledResponse
    // has been set by this point (inside theHandler)
    return handledResponse!
}


/// Executes the attached operation on the general concurrent background queue
/// and waits for it to complete.  Returns the result of the callback handler that
/// $0 was attached to.
///
/// - e.g.: ```let x = <~{ func(i, callback: $0)``` }
public prefix func <~<O>(operation: (callbackHandler: (param: O) -> ()) -> ()) -> O {
    return processAsync2Sync(operation, queue: backgroundQueue)
}


/// Executes the attached operation on the main queue
/// and waits for it to complete.  Returns the result of the callback handler that
/// $0 was attached to.
///
/// - e.g.: ```let x = <+{ func(i, callback: $0)``` }
public prefix func <+<O>(operation: (callbackHandler: (param: O) -> ()) -> ()) -> O {
    return processAsync2Sync(operation, queue: mainQueue)
}


/// Executes the attached operation on the supplied queue from the left side
/// and waits for it to complete.  Returns the result of the callback handler that
/// $0 was attached to.
///
/// - e.g.: ```let x = <~myQueue ~~ { func(i, callback: $0)``` }
public func ~~<O>(lhs: dispatch_queue_t, rhs: (callbackHandler: (param: O) -> ()) -> ()) -> O {
    return processAsync2Sync(rhs, queue: lhs)
}

