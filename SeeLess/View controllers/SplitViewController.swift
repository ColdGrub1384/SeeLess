//
//  SplitViewController.swift
//  SeeLess
//
//  Created by Adrian Labbé on 16-09-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import UIKit
import ios_system

/// A Split view controller containing a file browser and a terminal or a code editor.
class SplitViewController: UISplitViewController, UINavigationControllerDelegate {
    
    /// The current project.
    var document: Document?
    
    /// The terminal corresponding to this project.
    var terminal: LTTerminalViewController!
    
    /// Closes this View controller.
    @objc func close() {
        dismiss(animated: true) {}
    }
    
    /// Shows warning and errors.
    @objc func showIssues() {
        
        guard let doc = document else {
            return
        }
        
        var files = [URL]()
        var issues = [String]()
        
        for (key, value) in doc.warnings {
            files.append(key)
            issues.append(value)
        }
        
        let tableVC = BuildIssuesTableViewController(files: files, issues: issues)
        
        let navVC = UINavigationController(rootViewController: tableVC)
        navVC.loadViewIfNeeded()
        navVC.view.tintColor = .orange
        
        present(navVC, animated: true, completion: nil)
    }
    
    /// Show LibTerm settings.
    @objc func showSettings() {
        guard let vc = UIStoryboard(name: "Settings", bundle: nil).instantiateInitialViewController()  as? SettingsTableViewController else {
            return
        }
        let navVC = UINavigationController(rootViewController: vc)
        navVC.modalPresentationStyle = .formSheet
        present(navVC, animated: true, completion: nil)
    }
    
    /// Builds project.
    @objc func build(_ sender: Any) {
        
        guard (self.viewControllers.first as? UINavigationController)?.topViewController?.toolbarItems?.last?.isEnabled != false else {
            return
        }
        
        guard let directory = document?.fileURL else {
            return
        }
        
        let terminal = self.terminal!
        
        putenv("VERBOSE=\(UserDefaults.standard.bool(forKey: "verbose") ? 1 : 0)".cValue)
        
        document?.killAnalyser()
        
        for item in (viewControllers.first as? UINavigationController)?.topViewController?.toolbarItems ?? [] {
            item.isEnabled = false
        }
        Document.isCompiling = true
        
        terminal.shell.variables["PRODUCT_NAME"] = directory.deletingPathExtension().appendingPathExtension("bc").lastPathComponent.replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\"", with: "\\\"")
        terminal.shell.variables["CONFIG_DIR"] = directory.appendingPathComponent("configuration").path.replacingOccurrences(of: " ", with: "\\ ").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\"", with: "\\\"")
        FileBrowserViewController.terminals.append(terminal)
        
        if let item = splitViewController?.displayModeButtonItem {
            terminal.navigationItem.leftBarButtonItems = [item]
            terminal.navigationItem.rightBarButtonItems = [UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(showSettings))]
        }
        let navVC = UINavigationController(rootViewController: terminal)
        navVC.view.backgroundColor = .systemBackground
        showDetailViewController(navVC, sender: nil)
        
        let queue = terminal.thread
        queue.asyncAfter(deadline: .now()+1) {
            terminal.isAskingForInput = false
            terminal.shell.run(command: "echo", appendToHistory: false)
            
            terminal.shell.run(command: "sh '\(directory.appendingPathComponent("configuration/build.sh").path)'", appendToHistory: false)
            
            if let productName = terminal.shell.variables["PRODUCT_NAME"]?.replacingOccurrences(of: "\\ ", with: " ").replacingOccurrences(of: "\\'", with: "'").replacingOccurrences(of: "\\\"", with: "\""), FileManager.default.fileExists(atPath: directory.appendingPathComponent("build/\(productName)").path) {
                
                ios_system("cd \(directory.appendingPathComponent("build").path.replacingOccurrences(of: " ", with: "\\ ").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "'", with: "\\'"))")
                
                for file in FileManager.default.listFiles(path: directory.path) {
                    if file.pathExtension.lowercased() == "h" || file.pathExtension.lowercased() == "hpp", let path = file.relativePath(from: directory)  {
                        
                        guard !file.resolvingSymlinksInPath().path.contains(directory.appendingPathComponent("lib").resolvingSymlinksInPath().path) else {
                            continue
                        }
                        
                        let newURL = directory.appendingPathComponent("build/include").appendingPathComponent(path)
                        if !FileManager.default.fileExists(atPath: newURL.deletingLastPathComponent().path) {
                            try? FileManager.default.createDirectory(at: newURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                        }
                        FileManager.default.createFile(atPath: newURL.path, contents: try? Data(contentsOf: file), attributes: nil)
                    }
                }
                
                if (sender is UIBarButtonItem && (sender as! UIBarButtonItem).title?.isEmpty != false) || (sender is UIKeyCommand && (sender as! UIKeyCommand).input == "r") {
                    terminal.shell.run(command: "echo Running $PRODUCT_NAME...")
                    terminal.shell.run(command: "echo")
                    terminal.shell.run(command: "lli $PRODUCT_NAME")
                    sleep(UInt32(1))
                    terminal.shell.run(command: "echo")
                    terminal.shell.run(command: "echo Exited with status code: $?")
                    
                    terminal.shell.history = terminal.shell.history.dropLast(3)
                }
            }
            
            queue.asyncAfter(deadline: .now()+1) {
                terminal.shell.input()
            }
            
            DispatchQueue.main.async {
                for item in (self.viewControllers.first as? UINavigationController)?.topViewController?.toolbarItems ?? [] {
                    item.isEnabled = true
                }
            }
            
            Document.isCompiling = false
        }
    }
    
    private var appeared = false
    
    // MARK: - Split view controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var configuration = LTTerminalViewController.Preferences()
        configuration.barStyle = .default
        terminal = LTTerminalViewController.makeTerminal(preferences: configuration, shell: LibShell())
        terminal.edgesForExtendedLayout = []
        
        view.tintColor = .systemOrange
        preferredDisplayMode = .allVisible
        
        view.backgroundColor = .systemBackground
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        for scene in UIApplication.shared.connectedScenes {
            let splitVC = (scene as? UIWindowScene)?.windows.first?.rootViewController?.presentedViewController as? SplitViewController
            if splitVC?.document?.fileURL.resolvingSymlinksInPath() == document?.fileURL.resolvingSymlinksInPath(), splitVC !== self {
                (scene as? UIWindowScene)?.windows.first?.rootViewController?.dismiss(animated: true, completion: nil)
            }
        }
        
        if !appeared {
            let browserVC = FileBrowserViewController()
            browserVC.document = document
            browserVC.directory = self.document?.fileURL
            browserVC.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.close))
            browserVC.toolbarItems = [
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                UIBarButtonItem(title: "Build", style: .plain, target: self, action: #selector(build(_:))),
                UIBarButtonItem(barButtonSystemItem: .play, target: self, action: #selector(build(_:)))
            ]
            
            let browser = UINavigationController(rootViewController: browserVC)
            browser.isToolbarHidden = false
            browser.delegate = self
                    
            viewControllers = [browser]
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !isCollapsed, !appeared {
            ((viewControllers.first as? UINavigationController)?.viewControllers.first as? FileBrowserViewController)?.openTerminal()
            _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { (timer) in
                if let txtView = self.terminal.terminalTextView, txtView.isFirstResponder {
                    txtView.resignFirstResponder()
                    timer.invalidate()
                }
                self.document?.warnings = [:]
                
                DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
                    self.document?.checkForErrors(files: FileManager.default.listFiles(path: self.document!.fileURL.path))
                }
            })
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
                self.document?.checkForErrors(files: FileManager.default.listFiles(path: self.document!.fileURL.path))
            }
        }
        
        appeared = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        document?.close(completionHandler: nil)
    }
    
    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(title: "Build", image: nil, action: #selector(build), input: "b", modifierFlags: .command, propertyList: nil, alternates: [], discoverabilityTitle: "Build", attributes: [], state: .off),
            UIKeyCommand(title: "Build & Run", image: nil, action: #selector(build), input: "r", modifierFlags: .command, propertyList: nil, alternates: [], discoverabilityTitle: "Build & Run", attributes: [], state: .off),
        ]
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    // MARK: - Navigation controller delegate
    
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        
        guard let i = navigationController.viewControllers.firstIndex(of: viewController), navigationController.viewControllers.indices.contains(i-1) else {
            return
        }
        
        let items = navigationController.viewControllers[i-1].toolbarItems
        navigationController.topViewController?.toolbarItems = []
        viewController.toolbarItems = items
    }
}
