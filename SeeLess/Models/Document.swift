//
//  Document.swift
//  SeeLess
//
//  Created by Adrian Labbé on 15-09-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import UIKit
import ios_system

/// A document representing a C project.
class Document: UIDocument {
    
    /// The Split view controller currently managing the project.
    var splitViewController: SplitViewController?
    
    /// Warnings and errors for each file.
    var warnings = [URL:String]() {
        didSet {
            if warnings.count > 0 {
                let item = UIBarButtonItem(image: UIImage(systemName: "exclamationmark.triangle.fill"), style: .plain, target: self.splitViewController, action: #selector(self.splitViewController?.showIssues))
                (self.splitViewController?.viewControllers.first as? UINavigationController)?.topViewController?.toolbarItems = [
                    item,
                    UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                    UIBarButtonItem(title: "Build", style: .plain, target: self.splitViewController, action: #selector(self.splitViewController?.build(_:))),
                    UIBarButtonItem(barButtonSystemItem: .play, target: self.splitViewController, action: #selector(self.splitViewController?.build(_:)))
                ]
            } else {
                (self.splitViewController?.viewControllers.first as? UINavigationController)?.topViewController?.toolbarItems = [
                    UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                    UIBarButtonItem(title: "Build", style: .plain, target: self.splitViewController, action: #selector(self.splitViewController?.build(_:))),
                    UIBarButtonItem(barButtonSystemItem: .play, target: self.splitViewController, action: #selector(self.splitViewController?.build(_:)))
                ]
            }
        }
    }
    
    /// A queue where clang analyses sources.
    static let analyserQueue = DispatchQueue.global()
    
    /// A boolean indicating if clang is analysing a project.
    static var isAnalyzing = false
    
    /// A boolean indicating if the app is compiling a project.
    static var isCompiling = false {
        didSet {
            DispatchQueue.main.async {
                for window in UIApplication.shared.windows {
                    guard let splitVC = window.rootViewController?.presentedViewController as? SplitViewController else {
                        continue
                    }
                    
                    guard let vc = (splitVC.viewControllers.first as? UINavigationController)?.topViewController else {
                        continue
                    }
                    
                    for item in vc.toolbarItems ?? [] {
                        item.isEnabled = !self.isCompiling
                    }
                    
                    vc.navigationItem.rightBarButtonItems?.first?.isEnabled = !self.isCompiling
                }
            }
        }
    }
    
    /// Kills clang analyser.
    func killAnalyser() {
        Document.analyserQueue.async {
            ios_kill()
        }
    }
    
    /// Checks for errors on given files.
    ///
    /// - Parameters:
    ///     - files: An array of files to analyse. Only C and Header files will be checked.
    func checkForErrors(files: [URL]) {
        
        if !Thread.current.isMainThread {
            return DispatchQueue.main.async {
                self.checkForErrors(files: files)
            }
        }
        
        let topVC = (self.splitViewController?.viewControllers.first as? UINavigationController)?.topViewController
        guard topVC?.toolbarItems?.last?.isEnabled == true, (topVC as? LTTerminalViewController)?.terminalTextView.isFirstResponder != true else {
            return
        }
        
        self.killAnalyser()
        
        guard !Document.isAnalyzing else {
            return
        }
        
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        let item = UIBarButtonItem(customView: activityIndicator)
        activityIndicator.startAnimating()
        (self.splitViewController?.viewControllers.first as? UINavigationController)?.topViewController?.toolbarItems = [
            item,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "Build", style: .plain, target: self.splitViewController, action: #selector(self.splitViewController?.build(_:))),
            UIBarButtonItem(barButtonSystemItem: .play, target: self.splitViewController, action: #selector(self.splitViewController?.build(_:)))
        ]
        
        for item in topVC?.toolbarItems ?? [] {
            item.isEnabled = false
        }
        
        Document.analyserQueue.async {
            
            Document.isCompiling = true
            Document.isAnalyzing = true
            
            var currentFile: URL!
            
            var warnings = self.warnings
            
            thread_stdout = nil
            thread_stderr = nil
            thread_stdin = nil
            
            let outPipe = Pipe()
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                if let str = String(data: handle.availableData, encoding: .utf8) {
                    print(str, terminator: "")
                }
            }
            let errPipe = Pipe()
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                if let str = String(data: handle.availableData, encoding: .utf8), !str.isEmpty {
                    warnings[currentFile] = (warnings[currentFile] ?? "")+str
                    print(str, terminator: "")
                }
            }
            let inPipe = Pipe()
            
            let _stdout = fdopen(outPipe.fileHandleForWriting.fileDescriptor, "w")
            let _stderr = fdopen(errPipe.fileHandleForWriting.fileDescriptor, "w")
            let _stdin = fdopen(inPipe.fileHandleForReading.fileDescriptor, "r")
            
            ios_switchSession(_stdout)
            ios_setStreams(_stdin, _stdout, _stderr)
            
            let cwd = self.fileURL.appendingPathComponent("build").appendingPathComponent("objects")
            var isDir: ObjCBool = false
            if !FileManager.default.fileExists(atPath: cwd.path, isDirectory: &isDir) || !isDir.boolValue {
                if !isDir.boolValue {
                    try? FileManager.default.removeItem(at: cwd)
                }
                try? FileManager.default.createDirectory(at: cwd, withIntermediateDirectories: true, attributes: nil)
            }
            
            ios_setDirectoryURL(cwd)
            sleep(UInt32(0.2))
            
            for file in files {
                if file.pathExtension.lowercased() == "c" || file.pathExtension.lowercased() == "h" {
                    warnings[file.resolvingSymlinksInPath()] = nil
                    currentFile = file.resolvingSymlinksInPath()
                    ios_system("pwd")
                    ios_system("clang -fcolor-diagnostics --config \(cwd.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("configuration/configuration.txt").path.replacingOccurrences(of: " ", with: "\\ ").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\"", with: "\\\"")) -fsyntax-only \(file.path.replacingOccurrences(of: " ", with: "\\ ").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\"", with: "\\\""))")
                    sleep(UInt32(0.2))
                }
            }
            
            DispatchQueue.main.async {
                for item in topVC?.toolbarItems ?? [] {
                    item.isEnabled = true
                }
                self.warnings = warnings
            }
            
            Document.isAnalyzing = false
            Document.isCompiling = false
        }
    }
    
    /// Updates directories content on file browsers and check for warnings and errors.
    func updateDirectory() {
        DispatchQueue.main.async {
            for vc in self.splitViewController?.viewControllers ?? [] {
                if let browser = (vc as? UINavigationController)?.topViewController as? FileBrowserViewController {
                    if browser.files != (try? FileManager.default.contentsOfDirectory(at: browser.directory, includingPropertiesForKeys: nil, options: [])) {
                        browser.load()
                    }
                }
            }
        }
    }
    
    // MARK: - Document
    
    override func contents(forType typeName: String) throws -> Any {
        // Encode your document with an instance of NSData or NSFileWrapper
        return Data()
    }
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        // Load your document from contents
    }
    
    override func presentedItemDidChange() {
        super.presentedItemDidChange()
        
        updateDirectory()
    }
    
    override func accommodatePresentedSubitemDeletion(at url: URL, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
        
        updateDirectory()
        warnings[url] = nil
    }
    
    override func presentedSubitemDidAppear(at url: URL) {
        updateDirectory()
        checkForErrors(files: [url])
    }
    
    override func presentedSubitemDidChange(at url: URL) {
        DispatchQueue.main.async {
            if let editor = ((self.splitViewController?.viewControllers.last as? UINavigationController)?.topViewController as? EditorViewController) ?? ((self.splitViewController?.viewControllers.last as? UINavigationController)?.topViewController as? UINavigationController)?.topViewController as? EditorViewController, editor.document.resolvingSymlinksInPath() == url.resolvingSymlinksInPath() {
                let text = (try? String(contentsOf: url))
                if text != editor.textView.text {
                    editor.textView.text = text
                }
            }
            
            self.updateDirectory()
            self.checkForErrors(files: [url])
        }
    }
    
    override func presentedSubitem(at oldURL: URL, didMoveTo newURL: URL) {
        updateDirectory()
        warnings[oldURL] = nil
        checkForErrors(files: [newURL])
    }
}

