//
//  BriskGCD.swift
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




/// The leeway granted for inexact timers.
private let kInexactTimerLeeway = UInt64(0.01 * Double(NSEC_PER_SEC))


// MARK: - Dispatch Helpers


/// Execute a block asynchronously on the main dispatch queue
///
/// - parameter block: The block to execute.
@inline(__always) public func dispatch_main_async(_ block: @escaping () -> ()) {
    
    mainQueue.async(execute: block)
}


/// Execute a block asynchronously on the generic concurrent background queue.
///
/// - parameter block: The block to execute.
@inline(__always) public func dispatch_bg_async(_ block: @escaping () -> ()) {
    
    backgroundQueue.async(execute: block)
}


// Data Structures for dispatch_async
private var queueForId: [String : DispatchQueue] = [:]
private var queueLock:   NSLock                     = NSLock()

/// Executes a block on an ad-hoc named serial dispatch queue.  If a queue was already created
/// with the provided name, it is reused.  This allows you to dispatch code on serial queues
/// whose uniqueness is identified by a string, rather than a pre-allocated queue instance.
/// - note: This is a more a convenience feature than a recommended practice.  It is generally
///         safer from a coding perspective to use a pre-instantiated queue variable.
public func dispatch_async(_ queueName: String, block: @escaping () -> ()) {
    
    if let queue: DispatchQueue = synchronized(queueLock, block: { return queueForId[queueName] }) {
        queue.async(execute: block)
        return
    }
    
    synchronized(queueLock) {
        let queue = DispatchQueue(label: queueName, attributes: [])
        queueForId[queueName] = queue
        queue.async(execute: block)
    }
}


/// Execute a block synchronously on the main dispatch queue.  If called
/// from the main queue, the block is executed immediately.
///
/// - parameter block: The block to execute.
@inline(__always) public func dispatch_main_sync(_ block: () -> ())  {
    
    if Thread.current.isMainThread {
        block()
    } else {
        mainQueue.sync(execute: block)
    }
}


/// Dispatch a block asynchronously on a dispatch queue after a certain time interval.
/// The dispatch timer will use the standard leeway (non-exact).
///
/// - parameter after: The time to wait before running the block asynchronously.
/// - parameter block: The block to execute.
@inline(__always) public func dispatch_after(_ seconds: TimeInterval,
                                             _ onQueue: DispatchQueue,
                                               _ block: @escaping () -> ()) {
    
    onQueue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(seconds * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: block)
}


/// Dispatch a block asynchronously on a dispatch queue after a certain time interval.
/// The dispatch timer will use 0 leeway to make the timing as exact as possible.  This is used
/// mainly for animation or other activities that require exact timing.
///
///  - parameter after: The time to wait before running the block asynchronously.
///  - parameter block: The block to execute.
@inline(__always) public func dispatch_after_exactly(_ seconds: TimeInterval,
                                                     _ onQueue: DispatchQueue,
                                                       _ block: @escaping (() -> ())) {
    
    let timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: UInt(0)), queue: onQueue)
    timer.setEventHandler {
        block()
    }
    
    timer.scheduleOneshot(deadline: DispatchTime.now() + seconds, leeway: DispatchTimeInterval.microseconds(0))
    timer.resume()
}


/// Dispatch a block every interval on the given queue.  You stop the timer by calling
/// dispatch_source_cancel on the returned timer.
///
/// - parameter interval: The interval to call the block.
/// - parameter onQueue:  The queue to call the block on.
/// - parameter block:    The block to execute.
///
/// - returns: The dispatch_source_t that represents the timer.
///            You must eventually cancel this with dispatch_source_cancel()
@discardableResult @inline(__always) public func dispatch_every(_ interval: TimeInterval,
                                                                 _ onQueue: DispatchQueue,
                                                                   _ block: @escaping ((DispatchSourceTimer) -> ())) -> DispatchSourceTimer {
    
    let timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: UInt(0)), queue: onQueue)
    timer.setEventHandler {
        block(timer)
    }
    
    timer.scheduleRepeating(deadline: DispatchTime.now() + interval, interval: interval)
    timer.resume()
    return timer
}


/// Dispatch a block every interval on the given queue.  You stop the timer by calling
/// dispatch_source_cancel on the returned timer.
///
/// This function uses the most exact timing possible the timer.
///
/// - parameter interval: The interval to call the block.
/// - parameter onQueue:  The queue to call the block on.
/// - parameter block:    The block to execute.
///
/// - returns: The dispatch_source_t that represents the timer.
///            You must eventually cancel this with dispatch_source_cancel()
@discardableResult @inline(__always) public func dispatch_every_exact(_ interval: TimeInterval,
                                                                       _ onQueue: DispatchQueue,
                                                                         _ block: @escaping ((DispatchSourceTimer) -> ())) -> DispatchSourceTimer {
    
    let timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: UInt(0)), queue: onQueue)
    timer.setEventHandler {
        block(timer as! DispatchSource)
    }
    
    timer.scheduleRepeating(deadline: DispatchTime.now() + interval, interval: interval, leeway: DispatchTimeInterval.microseconds(0))
    timer.resume()
    return timer as! DispatchSource
}


/// Dispatch a block asynchronously on the main dispatch queue after a certain time interval.
/// The dispatch timer will use the standard leeway (non-exact).
///
/// - parameter after: The time to wait before running the block asynchronously.
/// - parameter block: The block to execute.
@inline(__always) public func dispatch_main_after(_ seconds: TimeInterval,
                                                    _ block: @escaping () -> ()) {
    
    dispatch_after(seconds, mainQueue, block)
}


/// Dispatch a block asynchronously on the main dispatch queue after a certain time interval.
/// The dispatch timer will use 0 leeway to make the timing as exact as possible.  This is used
/// mainly for animation or other activities that require exact timing.
///
/// - parameter after: The time to wait before running the block asynchronously.
/// - parameter block: The block to execute.
@inline(__always) public func dispatch_main_after_exactly(_ seconds: TimeInterval,
                                                            _ block: @escaping (() -> ())) {
    
    dispatch_after_exactly(seconds, mainQueue, block)
}


/// Dispatch a block every interval on the main queue.  You stop the timer by calling
/// dispatch_source_cancel on the returned timer.
///
/// - parameter interval: The interval to call the block.
/// - parameter block:    The block to execute.
///
/// - returns: The dispatch_source_t that represents the timer.
///            You must eventually cancel this with dispatch_source_cancel()
@discardableResult @inline(__always) public func dispatch_main_every(_ interval: TimeInterval,
                                                                        _ block: @escaping ((DispatchSourceTimer) -> ())) -> DispatchSourceTimer {
    
    return dispatch_every(interval, DispatchQueue.main, block)
}


/// Dispatch a block every interval on the main queue.  You stop the timer by calling
/// dispatch_source_cancel on the returned timer.
///
/// This function uses the most exact timing possible on the timer.
///
/// - parameter interval: The interval to call the block.
/// - parameter block:    The block to execute.
///
/// - returns: The dispatch_source_t that represents the timer.
///            You must eventually cancel this with dispatch_source_cancel()
@discardableResult @inline(__always) public func dispatch_main_every_exact(_ interval: TimeInterval,
                                                                              _ block: @escaping ((DispatchSourceTimer) -> ())) -> DispatchSourceTimer {
    
    return dispatch_every_exact(interval, DispatchQueue.main, block)
}



// Data Structures for dispatch_once_after
private var operationTimerForId: [String : DispatchSourceTimer] = [:]
private var operationTimerLock:   NSLock                        = NSLock()

/// Queue up an action to take place on an queue in the future, but make sure it only triggers once.
/// This allows you to queue up the same operation several times and not worry about
/// it being called multiple times later.
public func dispatch_once_after(_ after: TimeInterval,
                            operationId: String,
                          onQueue queue: DispatchQueue,
                                  block: @escaping () -> ()) {
    
    // Check if we already have a timer source for this operation ID
    if let existingTimer: DispatchSourceTimer = synchronized(operationTimerLock, block: { return operationTimerForId[operationId] }) {
        existingTimer.scheduleOneshot(deadline: DispatchTime.now() + after)        
        return
    }
    
    // Timer doesn't exist, we have to make one!
    let timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: UInt(0)), queue: queue)
    timer.setEventHandler {
        
        // one shot timer -- remove from dictionary
        synchronized(operationTimerLock) {
            operationTimerForId.removeValue(forKey: operationId)
            timer.cancel()
        }
        block()
    }
    
    // Set it!
    synchronized(operationTimerLock) { operationTimerForId[operationId] = timer }
    timer.scheduleOneshot(deadline: DispatchTime.now() + after)
    timer.resume()
}


/// Queue up an action to take place on the main queue in the future, but make sure it only triggers once.
/// This allows you to queue up the same operation several times and not worry about
/// it being called multiple times later.
public func dispatch_main_once_after(_ after: TimeInterval,
                                 operationId: String,
                                       block: @escaping () -> ()) {
    
    dispatch_once_after(after, operationId: operationId, onQueue: mainQueue, block: block)
}

/// This is a helper to take advantage of multiple cores when performing an activity in parallel on
/// multiple values in an array.
///
/// - parameter elements: An array of elements to process
/// - parameter queue:    The dispatch queue to process on (should be concurrent)
/// - parameter block:    The block to process for each element.
public func dispatch_each<T>(_ elements: [T],
                                  queue: DispatchQueue,
                                  block: (T) -> ()) {
    
    DispatchQueue.concurrentPerform(iterations: elements.count) { i in
        block(elements[i])
    }
}


