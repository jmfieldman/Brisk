//
//  BriskRaise.swift
//  Brisk
//
//  Created by Jason Fieldman on 8/14/16.
//  Copyright © 2016 Jason Fieldman. All rights reserved.
//

import Foundation

@noreturn internal func brisk_raise(reason: String) {
    NSException(name: "Brisk Exception", reason: reason, userInfo: nil).raise()
    fatalError("Brisk usage exceptions are fatal errors.")
}