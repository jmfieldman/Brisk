//
//  BriskGate.swift
//  Brisk
//
//  Created by Jason Fieldman on 8/14/16.
//  Copyright © 2016 Jason Fieldman. All rights reserved.
//

import Foundation


// BriskGate is an intelligent semaphore mechanism that can
// perform waits from the main thread without freezing the
// application (though it does so inefficiently).

internal class BriskGate {
    
    var isMain:     Bool
    var group:      dispatch_group_t?   = nil
    var finished:   Bool                = false
    
    init() {
        isMain = NSThread.currentThread().isMainThread
        if !isMain {
            group = dispatch_group_create()
            dispatch_group_enter(group!)
        }
    }
    
    func signal() {
        finished = true
        if !isMain {
            dispatch_group_leave(group!)
        }
    }
    
    func wait() {
        if isMain {
            while !finished {
                NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate(timeIntervalSinceNow: 0.1))
            }
        } else {
            dispatch_group_wait(group!, DISPATCH_TIME_FOREVER)
        }
    }
    
}