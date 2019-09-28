//
//  DocumentBrowserViewController.swift
//  SeeLess
//
//  Created by Adrian Labbé on 15-09-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import UIKit
import ios_system

fileprivate extension LTTerminalViewController {
    
    @objc func close() {
        dismiss(animated: true, completion: nil)
    }
}

/// The document browser.
class DocumentBrowserViewController: UIDocumentBrowserViewController, UIDocumentBrowserViewControllerDelegate, UIViewControllerTransitioningDelegate {
    
    private var transitionController: UIDocumentBrowserTransitionController?
    
    /// Opens app's settings.
    @objc func openSettings() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
    }
    
    /// Opens LibTerm settings.
    @objc func showLibTermSettings() {
        guard let vc = UIStoryboard(name: "Settings", bundle: nil).instantiateInitialViewController()  as? SettingsTableViewController else {
            return
        }
        let navVC = UINavigationController(rootViewController: vc)
        navVC.modalPresentationStyle = .formSheet
        presentedViewController?.present(navVC, animated: true, completion: nil)
    }
    
    /// Closes presented View controller
    @objc func close() {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Document browser view controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
        
        localizedCreateDocumentActionTitle = "New Project"
        defaultDocumentAspectRatio = 1
        allowsDocumentCreation = true
        allowsPickingMultipleItems = false
        additionalLeadingNavigationBarButtonItems = [UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(openSettings))]
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        #if targetEnvironment(simulator)
        presentDocument(at: Bundle.main.url(forResource: "Hello World", withExtension: "cproj")!)
        #endif
    }
    
    // MARK: Document browser view controller delegate
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
        
        guard let projURL = Bundle.main.url(forResource: "Untitled", withExtension: "cproj") else {
            importHandler(nil, .none)
            return
        }
        
        let alert = UIAlertController(title: "New project", message: "Type the new project's name", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { (_) in
            var title = alert.textFields?.first?.text ?? "Untitled"
            if title.isEmpty || title.replacingOccurrences(of: " ", with: "").isEmpty {
                title = "Untitled"
            }
            title = title.replacingOccurrences(of: "\"", with: "”").replacingOccurrences(of: "'", with: "’")
            let newDocumentURL = FileManager.default.urls(for: .cachesDirectory, in: .allDomainsMask)[0].appendingPathComponent(title+".cproj")
            try? FileManager.default.copyItem(at: projURL, to: newDocumentURL)
            
            importHandler(newDocumentURL, .move)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
            importHandler(nil, .none)
        }))
        alert.addTextField { (textField) in
            textField.placeholder = "Untitled"
        }
        present(alert, animated: true, completion: nil)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt documentURLs: [URL]) {
        guard let sourceURL = documentURLs.first else { return }
        
        // Present the Document View Controller for the first document that was picked.
        // If you support picking multiple items, make sure you handle them all.
        presentDocument(at: sourceURL)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didImportDocumentAt sourceURL: URL, toDestinationURL destinationURL: URL) {
        // Present the Document View Controller for the new newly created document
        presentDocument(at: destinationURL)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, failedToImportDocumentAt documentURL: URL, error: Error?) {
        // Make sure to handle the failed import appropriately, e.g., by presenting an error message to the user.
    }
    
    // MARK: Document Presentation
    
    /// Presents the given document.
    ///
    /// - Parameters:
    ///     - documentURL: The URL of the doucment to open.
    func presentDocument(at documentURL: URL) {
        
        if documentURL.pathExtension.lowercased() == "cproj" {
            let doc = Document(fileURL: documentURL)
            doc.open { (success) in
                if success {
                    let storyBoard = UIStoryboard(name: "Main", bundle: nil)
                    let documentViewController = storyBoard.instantiateViewController(withIdentifier: "Browser") as! SplitViewController
                    documentViewController.document = doc
                    doc.splitViewController = documentViewController
                    
                    documentViewController.modalPresentationStyle = .fullScreen
                    documentViewController.loadViewIfNeeded()
                    
                    documentViewController.transitioningDelegate = self
                    
                    self.transitionController = self.transitionController(forDocumentAt: documentURL)
                    self.transitionController?.loadingProgress = doc.progress
                    self.transitionController?.targetView = documentViewController.view
                    
                    self.present(documentViewController, animated: true, completion: nil)
                } else {
                    let alert = UIAlertController(title: "Error opening project", message: "The project couldn't be opened.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        } else if documentURL.pathExtension.lowercased() == "ll" || documentURL.pathExtension.lowercased() == "bc" {
            
            _ = documentURL.startAccessingSecurityScopedResource()
            
            Document.analyserQueue.async {
                ios_kill()
            }
            
            var configuration = LTTerminalViewController.Preferences()
            configuration.barStyle = .default
            let terminal = LTTerminalViewController.makeTerminal(preferences: configuration, shell: LibShell())
            
            FileBrowserViewController.terminals.append(terminal)
            
            terminal.edgesForExtendedLayout = []
            terminal.navigationItem.leftBarButtonItems = [UIBarButtonItem(barButtonSystemItem: .done, target: terminal, action: #selector(terminal.close))]
            terminal.navigationItem.rightBarButtonItems = [UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(showLibTermSettings))]
            let navVC = UINavigationController(rootViewController: terminal)
            navVC.view.backgroundColor = .systemBackground
            navVC.view.tintColor = .systemOrange
            
            navVC.modalPresentationStyle = .fullScreen
            navVC.loadViewIfNeeded()
            
            navVC.transitioningDelegate = self
            
            self.transitionController = self.transitionController(forDocumentAt: documentURL)
            self.transitionController?.targetView = navVC.view
            
            func run() {
                ios_setDirectoryURL(FileManager.default.urls(for: .documentDirectory, in: .allDomainsMask)[0])
                
                terminal.thread.async {
                    
                    terminal.isAskingForInput = false
                    
                    let path = documentURL.path.replacingOccurrences(of: " ", with: "\\ ").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "'", with: "\\'")
                    terminal.shell.run(command: "echo lli \(path); lli \(path)")
                    sleep(1)
                    terminal.shell.run(command: "echo ''; echo Exited with status code: $?")
                    
                    terminal.shell.history = terminal.shell.history.dropLast(2)
                    
                    terminal.thread.asyncAfter(deadline: .now()+0.5) {
                        terminal.shell.input()
                    }
                }
            }
            
            present(navVC, animated: true, completion: {
                DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: run)
            })
        } else if let editor = UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(identifier: "Editor") as? EditorViewController {
            
            guard documentURL.startAccessingSecurityScopedResource() else {
                return
            }
            
            guard let str = (try? String(contentsOf: documentURL)) else {
                return documentURL.stopAccessingSecurityScopedResource()
            }
            
            editor.text = str
            editor.document = documentURL
            editor.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))
            
            let navVC = UINavigationController(rootViewController: editor)
            navVC.view.backgroundColor = .systemBackground
            navVC.modalPresentationStyle = .fullScreen
            navVC.view.tintColor = .systemOrange
            
            present(navVC, animated: true, completion: nil)
        }
    }
    
    // MARK: - View controller transition delegate
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return transitionController
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return transitionController
    }
}

