//
//  package.swift
//  SeeLess
//
//  Created by Adrian Labbé on 24-12-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import Foundation

/// The 'package' command.
func packageMain(argc: Int, argv: [String], io: LTIO) -> Int32 {
    
    fputs("package is not supported by SeeLess. Third party commands can only be installed in LibTerm.\n".cValue, io.stdout)
    
    return 0
}
