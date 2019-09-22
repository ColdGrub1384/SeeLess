//
//  URL.swift
//  SeeLess
//
//  Created by Adrian Labbé on 19-09-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import Foundation

extension URL {
    
    /// Taken from https://stackoverflow.com/a/56054033/7515957
    func relativePath(from base: URL) -> String? {
        // Ensure that both URLs represent files:
        guard self.isFileURL && base.isFileURL else {
            return nil
        }

        //this is the new part, clearly, need to use workBase in lower part
        let workBase = base

        // Remove/replace "." and "..", make paths absolute:
        let destComponents = self.standardized.pathComponents
        let baseComponents = workBase.standardized.pathComponents

        // Find number of common path components:
        var i = 0
        while i < destComponents.count &&
              i < baseComponents.count &&
              destComponents[i] == baseComponents[i] {
                i += 1
        }

        // Build relative path:
        var relComponents = Array(repeating: "..", count: baseComponents.count - i)
        relComponents.append(contentsOf: destComponents[i...])
        return relComponents.joined(separator: "/")
    }
}
