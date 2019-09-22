//
//  TextDocument.swift
//  SeeLess
//
//  Created by Adrian Labbé on 16-09-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import UIKit

/// Errors opening the document.
enum DocumentError: Error {
    case unableToParseText
    case unableToEncodeText
}

/// A document representing a text document.
class TextDocument: UIDocument {
    
    /// The text to save.
    var text = ""
    
    /// The editor editing this document.
    var editor: EditorViewController?
    
    private var storedModificationDate: Date? {
        didSet {
            print(self.storedModificationDate ?? "nil")
        }
    }
    
    override func contents(forType typeName: String) throws -> Any {
        guard let data = text.data(using: .utf8) else {
            throw DocumentError.unableToEncodeText
        }
        
        return data
    }
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        guard let data = contents as? Data else {
            // This would be a developer error.
            fatalError("*** \(contents) is not an instance of NSData.***")
        }
        
        guard let newText = String(data: data, encoding: .utf8) else {
            throw DocumentError.unableToParseText
        }
        
        text = newText
    }
    
    override func open(completionHandler: ((Bool) -> Void)? = nil) {
        super.open { (success) in
            if self.storedModificationDate == nil {
                self.storedModificationDate = self.fileModificationDate
            }
            completionHandler?(success)
        }
    }
    
    override func presentedItemDidChange() {
        super.presentedItemDidChange()
        
        guard fileModificationDate != storedModificationDate else {
            return
        }
        
        print(fileModificationDate ?? "nil")
        print(storedModificationDate ?? "nil")
        
        storedModificationDate = fileModificationDate
        
        if let data = try? Data(contentsOf: fileURL) {
            try? load(fromContents: data, ofType: "public.data")
            DispatchQueue.main.async {
                if self.editor?.textView.text != self.text {
                    self.editor?.textView.text = self.text
                }
            }
        }
    }
}

