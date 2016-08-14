//
//  Spin.swift
//  Brisk
//
//  Created by Jason Fieldman on 8/12/16.
//  Copyright © 2016 Jason Fieldman. All rights reserved.
//

import Foundation

protocol Spin : AnyObject {
    func start()
    func done()
    func wait()
}


internal class MainSpin : Spin {
    var finished: Bool = false
    
    func start() {
        self.finished = false
    }
    
    func done() {
        self.finished = true
    }
    
    func wait() {
        while !finished {
            NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate(timeIntervalSinceNow: 0.1))
        }
    }
}

internal class AsyncSpin : Spin {
    let group = dispatch_group_create()
    
    
    func start() {
        dispatch_group_enter(group)
    }
    
    func done() {
        dispatch_group_leave(group)
    }
    
    func wait() {
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
    }
    
}
