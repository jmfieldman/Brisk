//
//  BriskTests.swift
//  BriskTests
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

import XCTest
@testable import Brisk

private let mainQueueKey = UnsafeMutableRawPointer(allocatingCapacity: 1)
private let mainQueueValue = UnsafeMutableRawPointer(allocatingCapacity: 1)

private func onMainQueue() -> Bool {
    return DispatchQueue.getSpecific(mainQueueKey) == mainQueueValue
}

private func onMainThread() -> Bool {
    return Thread.current.isMainThread
}

private func onMainEverything() -> Bool {
    return onMainThread() && onMainQueue()
}

class BriskTests: XCTestCase {
    
    
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        DispatchQueue.main.setSpecific(key: /*Migrator FIXME: Use a variable of type DispatchSpecificKey*/ mainQueueKey,
            value: mainQueueValue)
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
                t.cancel()
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
                t.cancel()
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
                t.cancel()
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
                t.cancel()
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
		
		let myQueue = DispatchQueue(label: "test", attributes: [])
		
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
    
    func testSync2Async_MainA() {
        let spin = MainSpin()
        spin.start()
        var r: Int = 0
        var inMain = false
        
        syncTest_Return4+>>() +>> { inMain = Thread.current.isMainThread; r = $0; spin.done() }
        spin.wait()
        
        XCTAssertEqual(r, 4, "incorrect response int")
        XCTAssertEqual(inMain, true, "incorrect queue")
    }
    
    func testSync2Async_MainB() {
        let spin = MainSpin()
        spin.start()
        var r: Int = 0
        var inMain = false
        
        syncTest_Return4 +>> () +>> { inMain = Thread.current.isMainThread; r = $0; spin.done() }
        spin.wait()
        
        XCTAssertEqual(r, 4, "incorrect response int")
        XCTAssertEqual(inMain, true, "incorrect queue")
    }
    
    func testSync2Async_MainC() {
        let spin = MainSpin()
        spin.start()
        var r: Int = 0
        var inMain = false
        
        syncTest_ReturnsI+>>.async(4) +>> { inMain = Thread.current.isMainThread; r = $0; spin.done() }
        spin.wait()
        
        XCTAssertEqual(r, 4, "incorrect response int")
        XCTAssertEqual(inMain, true, "incorrect queue")
    }
    
    func testSync2Async_MainD() {
        let spin = MainSpin()
        spin.start()
        var r: Int = 0
        var inMain = false
        
        syncTest_ReturnsI +>> (4) +>> { inMain = Thread.current.isMainThread; r = $0; spin.done() }
        spin.wait()
        
        XCTAssertEqual(r, 4, "incorrect response int")
        XCTAssertEqual(inMain, true, "incorrect queue")
    }
    
    func testSync2Async_MainE() {
        let spin = MainSpin()
        spin.start()
        var r: Int = 0
        var inMain = false
        
        syncTest_ReturnsI ~>> (4) +>> { inMain = Thread.current.isMainThread; r = $0; spin.done() }
        spin.wait()
        
        XCTAssertEqual(r, 4, "incorrect response int")
        XCTAssertEqual(inMain, true, "incorrect queue")
    }
    
    func testSync2Async_MainBothA() {
        let spin = MainSpin()
        spin.start()
        var r: Int = 0
        var s: String = ""
        var inMain = false
        
        syncTest_ReturnsIforBoth ~>> (4) +>> { inMain = onMainQueue(); (r, s) = $0; spin.done() }
        spin.wait()
        
        XCTAssertEqual(r, 4, "incorrect response int")
        XCTAssertEqual(s, "4", "incorrect response str")
        XCTAssertEqual(inMain, true, "incorrect queue")
    }
    
    func testSync2Async_MainBothB() {
        let spin = MainSpin()
        spin.start()
        var r: Int = 0
        var s: String = ""
        var inMain = false
        
        syncTest_ReturnsIforBoth ~>> (4) ~>> DispatchQueue.main ~>> { inMain = onMainQueue(); (r, s) = $0; spin.done() }
        spin.wait()
        
        XCTAssertEqual(r, 4, "incorrect response int")
        XCTAssertEqual(s, "4", "incorrect response str")
        XCTAssertEqual(inMain, true, "incorrect queue")
    }
    
    func testSync2Async_BGBothB() {
        let spin = MainSpin()
        spin.start()
        var r: Int = 0
        var s: String = ""
        var inMain = false
        
        syncTest_ReturnsIforBoth ~>> (4) ~>> DispatchQueue(label: "", attributes: []) ~>> { inMain = onMainQueue(); (r, s) = $0; spin.done() }
        spin.wait()
        
        XCTAssertEqual(r, 4, "incorrect response int")
        XCTAssertEqual(s, "4", "incorrect response str")
        XCTAssertEqual(inMain, false, "incorrect queue")
    }
    
    func testSync2Async_MainRetA() {
        var r: Int = 0
        var s: String = ""
        
        (r, s) = syncTest_ReturnsIforBoth~>>.sync(4)
        
        XCTAssertEqual(r, 4, "incorrect response int")
        XCTAssertEqual(s, "4", "incorrect response str")
    }
    
    func testSync2Async_MainRetB() {
        var r: Int = 0
        var s: String = ""
        
        (r, s) = syncTest_ReturnsIforBoth+>>.sync(4)
        
        XCTAssertEqual(r, 4, "incorrect response int")
        XCTAssertEqual(s, "4", "incorrect response str")
    }
    
    func testSync2Async_MainRetC() {
        var r: Int = 0
        var inMain = false
        
        r = { (i: Int) in inMain = onMainQueue(); return i }+>>.sync(4)
        
        XCTAssertEqual(r, 4, "incorrect response int")
        XCTAssertEqual(inMain, true, "incorrect queue")
    }
    
    func testSync2Async_MainRetD() {
        var r: Int = 0
        var inMain = true
        
        r = { (i: Int) in inMain = onMainQueue(); return i }~>>.sync(4)
        
        XCTAssertEqual(r, 4, "incorrect response int")
        XCTAssertEqual(inMain, false, "incorrect queue")
    }
    
    func testSync2Async_MainRetE() {
        var inMain = true;
        
        { inMain = onMainQueue() }~>>.sync()
        
        XCTAssertEqual(inMain, false, "incorrect queue")
    }
    
    func testSync2Async_MainRetF() {
        var inMain = false;
        
        { inMain = onMainQueue() }+>>.sync()
        
        XCTAssertEqual(inMain, true, "incorrect queue")
    }
    
    // Compile checks
    
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
        
        let q = DispatchQueue(label: "dkjfd", attributes: [])
        
        syncTest_ReturnsI +>> (4) ~>> q ~>> { i in }
        syncTest_ReturnsI +>> (4) ~>> q ~>> { i in }
        syncTest_ReturnsI +>> (4) ~>> { i in }
        syncTest_ReturnsVoid ~>> ()
        syncTest_ReturnsVoidParam ~>> q ~>> (3)
        
        var s: Int = 0;
        { s = 3 } +>> ();
        { s = 3 }+>>.sync()
        let _ = s
    }
    
    func makeSureThisCompiles(_ p: Int, completionHandler: ((_ i: Int) -> Int)?) {
        completionHandler ?+>> (3) +>> { i in }
        completionHandler?+>>.async(3)
        let _: Int? = completionHandler?~>>.sync(3)
    }
    
	
	// MARK: - Async Functions to Test With
	
	func asyncTest_CallsOnMainReturns4(_ handler: @escaping (Int) -> Void) {
		dispatch_main_async { handler(4) }
	}
	
	func asyncTest_CallsOnMainReturnsI(_ i: Int, handler: @escaping (Int) -> Void) {
		dispatch_main_async { handler(i) }
	}
	
	func asyncTest_CallsOnMainReturnsIforBoth(_ i: Int, handler: @escaping (_ i: Int, _ s: String) -> Void) {
		dispatch_main_async { handler(i: i, s: "\(i)") }
	}
	
	// MARK: - Sync Functions to Test With
	
    func syncTest_ReturnsVoid() {
        
    }
    
    func syncTest_ReturnsVoidParam(_ i: Int) {
        
    }
    
	func syncTest_Return4() -> Int {
		return 4
	}
	
	func syncTest_ReturnsI(_ i: Int) -> Int {
		return i
	}
	
	func syncTest_ReturnsIforBoth(_ i: Int) -> (i: Int, s: String) {
		return (i: i, s: "\(i)")
	}
	
}



