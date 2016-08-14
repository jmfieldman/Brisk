//
//  BriskTests.swift
//  BriskTests
//
//  Created by Jason Fieldman on 8/12/16.
//  Copyright © 2016 Jason Fieldman. All rights reserved.
//

import XCTest
@testable import Brisk

private let mainQueueKey = UnsafeMutablePointer<Void>.alloc(1)
private let mainQueueValue = UnsafeMutablePointer<Void>.alloc(1)

private func onMainQueue() -> Bool {
    return dispatch_get_specific(mainQueueKey) == mainQueueValue
}

private func onMainThread() -> Bool {
    return NSThread.currentThread().isMainThread
}

private func onMainEverything() -> Bool {
    return onMainThread() && onMainQueue()
}

class BriskTests: XCTestCase {
    
    
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        dispatch_queue_set_specific(
            dispatch_get_main_queue(),
            mainQueueKey,
            mainQueueValue,
            nil
        )
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    
    // MARK: - Basic dispatch stuff
    
    func testBasicDispatchMain() {
        let spin = MainSpin()
        var qPassed = false
        
        spin.start()
        dispatch_main_async {
            spin.done()
            qPassed = onMainEverything()
        }
        spin.waitUntilFinished()
        
        XCTAssertTrue(qPassed, "on incorrect queue")
    }
    
    
    func testBasicDispatchAsync() {
        let spin = AsyncSpin()
        var qPassed = false
        
        spin.start()
        dispatch_bg_async {
            spin.done()
            qPassed = !onMainQueue()
        }
        spin.waitUntilFinished()
        
        XCTAssertTrue(qPassed, "on incorrect queue")
    }
    
    
    func testBasicDispatchMainAfter() {
        
        let spin = MainSpin()
        let time1: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        var time2: CFAbsoluteTime = 0
        var qPassed = false
        
        spin.start()
        dispatch_main_after(0.5) {
            time2 = CFAbsoluteTimeGetCurrent()
            spin.done()
            qPassed = onMainEverything()
        }
        spin.waitUntilFinished()
    
        XCTAssertGreaterThan(time2 - time1, 0.25, "diff must be greater than 0.25")
        XCTAssertTrue(qPassed, "on incorrect queue")
    }
    
    func testBasicDispatchAsyncAfter() {
        
        let spin = AsyncSpin()
        let time1: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        var time2: CFAbsoluteTime = 0
        var qPassed = false
        
        spin.start()
        dispatch_after(0.5, backgroundQueue) {
            time2 = CFAbsoluteTimeGetCurrent()
            spin.done()
            qPassed = !onMainQueue()
        }
        spin.waitUntilFinished()
        
        XCTAssertGreaterThan(time2 - time1, 0.25, "diff must be greater than 0.5")
        XCTAssertTrue(qPassed, "on incorrect queue")
    }
    
    
    func testBasicDispatchMainOnce() {
        
        let spin = MainSpin()
        let time1: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        var time2: CFAbsoluteTime = 0
        var qPassed = false
        var count = 0
        
        spin.start()
        let block = {
            time2 = CFAbsoluteTimeGetCurrent()
            count += 1
            qPassed = onMainEverything()
            spin.done()
        }
        for _ in 0 ..< 10 {
            dispatch_main_once_after(0.5, operationId: "testop2") {
                block()
            }
        }
        spin.waitUntilFinished()
        
        XCTAssertEqual(count, 1, "counted more than once")
        XCTAssertGreaterThan(time2 - time1, 0.25, "diff must be greater than 0.5")
        XCTAssertTrue(qPassed, "on incorrect queue")
        
    }
    
    
    func testBasicDispatchAsyncOnce() {
        
        let spin = AsyncSpin()
        let time1: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        var time2: CFAbsoluteTime = 0
        var qPassed = false
        var count = 0
        
        spin.start()
        let block = {
            time2 = CFAbsoluteTimeGetCurrent()
            count += 1
            qPassed = !onMainQueue()
            spin.done()
        }
        for _ in 0 ..< 10 {
            dispatch_once_after(0.5, operationId: "testop", onQueue: backgroundQueue) {
                block()
            }
        }
        spin.waitUntilFinished()
        
        XCTAssertEqual(count, 1, "counted more than once")
        XCTAssertGreaterThan(time2 - time1, 0.25, "diff must be greater than 0.5")
        XCTAssertTrue(qPassed, "on incorrect queue")
        
    }
    
    
    func testBasicDispatchEveryMain() {
        
        let spin = MainSpin()
        var count = 0
        var qPassed = true
        
        spin.start()
        dispatch_main_every(0.1) { t in
            count += 1
            if !onMainEverything() { qPassed = false }
            if count == 10 {
                spin.done()
                dispatch_source_cancel(t)
            }
        }
        spin.waitUntilFinished()
        
        XCTAssertEqual(count, 10, "counted incorrect times")
        XCTAssertTrue(qPassed, "on incorrect queue")
    }
    
    func testBasicDispatchEveryMainExact() {
        
        let spin = MainSpin()
        var count = 0
        var qPassed = true
        
        spin.start()
        dispatch_main_every_exact(0.1) { t in
            count += 1
            if !onMainEverything() { qPassed = false }
            if count == 10 {
                spin.done()
                dispatch_source_cancel(t)
            }
        }
        spin.waitUntilFinished()
        
        XCTAssertEqual(count, 10, "counted incorrect times")
        XCTAssertTrue(qPassed, "on incorrect queue")
    }
    
    func testBasicDispatchEveryAsync() {
        
        let spin = AsyncSpin()
        var count = 0
        var qPassed = true
        
        spin.start()
        dispatch_every(0.1, backgroundQueue) { t in
            count += 1
            if onMainQueue() { qPassed = false }
            if count == 10 {
                spin.done()
                dispatch_source_cancel(t)
            }
        }
        spin.waitUntilFinished()
        
        XCTAssertEqual(count, 10, "counted incorrect times")
        XCTAssertTrue(qPassed, "on incorrect queue")
    }
    
    func testBasicDispatchEveryAsyncExact() {
        
        let spin = AsyncSpin()
        var count = 0
        var qPassed = true
        
        spin.start()
        dispatch_every_exact(0.1, backgroundQueue) { t in
            count += 1
            if onMainQueue() { qPassed = false }
            if count == 10 {
                spin.done()
                dispatch_source_cancel(t)
            }
        }
        spin.waitUntilFinished()
        
        XCTAssertEqual(count, 10, "counted incorrect times")
        XCTAssertTrue(qPassed, "on incorrect queue")
    }
    
}
