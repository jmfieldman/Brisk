//
//  BriskDispatch.swift
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


public protocol QuickDispatchTimeInterval {
    /// Returns the receiver as a DispatchTimeInterval
    func asDispatchTimeInterval() -> DispatchTimeInterval
}


extension Double: QuickDispatchTimeInterval {
    public func asDispatchTimeInterval() -> DispatchTimeInterval {
        return DispatchTimeInterval.nanoseconds(Int(self * Double(NSEC_PER_SEC)))
    }
}

extension Float: QuickDispatchTimeInterval {
    public func asDispatchTimeInterval() -> DispatchTimeInterval {
        return DispatchTimeInterval.nanoseconds(Int(Double(self) * Double(NSEC_PER_SEC)))
    }
}

extension Int: QuickDispatchTimeInterval {
    public func asDispatchTimeInterval() -> DispatchTimeInterval {
        return DispatchTimeInterval.seconds(self)
    }
}


// Data Structures for DispatchQueue.once
private var operationTimerForId: [String : DispatchSourceTimer] = [:]
private var operationTimerLock:   NSRecursiveLock               = NSRecursiveLock()


public extension DispatchQueue {
    
    /// Dispatch a block asynchronously on the receiving queue after a period of time.  This method
    /// takes parameters that allow more straightforward and readable code.
    /// The DispatchSourceTimer is returned for reference, but can be ignored.
    ///
    /// - parameter after:      The number of seconds before the block is triggered.
    /// - parameter leeway:     The leeway, in seconds, for the timer.  This is optional and
    ///                         will use the default if unspecified.
    /// - parameter qos:        The qos to use for the executing block.
    /// - parameter flags:      The DispatchWorkItemFlags for the executing block.
    /// - parameter execute:    The block to run after the specified time on the receiving queue.
    @discardableResult public func async(after seconds: Double,
                                                leeway: QuickDispatchTimeInterval? = nil,
                                                   qos: DispatchQoS = .default,
                                                 flags: DispatchWorkItemFlags = [],
                                         execute block: @escaping () -> Void) -> DispatchSourceTimer {
    
        let timer = DispatchSource.makeTimerSource(flags: [], queue: self)
        timer.setEventHandler(qos: qos, flags: flags, handler: block)
    
        if let leeway = leeway {
            timer.scheduleOneshot(deadline: DispatchTime.now() + seconds, leeway: leeway.asDispatchTimeInterval())
        } else {
            timer.scheduleOneshot(deadline: DispatchTime.now() + seconds)
        }
        
        timer.resume()
        return timer
    }
    
    
    
    /// Dispatch a block asynchronously on the receiving queue after a period of time.  This method
    /// takes parameters that allow more straightforward and readable code.
    /// The DispatchSourceTimer is returned for reference, but can be ignored.
    ///
    /// - parameter after:      The number of seconds before the block is triggered.
    /// - parameter leeway:     The leeway, in seconds, for the timer.  This is optional and
    ///                         will use the default if unspecified.
    /// - parameter execute:    The item to execute after the specified time on the receiving queue.
    @discardableResult public func async(after seconds: Double,
                                                leeway: QuickDispatchTimeInterval? = nil,
                                          execute item: DispatchWorkItem) -> DispatchSourceTimer {
        
        let timer = DispatchSource.makeTimerSource(flags: [], queue: self)
        timer.setEventHandler(handler: item)
        
        if let leeway = leeway {
            timer.scheduleOneshot(deadline: DispatchTime.now() + seconds, leeway: leeway.asDispatchTimeInterval())
        } else {
            timer.scheduleOneshot(deadline: DispatchTime.now() + seconds)
        }
        
        timer.resume()
        return timer
    }
    
    
    
    /// Dispatch a block asynchronously on the receiving queue at a specific date.  This method
    /// takes parameters that allow more straightforward and readable code.
    /// The DispatchSourceTimer is returned for reference, but can be ignored.
    ///
    /// - parameter at:         The date to trigger the block.  If the date is before the current time
    ///                         it is triggered immediately.
    /// - parameter leeway:     The leeway, in seconds, for the timer.  This is optional and
    ///                         will use the default if unspecified.
    /// - parameter qos:        The qos to use for the executing block.
    /// - parameter flags:      The DispatchWorkItemFlags for the executing block.
    /// - parameter execute:    The block to run after the specified time on the receiving queue.
    @discardableResult public func async(at date: NSDate,
                                          leeway: QuickDispatchTimeInterval? = nil,
                                             qos: DispatchQoS = .default,
                                           flags: DispatchWorkItemFlags = [],
                                   execute block: @escaping () -> Void) -> DispatchSourceTimer {
        
        let timer = DispatchSource.makeTimerSource(flags: [], queue: self)
        timer.setEventHandler(qos: qos, flags: flags, handler: block)
        
        let timeInterval = max(date.timeIntervalSinceNow, 0)
        
        if let leeway = leeway {
            timer.scheduleOneshot(wallDeadline: DispatchWallTime.now() + timeInterval, leeway: leeway.asDispatchTimeInterval())
        } else {
            timer.scheduleOneshot(wallDeadline: DispatchWallTime.now() + timeInterval)
        }
        
        timer.resume()
        return timer
    }
    
    
    
    /// Dispatch a block asynchronously on the receiving queue at a specific date.  This method
    /// takes parameters that allow more straightforward and readable code.
    /// The DispatchSourceTimer is returned for reference, but can be ignored.
    ///
    /// - parameter at:         The date to trigger the block.  If the date is before the current time
    ///                         it is triggered immediately.
    /// - parameter leeway:     The leeway, in seconds, for the timer.  This is optional and
    ///                         will use the default if unspecified.
    /// - parameter execute:    The item to execute after the specified time on the receiving queue.
    @discardableResult public func async(at date: NSDate,
                                          leeway: QuickDispatchTimeInterval? = nil,
                                    execute item: DispatchWorkItem) -> DispatchSourceTimer {
        
        let timer = DispatchSource.makeTimerSource(flags: [], queue: self)
        timer.setEventHandler(handler: item)
        
        let deadline = DispatchWallTime.now() + max(date.timeIntervalSinceNow, 0)
        
        if let leeway = leeway {
            timer.scheduleOneshot(wallDeadline: deadline, leeway: leeway.asDispatchTimeInterval())
        } else {
            timer.scheduleOneshot(wallDeadline: deadline)
        }
        
        timer.resume()
        return timer
    }
    
    
    
    /// Dispatch a block asynchronously on the receiving queue at a specified rate.
    /// The DispatchSourceTimer is returned for reference, but can be ignored. This
    /// version of the function takes a block with no arguments.  It is considered
    /// a fatal error to pass both startingIn and startingAt parameters.  If neither
    /// startingIn or startingAt are specified, the repetition will start after
    /// one interval.
    ///
    /// - parameter every:      The interval to execute the block.
    /// - parameter startingIn: The number of seconds to begin the repetition.
    /// - parameter startingAt: The date at which to start the repetition.  If the date is
    ///                         in the past it will start immediately.
    /// - parameter leeway:     The leeway, in seconds, for the timer.  This is optional and
    ///                         will use the default if unspecified.
    /// - parameter qos:        The qos to use for the executing block.
    /// - parameter flags:      The DispatchWorkItemFlags for the executing block.
    /// - parameter execute:    The block to run after the specified time on the receiving queue.
    @discardableResult public func async(every interval: Double,
                                             startingIn: Double? = nil,
                                             startingAt: NSDate? = nil,
                                                 leeway: QuickDispatchTimeInterval? = nil,
                                                    qos: DispatchQoS = .default,
                                                  flags: DispatchWorkItemFlags = [],
                                          execute block: @escaping () -> Void) -> DispatchSourceTimer {
        
        let timer = DispatchSource.makeTimerSource(flags: [], queue: self)
        timer.setEventHandler(qos: qos, flags: flags, handler: block)
        
        guard startingIn == nil || startingAt == nil else {
            Brisk.brisk_raise("It is considered a fatal error to pass both startingIn and startingAt")
        }
        
        if let startingAt = startingAt {
            let deadline = DispatchWallTime.now() + max(startingAt.timeIntervalSinceNow, 0)
            
            if let leeway = leeway {
                timer.scheduleRepeating(wallDeadline: deadline, interval: interval, leeway: leeway.asDispatchTimeInterval())
            } else {
                timer.scheduleRepeating(wallDeadline: deadline, interval: interval)
            }
        } else {
            let deadline = DispatchTime.now() + (startingIn ?? interval)
            
            if let leeway = leeway {
                timer.scheduleRepeating(deadline: deadline, interval: interval, leeway: leeway.asDispatchTimeInterval())
            } else {
                timer.scheduleRepeating(deadline: deadline, interval: interval)
            }
        }
        
        timer.resume()
        return timer
    }
    
    
    
    /// Dispatch a block asynchronously on the receiving queue at a specified rate.
    /// The DispatchSourceTimer is returned for reference, but can be ignored. It is considered
    /// a fatal error to pass both startingIn and startingAt parameters.  If neither
    /// startingIn or startingAt are specified, the repetition will start after
    /// one interval.
    ///
    /// This version of the function takes a block with the repeating timer as an argument.
    /// You can use this parameter to cancel the repetition from inside the block.
    ///
    /// - parameter every:      The interval to execute the block.
    /// - parameter startingIn: The number of seconds to begin the repetition.
    /// - parameter startingAt: The date at which to start the repetition.  If the date is
    ///                         in the past it will start immediately.
    /// - parameter leeway:     The leeway, in seconds, for the timer.  This is optional and
    ///                         will use the default if unspecified.
    /// - parameter qos:        The qos to use for the executing block.
    /// - parameter flags:      The DispatchWorkItemFlags for the executing block.
    /// - parameter execute:    The block to run after the specified time on the receiving queue.
    @discardableResult public func async(every interval: Double,
                                             startingIn: Double? = nil,
                                             startingAt: NSDate? = nil,
                                                 leeway: QuickDispatchTimeInterval? = nil,
                                                    qos: DispatchQoS = .default,
                                                  flags: DispatchWorkItemFlags = [],
                                          execute block: @escaping (_ timer: DispatchSourceTimer) -> Void) -> DispatchSourceTimer {
        
        let timer = DispatchSource.makeTimerSource(flags: [], queue: self)
        timer.setEventHandler(qos: qos, flags: flags) {
            block(timer)
        }
        
        guard startingIn == nil || startingAt == nil else {
            Brisk.brisk_raise("It is considered a fatal error to pass both startingIn and startingAt")
        }
        
        if let startingAt = startingAt {
            let deadline = DispatchWallTime.now() + max(startingAt.timeIntervalSinceNow, 0)
            
            if let leeway = leeway {
                timer.scheduleRepeating(wallDeadline: deadline, interval: interval, leeway: leeway.asDispatchTimeInterval())
            } else {
                timer.scheduleRepeating(wallDeadline: deadline, interval: interval)
            }
        } else {
            let deadline = DispatchTime.now() + (startingIn ?? interval)
            
            if let leeway = leeway {
                timer.scheduleRepeating(deadline: deadline, interval: interval, leeway: leeway.asDispatchTimeInterval())
            } else {
                timer.scheduleRepeating(deadline: deadline, interval: interval)
            }
        }
        
        timer.resume()
        return timer
    }
    
    
    
    /// Dispatch a block asynchronously on the receiving queue at a specified rate.
    /// The DispatchSourceTimer is returned for reference, but can be ignored. This
    /// version of the function takes a block with no arguments.  It is considered
    /// a fatal error to pass both startingIn and startingAt parameters.  If neither
    /// startingIn or startingAt are specified, the repetition will start after
    /// one interval.
    ///
    /// - parameter every:      The interval to execute the block.
    /// - parameter startingIn: The number of seconds to begin the repetition.
    /// - parameter startingAt: The date at which to start the repetition.  If the date is
    ///                         in the past it will start immediately.
    /// - parameter leeway:     The leeway, in seconds, for the timer.  This is optional and
    ///                         will use the default if unspecified.
    /// - parameter qos:        The qos to use for the executing block.
    /// - parameter flags:      The DispatchWorkItemFlags for the executing block.
    /// - parameter execute:    The block to run after the specified time on the receiving queue.
    @discardableResult public func async(every interval: Double,
                                             startingIn: Double? = nil,
                                             startingAt: NSDate? = nil,
                                                 leeway: QuickDispatchTimeInterval? = nil,
                                           execute item: DispatchWorkItem) -> DispatchSourceTimer {
        
        let timer = DispatchSource.makeTimerSource(flags: [], queue: self)
        timer.setEventHandler(handler: item)
        
        guard startingIn == nil || startingAt == nil else {
            Brisk.brisk_raise("It is considered a fatal error to pass both startingIn and startingAt")
        }
        
        if let startingAt = startingAt {
            let deadline = DispatchWallTime.now() + max(startingAt.timeIntervalSinceNow, 0)
            
            if let leeway = leeway {
                timer.scheduleRepeating(wallDeadline: deadline, interval: interval, leeway: leeway.asDispatchTimeInterval())
            } else {
                timer.scheduleRepeating(wallDeadline: deadline, interval: interval)
            }
        } else {
            let deadline = DispatchTime.now() + (startingIn ?? interval)
            
            if let leeway = leeway {
                timer.scheduleRepeating(deadline: deadline, interval: interval, leeway: leeway.asDispatchTimeInterval())
            } else {
                timer.scheduleRepeating(deadline: deadline, interval: interval)
            }
        }
        
        timer.resume()
        return timer
    }
    
    
    
    /// Dispatch a block asynchronously on the receiving queue once per operationId,
    /// no matter how many times this request is made.  This is convenient way to
    /// coalesce many disparate triggers into a single finalizing block (e.g. saving
    /// a database to disk after many simultaneous async updates)
    ///
    /// Each time the function is called with an operationId that corresponds to a
    /// timer that hasn't triggered, the previous timer is canceled in favor of the
    /// new one.
    ///
    /// When a timer eventually triggers for an operationId, that operationId is cleared
    /// and is no longer associated with a timer.
    ///
    /// It is considered a fatal error to pass both after and at parameters.
    /// If neither after or at is specified, the operation is scheduled to run asap.
    ///
    /// - parameter operationId:    The ID of the operation to execute.
    /// - parameter leeway:     The leeway, in seconds, for the timer.  This is optional and
    ///                         will use the default if unspecified.
    /// - parameter startingIn: The number of seconds to begin the repetition.
    /// - parameter startingAt: The date at which to start the repetition.  If the date is
    ///                         in the past it will start immediately.
    /// - parameter qos:        The qos to use for the executing block.
    /// - parameter flags:      The DispatchWorkItemFlags for the executing block.
    /// - parameter execute:    The block to run after the specified time on the receiving queue.
    @discardableResult public func once(operationId: String,
                                     after interval: Double? = nil,
                                            at date: NSDate? = nil,
                                             leeway: QuickDispatchTimeInterval? = nil,
                                                qos: DispatchQoS = .default,
                                              flags: DispatchWorkItemFlags = [],
                                      execute block: @escaping () -> Void) -> DispatchSourceTimer {
        
        let timer = DispatchSource.makeTimerSource(flags: [], queue: self)
        timer.setEventHandler(qos: qos, flags: flags) {
            operationTimerLock.lock()
            if let curTimer = operationTimerForId[operationId], curTimer === timer {
                operationTimerForId[operationId] = nil
            }
            operationTimerLock.unlock()
            block()
        }
        
        guard interval == nil || date == nil else {
            Brisk.brisk_raise("It is considered a fatal error to pass both 'after' and 'at'")
        }
        
        if let date = date {
            let deadline = DispatchWallTime.now() + max(date.timeIntervalSinceNow, 0)
            
            if let leeway = leeway {
                timer.scheduleOneshot(wallDeadline: deadline, leeway: leeway.asDispatchTimeInterval())
            } else {
                timer.scheduleOneshot(wallDeadline: deadline)
            }
        } else {
            let deadline = DispatchTime.now() + (interval ?? 0)
            
            if let leeway = leeway {
                timer.scheduleOneshot(deadline: deadline, leeway: leeway.asDispatchTimeInterval())
            } else {
                timer.scheduleOneshot(deadline: deadline)
            }
        }
        
        operationTimerLock.lock()
        if let existingTimer = operationTimerForId[operationId], !existingTimer.isCancelled {
            existingTimer.cancel()
        }
        operationTimerForId[operationId] = timer
        timer.resume()
        operationTimerLock.unlock()
        
        return timer
    }
}
