//
//  EditorViewController.swift
//  SeeLess
//
//  Created by Adrian Labbé on 16-09-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import UIKit
import Highlightr
import MobileCoreServices
import ios_system

/// The View controller for editing a Markdown file.
class EditorViewController: UIViewController, UITextViewDelegate {
        
    /// The text storage used in `textView`.
    var textStorage: NSTextStorage!
    
    /// The Text view containing the raw content.
    var textView: LineNumberTextView!
    
    /// The document to edit.
    var document: URL! {
        didSet {
            
            title = document.lastPathComponent
            if #available(iOS 13.0, *) {
                view.window?.windowScene?.title = title
            }
            
            textStorage = CodeAttributedString()
            if #available(iOS 12.0, *) {
                if traitCollection.userInterfaceStyle == .dark {
                    (textStorage as! CodeAttributedString).highlightr.setTheme(to: themeName)
                } else {
                    (textStorage as! CodeAttributedString).highlightr.setTheme(to: themeName)
                }
            } else {
                (textStorage as! CodeAttributedString).highlightr.setTheme(to: themeName)
            }
            
            textView = LineNumberTextView(frame: view.safeAreaLayoutGuide.layoutFrame, andTextStorage: textStorage)
            textView.text = text
            textView.lineNumberTextColor = .secondaryLabel
            textView.lineNumberBackgroundColor = .systemBackground
            textView.lineNumberBorderColor = .secondarySystemFill
            textView.autocorrectionType = .no
            textView.autocapitalizationType = .none
            textView.smartDashesType = .no
            textView.smartQuotesType = .no
            textView.inputAssistantItem.leadingBarButtonGroups = []
            textView.inputAssistantItem.trailingBarButtonGroups = []
            let toolbar = UIToolbar()
            toolbar.items = [
                UIBarButtonItem(image: UIImage(systemName: "arrow.right.to.line"), style: .plain, target: self, action: #selector(insertTab)),
                undoItem,
                redoItem,
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                UIBarButtonItem(image: UIImage(systemName: "chevron.down"), style: .plain, target: textView, action: #selector(textView.resignFirstResponder))
            ]
            toolbar.frame.size.height = 44
            toolbar.tintColor = .label
            textView.inputAccessoryView = toolbar
            
            // Syntax coloring
            
            if document.lastPathComponent == "configuration.txt" {
               (textStorage as? CodeAttributedString)?.language = "bash"
            } else {
                let languages = NSDictionary(contentsOf: Bundle.main.bundleURL.appendingPathComponent("langs.plist"))! as! [String:[String]] // List of languages associated by file extensions
                
                if let languagesForFile = languages[document.pathExtension.lowercased()] {
                    if languagesForFile.count > 0 {
                        (textStorage as? CodeAttributedString)?.language = languagesForFile[0]
                    }
                } else {
                    (textStorage as? CodeAttributedString)?.language = "markdown"
                }
            }
            
            textView.backgroundColor = (textStorage as? CodeAttributedString)?.highlightr.theme.themeBackgroundColor
        }
    }
    
    /// The path extension of `document`.
    var pathExtension: String {
        return document.pathExtension.lowercased()
    }
    
    /// The name of the theme to use.
    var themeName: String {
        if #available(iOS 12.0, *) {
            if traitCollection.userInterfaceStyle == .dark {
                return "ir-black"
            } else {
                return "xcode"
            }
        } else {
            return "xcode"
        }
    }
    
    private var _text = ""
    
    /// The text to display when the editor loads.
    var text = ""
    
    // MARK: - View controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        edgesForExtendedLayout = []
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let txtView = textView, txtView.superview == nil {
            txtView.delegate = self
            view.backgroundColor = txtView.backgroundColor
            txtView.frame = view.safeAreaLayoutGuide.layoutFrame
            view.addSubview(txtView)
            _text = txtView.text ?? ""
            textView.text = ""
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        navigationItem.leftItemsSupplementBackButton = true
        if let item = splitViewController?.displayModeButtonItem {
            navigationItem.leftBarButtonItem = item
        }
        
        textView.frame = view.safeAreaLayoutGuide.layoutFrame
        textView.keyboardAppearance = .default
                
        if #available(iOS 13.0, *) {
            view.window?.windowScene?.title = title
        }
        
        // Yes, I know
        textView.becomeFirstResponder()
        textView.text = _text
        undoItem.isEnabled = (textView.undoManager?.canUndo == true)
        redoItem.isEnabled = (textView.undoManager?.canRedo == true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if #available(iOS 13.0, *) {
            view.window?.windowScene?.title = nil
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        guard view != nil else {
            return
        }
        
        let wasFirstResponder = textView.isFirstResponder
        textView.resignFirstResponder()
        
        coordinator.animate(alongsideTransition: nil) { (_) in
            self.textView.frame = self.view.safeAreaLayoutGuide.layoutFrame
            if wasFirstResponder {
                self.textView.becomeFirstResponder()
            }
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if #available(iOS 13.0, *) {
            if let codeStorage = textStorage as? CodeAttributedString {
                codeStorage.highlightr.setTheme(to: themeName)
                textView.backgroundColor = codeStorage.highlightr.theme.themeBackgroundColor
            }
            
            view.backgroundColor = textView.backgroundColor
        }
    }
    
    // MARK: - Keyboard
    
    /// Resize `textView`.
    @objc func keyboardWillShow(_ notification:Notification) {
        let d = notification.userInfo!
        var r = d[UIResponder.keyboardFrameEndUserInfoKey] as! CGRect
        
        r = textView.convert(r, from:nil)
        textView.contentInset.bottom = r.size.height
        textView.verticalScrollIndicatorInsets.bottom = r.size.height
    }
    
    /// Set `textView` to the default size.
    @objc func keyboardWillHide(_ notification:Notification) {
        textView.contentInset = .zero
        textView.scrollIndicatorInsets = .zero
    }
    
    /// Inserts tab.
    @objc func insertTab() {
        textView.insertText(UserDefaults.standard.string(forKey: "indentation") ?? "    ")
    }
    
    /// An item to undo last change.
    let undoItem = UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.left"), style: .plain, target: self, action: #selector(undo(_:)))
    
    /// An item to redo last change.
    let redoItem = UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.right"), style: .plain, target: self, action: #selector(redo(_:)))
    
    /// Undoes last change.
    @objc func undo(_ sender: UIBarButtonItem) {
        if textView.undoManager?.canUndo == true {
            textView.undoManager?.undo()
        }
        sender.isEnabled = (textView.undoManager?.canUndo == true)
    }
    
    /// Redoes last change.
    @objc func redo(_ sender: UIBarButtonItem) {
        if textView.undoManager?.canRedo == true {
            textView.undoManager?.redo()
        }
        sender.isEnabled = (textView.undoManager?.canRedo == true)
    }
    
    // MARK: - Text view delegate
    
    func textViewDidEndEditing(_ textView: UITextView) {
        try? textView.text.write(to: document, atomically: true, encoding: .utf8)
        (splitViewController as? SplitViewController)?.document?.updateDirectory()
    }
    
    func textViewDidChange(_ textView: UITextView) {
        undoItem.isEnabled = (textView.undoManager?.canUndo == true)
        redoItem.isEnabled = (textView.undoManager?.canRedo == true)
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\t" {
            textView.insertText(UserDefaults.standard.string(forKey: "indentation") ?? "    ")
        }
        return text != "\t"
    }
}
