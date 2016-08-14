//
//  BriskLock.swift
//  Brisk
//
//  Created by Jason Fieldman on 8/12/16.
//  Copyright © 2016 Jason Fieldman. All rights reserved.
//

import Foundation




// MARK: - Concurrency Synchronization

/// Perform a block synchronized on a spin lock.
///
/// - parameter lock:  The spinlock to use.
/// - parameter block: The block to perform.
@inline(__always) public func synchronized(inout lock: OSSpinLock, @noescape block: () -> ()) {
    OSSpinLockLock(&lock)
    block()
    OSSpinLockUnlock(&lock)
}


/// Perform a block synchronized on a spin lock.  The block returns a value.
///
/// - parameter lock:  The spinlock to use.
/// - parameter block: The block to perform.
@inline(__always) public func synchronized<T>(inout lock: OSSpinLock, @noescape block: () -> T) -> T {
    OSSpinLockLock(&lock)
    let r = block()
    OSSpinLockUnlock(&lock)
    return r
}


/// Perform a block synchronized on a spin lock.  The block returns an optional value.
///
/// - parameter lock:  The spinlock to use.
/// - parameter block: The block to perform.
@inline(__always) public func synchronized<T>(inout lock: OSSpinLock, @noescape block: () -> T?) -> T? {
    OSSpinLockLock(&lock)
    let r = block()
    OSSpinLockUnlock(&lock)
    return r
}


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
private var universalLock: OSSpinLock = OS_SPINLOCK_INIT


/// Perform a block synchronized on the global static spin lock.
///
/// - parameter block: The block to perform.
@inline(__always) public func synchronized(@noescape block: () -> ()) {
    OSSpinLockLock(&universalLock)
    block()
    OSSpinLockUnlock(&universalLock)
}


/// Perform a block synchronized on the global static spin lock.  The block returns a value.
///
/// - parameter block: The block to perform.
@inline(__always) public func synchronized<T>(@noescape block: () -> T) -> T {
    OSSpinLockLock(&universalLock)
    let r = block()
    OSSpinLockUnlock(&universalLock)
    return r
}


/// Perform a block synchronized on the global static spin lock.  The block returns an optional value.
///
/// - parameter block: The block to perform.
@inline(__always) public func synchronized<T>(@noescape block: () -> T?) -> T? {
    OSSpinLockLock(&universalLock)
    let r = block()
    OSSpinLockUnlock(&universalLock)
    return r
}


