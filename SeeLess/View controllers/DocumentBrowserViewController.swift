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
class DocumentBrowserViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating {
    
    /// A folder containing projects.
    class Folder: UIDocument {
        
        /// Reloads directory.
        func reloadDirectory() {
            DispatchQueue.main.async {
                for scene in UIApplication.shared.connectedScenes {
                    for window in (scene as? UIWindowScene)?.windows ?? [] {
                        if let navVC = window.rootViewController as? UINavigationController, let vc = navVC.visibleViewController as? DocumentBrowserViewController {
                            vc.reload()
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
            
            reloadDirectory()
        }
        
        override func accommodatePresentedSubitemDeletion(at url: URL, completionHandler: @escaping (Error?) -> Void) {
            completionHandler(nil)
            
            reloadDirectory()
        }
        
        override func presentedSubitemDidAppear(at url: URL) {
            reloadDirectory()
        }
        
        override func presentedSubitemDidChange(at url: URL) {
            reloadDirectory()
        }
        
        override func presentedSubitem(at oldURL: URL, didMoveTo newURL: URL) {
            reloadDirectory()
        }
    }
    
    /// The local scripts directory.
    static let local = { () -> DocumentBrowserViewController.Folder in
        let folder = Folder(fileURL: FileManager.default.urls(for: .documentDirectory, in: .allDomainsMask)[0])
        folder.open(completionHandler: nil)
        return folder
    }()
    
    /// The iCloud folder.
    static var iCloud = { () -> DocumentBrowserViewController.Folder? in
                
        guard let iCloud = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") else {
            return nil
        }
        
        let folder = Folder(fileURL: iCloud)
        folder.open(completionHandler: nil)
        return folder
    }()
    
    /// The current directory.
    var directory: URL = DocumentBrowserViewController.local.fileURL {
        didSet {
            navigationItem.largeTitleDisplayMode = .never
        }
    }
    
    /// Files in `directory`.
    var files = [URL]()
    
    /// Files found with search.
    var filtredFiles: [URL]?
    
    /// The Table view containing projects.
    @IBOutlet weak var tableView: UITableView!
    
    /// Opens app's settings.
    @IBAction func openSettings(_ sender: Any) {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
    }
    
    /// Creates a project.
    @IBAction func createProject(_ sender: Any) {
        guard let projURL = Bundle.main.url(forResource: "Untitled", withExtension: "cproj") else {
            return
        }
        
        let directory: URL
        if self.directory.resolvingSymlinksInPath() == DocumentBrowserViewController.local.fileURL.resolvingSymlinksInPath(), let iCloud = DocumentBrowserViewController.iCloud?.fileURL {
            directory = iCloud
        } else {
            directory = self.directory
        }
        
        let alert = UIAlertController(title: "New project", message: "Type the new project's name", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { (_) in
            var title = alert.textFields?.first?.text ?? "Untitled"
            if title.isEmpty || title.replacingOccurrences(of: " ", with: "").isEmpty {
                title = "Untitled"
            }
            title = title.replacingOccurrences(of: "\"", with: "”").replacingOccurrences(of: "'", with: "’")
            try? FileManager.default.copyItem(at: projURL, to: directory.appendingPathComponent(title).appendingPathExtension("cproj"))
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addTextField { (textField) in
            textField.placeholder = "Untitled"
        }
        present(alert, animated: true, completion: nil)
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
    
    /// The document that will be opened on `viewDidAppear(_:)`.
    var documentURL: URL?
    
    /// Reloads files.
    func reload() {
        var files = [URL]()
        if directory.resolvingSymlinksInPath() == DocumentBrowserViewController.local.fileURL.resolvingSymlinksInPath(), let iCloud = DocumentBrowserViewController.iCloud?.fileURL {
            files = FileManager.default.listFiles(path: iCloud.path)+FileManager.default.listFiles(path: directory.path)
        } else {
            files = FileManager.default.listFiles(path: directory.path)
        }
        
        self.files = []
        for file in files {
            
            var hidden = false
            for component in file.pathComponents {
                if component.hasPrefix(".") {
                    
                    if component.hasSuffix(".icloud") {
                        var name = file.lastPathComponent
                        name.removeFirst()
                        self.files.append(file.deletingLastPathComponent().appendingPathComponent(name).deletingPathExtension())
                    }
                    
                    hidden = true
                    break
                } else if component.lowercased().hasSuffix(".cproj") && file.pathExtension.lowercased() != "cproj" {
                    
                    hidden = true
                    break
                }
            }
            if hidden {
                continue
            }
                        
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: file.path, isDirectory: &isDir) && ((isDir.boolValue && file.pathExtension.lowercased() == "cproj") || file.pathExtension.lowercased() == "ll" || file.pathExtension.lowercased() == "bc") {
                self.files.append(file)
            }
        }
        
        tableView.reloadData()
    }
    
    // MARK: - Document browser view controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let controller = UISearchController(searchResultsController: nil)
        controller.obscuresBackgroundDuringPresentation = false
        controller.automaticallyShowsCancelButton = true
        controller.searchResultsUpdater = self
        controller.searchBar.autocorrectionType = .no
        
        definesPresentationContext = true
        navigationItem.searchController = controller
        
        reload()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        view.window?.windowScene?.title = ""
        
        if let docURL = documentURL {
            presentDocument(at: docURL)
            documentURL = nil
        }
        
        #if targetEnvironment(simulator)
        presentDocument(at: Bundle.main.url(forResource: "Hello World", withExtension: "cproj")!)
        #endif
        
        ReviewHelper.shared.requestReview()
    }
    
    // MARK: Document Presentation
    
    /// Presents the given document.
    ///
    /// - Parameters:
    ///     - documentURL: The URL of the doucment to open.
    ///     - arguments: Arguments to pass to the program if the passed file is a program.
    func presentDocument(at documentURL: URL, arguments: String? = nil) {
        
        if documentURL.pathExtension.lowercased() == "cproj" {
            let doc = Document(fileURL: documentURL)
            doc.open { (success) in
                if success {
                    let storyBoard = UIStoryboard(name: "Main", bundle: nil)
                    let documentViewController = storyBoard.instantiateViewController(withIdentifier: "Browser") as! SplitViewController
                    documentViewController.document = doc
                    doc.splitViewController = documentViewController
                    
                    documentViewController.modalPresentationStyle = .fullScreen
                    documentViewController.modalTransitionStyle = .crossDissolve
                    documentViewController.loadViewIfNeeded()
                    
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
            terminal.edgesForExtendedLayout = []
            
            FileBrowserViewController.terminals.append(terminal)
            
            terminal.edgesForExtendedLayout = []
            terminal.navigationItem.leftBarButtonItems = [UIBarButtonItem(barButtonSystemItem: .done, target: terminal, action: #selector(terminal.close))]
            terminal.navigationItem.rightBarButtonItems = [UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(showLibTermSettings))]
            let navVC = UINavigationController(rootViewController: terminal)
            navVC.view.backgroundColor = .systemBackground
            navVC.view.tintColor = .systemOrange
            
            navVC.modalPresentationStyle = .fullScreen
            navVC.loadViewIfNeeded()
            
            func run() {
                ios_setDirectoryURL(FileManager.default.urls(for: .documentDirectory, in: .allDomainsMask)[0])
                
                terminal.thread.async {
                    
                    terminal.isAskingForInput = false
                    
                    let path = documentURL.path.replacingOccurrences(of: " ", with: "\\ ").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "'", with: "\\'")
                    terminal.shell.run(command: "echo lli \(path)\(arguments != nil && !arguments!.isEmpty ? " "+arguments! : "")")
                    sleep(UInt32(0.2))
                    terminal.shell.run(command: "lli \(path)\(arguments != nil && !arguments!.isEmpty ? " "+arguments! : "")")
                    sleep(1)
                    terminal.shell.run(command: "echo")
                    sleep(UInt32(0.2))
                    terminal.shell.run(command: "echo Exited with status code: $?")
                    
                    terminal.shell.history = terminal.shell.history.dropLast(4)
                    
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
    
    // MARK: - Table view data source
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (filtredFiles ?? files).count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let file = (filtredFiles ?? files)[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "project", for: indexPath)
        cell.textLabel?.text = file.deletingPathExtension().lastPathComponent
        if file.deletingLastPathComponent().resolvingSymlinksInPath() == DocumentBrowserViewController.local.fileURL.resolvingSymlinksInPath() {
            cell.detailTextLabel?.text = "In Local Storage"
        } else if file.deletingLastPathComponent().resolvingSymlinksInPath() == DocumentBrowserViewController.iCloud?.fileURL.resolvingSymlinksInPath() {
            cell.detailTextLabel?.text = "In iCloud"
        } else {
            cell.detailTextLabel?.text = file.deletingLastPathComponent().lastPathComponent
        }
        
        var isDir: ObjCBool = true
        if FileManager.default.fileExists(atPath: file.path, isDirectory: &isDir) {
            if isDir.boolValue {
                cell.imageView?.image = UIImage(systemName: "folder")
            } else {
                cell.imageView?.image = UIImage(systemName: "doc")
            }
        } else {
            cell.imageView?.image = UIImage(systemName: "icloud.and.arrow.down")
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        let file = (filtredFiles ?? files)[indexPath.row]
        
        if editingStyle == .delete {
            do {
                do {
                    try FileManager.default.trashItem(at: file, resultingItemURL: nil)
                } catch {
                    try FileManager.default.removeItem(at: file)
                }
                
                if filtredFiles != nil {
                    filtredFiles?.remove(at: indexPath.row)
                } else {
                    files.remove(at: indexPath.row)
                }
                
                tableView.deleteRows(at: [indexPath], with: .automatic)
            } catch {
                let alert = UIAlertController(title: "Error removing file", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                present(alert, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - Table view delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        presentDocument(at: (filtredFiles ?? files)[indexPath.row])
    }
    
    // MARK: - Search results updating
    
    func updateSearchResults(for searchController: UISearchController) {
        
        if let text = searchController.searchBar.text, !text.isEmpty, searchController.isActive {
            filtredFiles = []
            for file in files {
                if file.deletingPathExtension().lastPathComponent.lowercased().contains(text.lowercased()) {
                    filtredFiles?.append(file)
                } else if file.deletingLastPathComponent().deletingPathExtension().lastPathComponent.contains(text.lowercased()) &&
                    file.deletingLastPathComponent().resolvingSymlinksInPath() != DocumentBrowserViewController.local.fileURL.resolvingSymlinksInPath() &&
                    file.deletingLastPathComponent().resolvingSymlinksInPath() != DocumentBrowserViewController.iCloud?.fileURL.resolvingSymlinksInPath() {
                    
                    filtredFiles?.append(file)
                }
            }
        } else {
            filtredFiles = nil
        }
        
        tableView.reloadData()
    }
}

