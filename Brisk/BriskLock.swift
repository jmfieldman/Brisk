//
//  BriskLock.swift
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




// MARK: - Concurrency Synchronization


/// Perform a block synchronized on a NSLocking object.
///
/// - parameter lock:  The NSLocking object to use.
/// - parameter block: The block to perform.
@inline(__always) public func synchronized(lock: NSLocking, @noescape block: () -> ()) {
    lock.lock()
    block()
    lock.unlock()
}


/// Perform a block synchronized on a NSLocking object.  The block returns a value.
///
/// - parameter lock:  The NSLocking object to use.
/// - parameter block: The block to perform.
@inline(__always) public func synchronized<T>(lock: NSLocking, @noescape block: () -> T) -> T {
    lock.lock()
    let r = block()
    lock.unlock()
    return r
}


/// Perform a block synchronized on a NSLocking object.  The block returns an optional value.
///
/// - parameter lock:  The NSLocking object to use.
/// - parameter block: The block to perform.
@inline(__always) public func synchronized<T>(lock: NSLocking, @noescape block: () -> T?) -> T? {
    lock.lock()
    let r = block()
    lock.unlock()
    return r
}


// For the universal synchronization
private var universalLock: NSRecursiveLock = NSRecursiveLock()


/// Perform a block synchronized on the global static spin lock.
///
/// - parameter block: The block to perform.
@inline(__always) public func synchronized(@noescape block: () -> ()) {
    universalLock.lock()
    block()
    universalLock.unlock()
}


/// Perform a block synchronized on the global static spin lock.  The block returns a value.
///
/// - parameter block: The block to perform.
@inline(__always) public func synchronized<T>(@noescape block: () -> T) -> T {
    universalLock.lock()
    let r = block()
    universalLock.unlock()
    return r
}


/// Perform a block synchronized on the global static spin lock.  The block returns an optional value.
///
/// - parameter block: The block to perform.
@inline(__always) public func synchronized<T>(@noescape block: () -> T?) -> T? {
    universalLock.lock()
    let r = block()
    universalLock.unlock()
    return r
}


