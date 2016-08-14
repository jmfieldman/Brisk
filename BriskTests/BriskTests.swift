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
        spin.wait()
        
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
        spin.wait()
        
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
        spin.wait()
    
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
        spin.wait()
        
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
        spin.wait()
        
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
        spin.wait()
        
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
        spin.wait()
        
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
        spin.wait()
        
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
        spin.wait()
        
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
        spin.wait()
        
        XCTAssertEqual(count, 10, "counted incorrect times")
        XCTAssertTrue(qPassed, "on incorrect queue")
    }
 
	
	// MARK: - Async To Sync
	
    
	func testBasicAsync2SyncConceptBG() {
		let spin = MainSpin()
		spin.start()
		
		var res: Int = 0
		
		dispatch_bg_async {
			res = <<~{ self.asyncTest_CallsOnMainReturns4($0) }
			spin.done()
		}
		
		spin.wait()
		
		XCTAssertEqual(res, 4, "incorrect response")
	}
	
	
	func testBasicAsync2SyncConceptMain() {
		let spin = MainSpin()
		spin.start()
		
		var res: Int = 0
		
		dispatch_bg_async {
			res = <<+{ self.asyncTest_CallsOnMainReturns4($0) }
			spin.done()
		}
		
		spin.wait()
		
		XCTAssertEqual(res, 4, "incorrect response")
	}
	
	func testBasicAsync2SyncConceptBG2() {
		let spin = MainSpin()
		spin.start()
		
		var res: Int = 0
		
		dispatch_bg_async {
			res = <<~{ self.asyncTest_CallsOnMainReturnsI(3, handler: $0) }
			spin.done()
		}
		
		spin.wait()
		
		XCTAssertEqual(res, 3, "incorrect response")
	}
	
	func testBasicAsync2SyncConceptBG3() {
		let spin = MainSpin()
		spin.start()
		
		var res: Int = 0
		var str: String = ""
		
		dispatch_bg_async {
			(res, str) = <<~{ self.asyncTest_CallsOnMainReturnsIforBoth(3, handler: $0) }
			spin.done()
		}
		
		spin.wait()
		
		XCTAssertEqual(res, 3, "incorrect response int")
		XCTAssertEqual(str, "3", "incorrect response str")
	}

	func testBasicAsync2SyncConceptBG3_ImmediateOp() {
		let spin = MainSpin()
		spin.start()
		
		var res: Int = 0
		var str: String = ""
		
		dispatch_bg_async {
			(res, str) = <<-{ self.asyncTest_CallsOnMainReturnsIforBoth(3, handler: $0) }
			spin.done()
		}
		
		spin.wait()
		
		XCTAssertEqual(res, 3, "incorrect response int")
		XCTAssertEqual(str, "3", "incorrect response str")
	}
	
	
	func testBasicAsync2SyncConceptBG3_QueueOp() {
		let spin = MainSpin()
		spin.start()
		
		var res: Int = 0
		var str: String = ""
		
		let myQueue = dispatch_queue_create("test", nil)
		
		dispatch_bg_async {
			(res, str) = <<~myQueue ~~~ { self.asyncTest_CallsOnMainReturnsIforBoth(3, handler: $0) }
			spin.done()
		}
		
		spin.wait()
		
		XCTAssertEqual(res, 3, "incorrect response int")
		XCTAssertEqual(str, "3", "incorrect response str")
	}
    
    
    func testBasicAsync2SyncConceptONMain() {
        let (res, str) = <<-{ asyncTest_CallsOnMainReturnsIforBoth(3, handler: $0) }
        
        XCTAssertEqual(res, 3, "incorrect response int")
        XCTAssertEqual(str, "3", "incorrect response str")
    }
    
    func testBasicAsync2SyncConceptONMain2() {
        let (res, str) = <<+{ self.asyncTest_CallsOnMainReturnsIforBoth(3, handler: $0) }
        
        XCTAssertEqual(res, 3, "incorrect response int")
        XCTAssertEqual(str, "3", "incorrect response str")
    }
    
    func testBasicAsync2SyncConceptONMain3() {
        let (res, str) = <<~{ self.asyncTest_CallsOnMainReturnsIforBoth(3, handler: $0) }
        
        XCTAssertEqual(res, 3, "incorrect response int")
        XCTAssertEqual(str, "3", "incorrect response str")
    }
    
    
    // MARK: - Sync To Async
    
    func makeSureThisCompiles() {
        
        syncTest_Return4+>>() +>> { i in }
        syncTest_ReturnsI~>>.async(3) +>> { i in }
        syncTest_Return4~>>()
        syncTest_Return4~>>() ~>> { i in }
        syncTest_ReturnsI+>>(4)
        (syncTest_ReturnsI+>>(4)) ~>> { (i: Int) in }
        syncTest_ReturnsI+>>(4) ~>> { (i: Int) in }
        syncTest_ReturnsI~>>(4)
        syncTest_ReturnsI~>>(4) +>> { i in }
        
        let q = dispatch_queue_create("dkjfd", nil)
        
        syncTest_ReturnsI +>> (4) ~>> q ~>> { i in }
        syncTest_ReturnsI +>> (4) ~>> q ~>> { i in }
        syncTest_ReturnsI +>> (4) ~>> { i in }
        syncTest_ReturnsVoid ~>> ()
        syncTest_ReturnsVoidParam ~>> q ~>> (3)
    }
    
    
	
	// MARK: - Async Functions to Test With
	
	func asyncTest_CallsOnMainReturns4(handler: Int -> Void) {
		dispatch_main_async { handler(4) }
	}
	
	func asyncTest_CallsOnMainReturnsI(i: Int, handler: Int -> Void) {
		dispatch_main_async { handler(i) }
	}
	
	func asyncTest_CallsOnMainReturnsIforBoth(i: Int, handler: (i: Int, s: String) -> Void) {
		dispatch_main_async { handler(i: i, s: "\(i)") }
	}
	
	// MARK: - Sync Functions to Test With
	
    func syncTest_ReturnsVoid() {
        
    }
    
    func syncTest_ReturnsVoidParam(i: Int) {
        
    }
    
	func syncTest_Return4() -> Int {
		return 4
	}
	
	func syncTest_ReturnsI(i: Int) -> Int {
		return i
	}
	
	func syncTest_ReturnsIforBoth(i: Int) -> (i: Int, s: String) {
		return (i: i, s: "\(i)")
	}
	
}



