//
//  UITextView.swift
//  SeeLess
//
//  Created by Adrian Labbé on 29-09-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import UIKit

extension UITextView {
    
    /// Get the entire line range from given range.
    ///
    /// - Parameters:
    ///     - range: The range contained in returned line.
    ///
    /// - Returns: The entire line range.
    func line(at range: NSRange) -> UITextRange? {
        let beginning = beginningOfDocument
        
        if let start = position(from: beginning, offset: range.location),
            let end = position(from: start, offset: range.length) {
            
            let textRange = tokenizer.rangeEnclosingPosition(end, with: .line, inDirection: UITextDirection(rawValue: 1))
            
            return textRange ?? selectedTextRange
        }
        return selectedTextRange
    }
    
    /// Returns the range of the selected line.
    var currentLineRange: UITextRange? {
        return line(at: selectedRange)
    }
    
    /// Returns the current selected line.
    var currentLine : String? {
        if let textRange = currentLineRange {
            return text(in: textRange)
        } else {
            return nil
        }
    }
}
