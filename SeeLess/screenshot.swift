//
//  screenshot.swift
//  SeeLess
//
//  Created by Adrian Labbé on 06-10-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import UIKit

/// A command to run for App Store screenshots.
func screenshotMain(argc: Int, argv: [String], io: LTIO) -> Int32 {
    
    _ = clearMain(1, argv: ["clear"], io: io)
    fputs("\(UIDevice.current.name) $\nCompiling main.c...\nLinking...\nRunning Hello-World.bc\n\nHello World!\n\nExited with status code: 0\n".cValue, io.stdout)
    io.terminal?.shell.history.removeLast()
    
    sleep(1)
    
    return 0
}
