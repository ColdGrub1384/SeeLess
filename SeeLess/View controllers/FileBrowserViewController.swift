//
//  FileBrowserViewController.swift
//  SeeLess
//
//  Created by Adrian Labbé on 16-09-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import UIKit
import QuickLook
import ios_system
import MobileCoreServices
import StoreKit

/// The file browser used to manage files inside a project.
class FileBrowserViewController: UITableViewController, UIDocumentPickerDelegate, UIContextMenuInteractionDelegate, UITableViewDragDelegate, UITableViewDropDelegate {
    
    /// All initialized terminals.
    static var terminals = [LTTerminalViewController]()
    
    private struct LocalFile {
        var url: URL
        var directory: URL
    }
    
    /// A type of file.
    enum FileType {
        
        /// C source.
        case c
        
        /// Header.
        case header
        
        /// Blank file.
        case blank
        
        /// Folder.
        case folder
    }
    
    /// FIles in the directory.
    var files = [URL]()
    
    /// The directory to browse.
    var directory: URL! {
        didSet {
            title = directory.lastPathComponent
            load()
        }
    }
    
    /// The C project.
    var document: Document?
    
    /// Loads directory.
    func load() {
        tableView.backgroundView = nil
        do {
            var files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [])
            let projURL = document?.fileURL.resolvingSymlinksInPath()
            
            for file in files {
                if file.resolvingSymlinksInPath() == projURL?.appendingPathComponent("configuration/build.sh") ||
                    file.resolvingSymlinksInPath() == projURL?.appendingPathComponent("configuration/find_sources.py") ||
                    file.resolvingSymlinksInPath().lastPathComponent.hasPrefix(".git"),
                    let i = files.firstIndex(of: file) {
                    files.remove(at: i)
                }
            }
            
            self.files = files
            
            tableView.reloadData()
        } catch {
            files = []
            tableView.reloadData()
            
            let textView = UITextView()
            textView.isEditable = false
            textView.text = error.localizedDescription
            tableView.backgroundView = textView
        }
    }
    
    /// Creates a file with given file type.
    ///
    /// - Parameters:
    ///     - type: The file type.
    func createFile(type: FileType) {
        
        func present(error: Error) {
            let alert = UIAlertController(title: "Error creating file", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
        
        let alert = UIAlertController(title: "New \(type == .c ? "C file" : (type == .folder ? "Folder" : (type == .header ? "Header" : "Blank file")))", message: "Type the new \(type == .folder ? "folder" : "file") name", preferredStyle: .alert)
        
        var textField: UITextField!
        
        alert.addAction(UIAlertAction(title: "Create\(type == .c ? " C file" : "")", style: .default, handler: { (_) in
            do {
                var name = textField.text ?? "Untitled"
                if name.replacingOccurrences(of: " ", with: "").isEmpty {
                    name = "Untitled"
                }
                if type == .c {
                    name += ".c"
                } else if type == .header {
                    name += ".h"
                }
                
                if type == .folder {
                    try FileManager.default.createDirectory(at: self.directory.appendingPathComponent(name), withIntermediateDirectories: true, attributes: nil)
                } else {
                    if !FileManager.default.createFile(atPath: self.directory.appendingPathComponent(name).path, contents: (type == .c ? "#include <stdio.h>\n\n" : (type == .header ? "#include <stdio.h>" : "")).data(using: .utf8), attributes: nil) {
                        throw NSError(domain: "SeeLess.errorCreatingFile", code: 1, userInfo: [NSLocalizedDescriptionKey : "Error creating file"])
                    }
                }
            } catch {
                present(error: error)
            }
        }))
        
        if type == .c {
            alert.addAction(UIAlertAction(title: "Create C file & header", style: .default, handler: { (_) in
                var name = textField.text ?? "Untitled"
                if name.replacingOccurrences(of: " ", with: "").isEmpty {
                    name = "Untitled"
                }
                
                do {
                    if !FileManager.default.createFile(atPath: self.directory.appendingPathComponent(name+".c").path, contents: "#include \"\(name+".h")\"\n\n".data(using: .utf8), attributes: nil) {
                        throw NSError(domain: "SeeLess.errorCreatingFile", code: 1, userInfo: [NSLocalizedDescriptionKey : "Error creating file"])
                    }
                    
                    if !FileManager.default.createFile(atPath: self.directory.appendingPathComponent(name+".h").path, contents: "#include <stdio.h>\n\n".data(using: .utf8), attributes: nil) {
                        throw NSError(domain: "SeeLess.errorCreatingFile", code: 1, userInfo: [NSLocalizedDescriptionKey : "Error creating file"])
                    }
                } catch {
                    present(error: error)
                }
            }))
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        alert.addTextField { (_textField) in
            textField = _textField
            textField.placeholder = "Untitled"
        }
        
        self.present(alert, animated: true, completion: nil)
    }
    
    /// Creates a new file.
    @objc func createNewFile(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "New file", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "C source", style: .default, handler: { (_) in
            self.createFile(type: .c)
        }))
        
        alert.addAction(UIAlertAction(title: "Header", style: .default, handler: { (_) in
            self.createFile(type: .header)
        }))
        
        alert.addAction(UIAlertAction(title: "Blank file", style: .default, handler: { (_) in
            self.createFile(type: .blank)
        }))
        
        alert.addAction(UIAlertAction(title: "Folder", style: .default, handler: { (_) in
            self.createFile(type: .folder)
        }))
        
        alert.addAction(UIAlertAction(title: "Import from Files", style: .default, handler: { (_) in
            let vc = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
            vc.allowsMultipleSelection = true
            vc.delegate = self
            self.present(vc, animated: true, completion: nil)
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        alert.popoverPresentationController?.barButtonItem = sender
        present(alert, animated: true, completion: nil)
    }
    
    /// Shows LibTerm settings.
    @objc func showSettings() {
        guard let vc = UIStoryboard(name: "Settings", bundle: nil).instantiateInitialViewController()  as? SettingsTableViewController else {
            return
        }
        let navVC = UINavigationController(rootViewController: vc)
        navVC.modalPresentationStyle = .formSheet
        present(navVC, animated: true, completion: nil)
    }
    
    /// Opens LibTerm.
    @objc func openTerminal() {
        
        (splitViewController as? SplitViewController)?.document?.killAnalyser()
        
        guard let terminal = (splitViewController as? SplitViewController)?.terminal else {
            return
        }
        
        func run() {
            terminal.shell.variables["PRODUCT_NAME"] = (splitViewController as? SplitViewController)?.document?.fileURL.deletingPathExtension().appendingPathExtension("bc").lastPathComponent.replacingOccurrences(of: " ", with: "-")
            FileBrowserViewController.terminals.append(terminal)
            
            terminal.edgesForExtendedLayout = []
            terminal.navigationItem.leftItemsSupplementBackButton = true
            if let item = splitViewController?.displayModeButtonItem {
                terminal.navigationItem.leftBarButtonItems = [item]
                terminal.navigationItem.rightBarButtonItems = [UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(showSettings))]
            }
            DispatchQueue.global().asyncAfter(deadline: .now()+0.5) {
                terminal.shell.run(command: "cd \(self.directory.path.replacingOccurrences(of: " ", with: "\\ ").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "'", with: "\\'"))", appendToHistory: false)
                DispatchQueue.main.async {
                    terminal.title = self.directory.lastPathComponent
                }
            }
        }
        
        let navVC = UINavigationController(rootViewController: terminal)
        navVC.view.backgroundColor = .systemBackground
        splitViewController?.showDetailViewController(navVC, sender: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: run)
    }
    
    // MARK: - Table view controller
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView.reloadData()
        navigationItem.rightBarButtonItems?.first?.isEnabled = !Document.isCompiling
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        clearsSelectionOnViewWillAppear = true
        tableView.tableFooterView = UIView()
        
        tableView.dragDelegate = self
        tableView.dropDelegate = self
        
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(systemName: "chevron.right"), style: .plain, target: self, action: #selector(openTerminal)),
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(createNewFile(_:)))
        ]
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return files.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = files[indexPath.row].lastPathComponent
        
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: files[indexPath.row].path, isDirectory: &isDir) && isDir.boolValue {
            cell.imageView?.image = UIImage(systemName: "folder.fill")
            cell.accessoryType = .disclosureIndicator
        } else {
            cell.imageView?.image = UIImage(systemName: "doc.fill")
            cell.accessoryType = .none
        }
        
        cell.contentView.alpha = files[indexPath.row].lastPathComponent.hasPrefix(".") ? 0.5 : 1
        
        let interaction = UIContextMenuInteraction(delegate: self)
        cell.addInteraction(interaction)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: files[indexPath.row].path, isDirectory: &isDir) && isDir.boolValue {
            let browser = FileBrowserViewController()
            browser.document = document
            browser.directory = files[indexPath.row]
            navigationController?.pushViewController(browser, animated: true)
        } else if let editor = UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(identifier: "Editor") as? EditorViewController {
                        
            if let str = (try? String(contentsOf: files[indexPath.row])) {
                editor.text = str
                editor.document = files[indexPath.row]
                let navVC = UINavigationController(rootViewController: editor)
                navVC.view.backgroundColor = .systemBackground
                self.splitViewController?.showDetailViewController(navVC, sender: nil)
            } else {
                
                class DataSource: NSObject, QLPreviewControllerDataSource {
                    
                    var urls: [URL]
                    
                    init(urls: [URL]) {
                        self.urls = urls
                    }
                    
                    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
                        return urls.count
                    }
                    
                    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
                        return urls[index] as QLPreviewItem
                    }
                }
                
                var files = [URL]()
                var index = 0
                
                for (i, file) in self.files.enumerated() {
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: file.path, isDirectory: &isDir), !isDir.boolValue {
                        files.append(file)
                        if file == self.files[indexPath.row] {
                            index = i
                        }
                    }
                }
                
                let dataSource = DataSource(urls: files)
                
                let vc = QLPreviewController()
                vc.dataSource = dataSource
                vc.currentPreviewItemIndex = index
                self.present(vc, animated: true, completion: nil)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            do {
                try FileManager.default.removeItem(at: files[indexPath.row])
                files.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
            } catch {
                let alert = UIAlertController(title: "Error deleting file", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                present(alert, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - Table view drag delegate
    
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        
        let file = files[indexPath.row]
        
        let item = UIDragItem(itemProvider: NSItemProvider())
        item.itemProvider.registerObject(file.path.replacingOccurrences(of: " ", with: "\\ ").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\"", with: "\\\"") as NSItemProviderWriting, visibility: .ownProcess)
        
        item.itemProvider.registerFileRepresentation(forTypeIdentifier: (try? file.resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier ?? kUTTypeItem as String, fileOptions: .openInPlace, visibility: .all) { (handler) -> Progress? in
            
            handler(file, true, nil)
            
            let progress = Progress(totalUnitCount: 1)
            progress.completedUnitCount = 1
            return progress
        }
        
        item.itemProvider.suggestedName = file.lastPathComponent
        item.localObject = LocalFile(url: file, directory: directory)
        
        return [item]
    }
    
    // MARK: - Table view drop delegate
    
    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        return session.hasItemsConforming(toTypeIdentifiers: [kUTTypeItem as String])
    }
    
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        
        for item in coordinator.items {
            if item.dragItem.itemProvider.hasItemConformingToTypeIdentifier(kUTTypeItem as String) {
                
                item.dragItem.itemProvider.loadInPlaceFileRepresentation(forTypeIdentifier: kUTTypeItem as String, completionHandler: { (file, inPlace, error) in
                    
                    guard let destination = (coordinator.destinationIndexPath != nil ? self.files[coordinator.destinationIndexPath!.row] : self.directory) else {
                        return
                    }
                    
                    if let error = error {
                        print(error.localizedDescription)
                    }
                    
                    if let file = file {
                        
                        let fileName = file.lastPathComponent
                        
                        _ = file.startAccessingSecurityScopedResource()
                        
                        if coordinator.proposal.operation == .move {
                            try? FileManager.default.moveItem(at: file, to: destination.appendingPathComponent(fileName))
                        } else if coordinator.proposal.operation == .copy {
                            try? FileManager.default.copyItem(at: file, to: destination.appendingPathComponent(fileName))
                        }
                        
                        file.stopAccessingSecurityScopedResource()
                        
                        DispatchQueue.main.async {
                            self.load()
                        }
                    }
                })
            }
        }
    }
    
    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        
        var isDir: ObjCBool = false
        if destinationIndexPath == nil || !(destinationIndexPath != nil && files.indices.contains(destinationIndexPath!.row) && FileManager.default.fileExists(atPath: files[destinationIndexPath!.row].path, isDirectory: &isDir) && isDir.boolValue) {
            
            if destinationIndexPath == nil && (session.items.first?.localObject as? LocalFile)?.url.deletingLastPathComponent() == directory {
                return UITableViewDropProposal(operation: .forbidden)
            } else if session.items.first?.localObject == nil || (session.items.first?.localObject as? LocalFile)?.directory != directory {
                return UITableViewDropProposal(operation: .copy, intent: .insertAtDestinationIndexPath)
            } else {
                return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
            }
        } else if destinationIndexPath != nil && files.indices.contains(destinationIndexPath!.row) && FileManager.default.fileExists(atPath: files[destinationIndexPath!.row].path, isDirectory: &isDir) && isDir.boolValue && (session.items.first?.localObject as? URL)?.deletingLastPathComponent() == files[destinationIndexPath!.row] {
            return UITableViewDropProposal(operation: .forbidden)
        } else if destinationIndexPath == nil && (session.items.first?.localObject as? LocalFile)?.url.deletingLastPathComponent() == directory {
            return UITableViewDropProposal(operation: .forbidden)
        } else if session.items.first?.localObject == nil {
            return UITableViewDropProposal(operation: .copy, intent: .insertIntoDestinationIndexPath)
        } else {
            return UITableViewDropProposal(operation: .move, intent: .insertIntoDestinationIndexPath)
        }
    }
        
    // MARK: - Document picker view controller delegate
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        
        func move(at index: Int) {
            do {
                try FileManager.default.moveItem(at: urls[index], to: directory.appendingPathComponent(urls[index].lastPathComponent))
                
                if urls.indices.contains(index+1) {
                    move(at: index+1)
                } else {
                    tableView.reloadData()
                }
                
            } catch {
                let alert = UIAlertController(title: "Error importing file", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                    if urls.indices.contains(index+1) {
                        move(at: index+1)
                    } else {
                        self.tableView.reloadData()
                    }
                }))
                present(alert, animated: true, completion: nil)
            }
        }
        
        move(at: 0)
    }
    
    // MARK: - Context menu interaction delegate
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        
        guard let cell = interaction.view as? UITableViewCell else {
            return nil
        }
        
        let share = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { action in
            
            guard let index = self.tableView.indexPath(for: cell), self.files.indices.contains(index.row) else {
                return
            }
            
            let activityVC = UIActivityViewController(activityItems: [self.files[index.row]], applicationActivities: nil)
            activityVC.popoverPresentationController?.sourceView = cell
            activityVC.popoverPresentationController?.sourceRect = cell.bounds
            self.present(activityVC, animated: true, completion: nil)
        }
        
        let saveTo = UIAction(title: "Save to Files", image: UIImage(systemName: "folder")) { action in
            
            guard let index = self.tableView.indexPath(for: cell), self.files.indices.contains(index.row) else {
                return
            }
            
            self.present(UIDocumentPickerViewController(url: self.files[index.row], in: .exportToService), animated: true, completion: nil)
        }
        
        let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.libterm")
        let useInLibTerm = UIAction(title: "Use in LibTerm", image: UIImage(named: "LibTerm")) { action in
            
            guard let index = self.tableView.indexPath(for: cell), self.files.indices.contains(index.row) else {
                return
            }
            
            guard let url = groupURL else {
                return
            }
            
            if UIApplication.shared.canOpenURL(URL(string: "libterm://")!) {
                let progName = self.files[index.row].lastPathComponent.replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\"", with: "").lowercased()
                
                if (progName as NSString).deletingPathExtension.isEmpty {
                    let alert = UIAlertController(title: "Invalid name", message: "The file has an invalid name to be used as a program.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                } else {
                    do {
                        if !FileManager.default.fileExists(atPath: url.path) {
                            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [:])
                        }
                        
                        if FileManager.default.fileExists(atPath: url.appendingPathComponent(progName).path) {
                            try FileManager.default.removeItem(at: url.appendingPathComponent(progName))
                        }
                        try FileManager.default.copyItem(at: self.files[index.row], to: url.appendingPathComponent(progName))
                        
                        let alert = UIAlertController(title: "\((progName as NSString).deletingPathExtension) installed!", message: "You can now use '\((progName as NSString).deletingPathExtension)' command as any other command in LibTerm.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: nil))
                        alert.addAction(UIAlertAction(title: "Open LibTerm", style: .default, handler: { _ in
                            UIApplication.shared.open(URL(string: "libterm://")!, options: [:], completionHandler: nil)
                        }))
                        self.present(alert, animated: true, completion: nil)
                    } catch {
                        let alert = UIAlertController(title: "Couldn't install command", message: error.localizedDescription, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            } else {
                class StoreDelegate: NSObject, SKStoreProductViewControllerDelegate {
                    func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
                        viewController.dismiss(animated: true, completion: nil)
                    }
                    static let shared = StoreDelegate()
                }
                let store = SKStoreProductViewController()
                store.delegate = StoreDelegate.shared
                store.loadProduct(withParameters: [SKStoreProductParameterITunesItemIdentifier: "1380911705"], completionBlock: nil)
                self.present(store, animated: true, completion: nil)
            }
        }
        
        let rename = UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { action in
            
            guard let index = self.tableView.indexPath(for: cell), self.files.indices.contains(index.row) else {
                return
            }
            
            let file = self.files[index.row]
            
            var textField: UITextField!
            let alert = UIAlertController(title: "Rename '\(file.lastPathComponent)'", message: "Type the new name", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Rename", style: .default, handler: { (_) in
                do {
                    
                    let name = textField.text ?? ""
                    
                    if !name.isEmpty {
                        try FileManager.default.moveItem(at: file, to: file.deletingLastPathComponent().appendingPathComponent(name))
                    }
                } catch {
                    let alert = UIAlertController(title: "Error renaming file", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            alert.addTextField { (_textField) in
                textField = _textField
                textField.placeholder = "Untitled"
                textField.text = file.lastPathComponent
            }
            
            self.present(alert, animated: true, completion: nil)
        }
        
        let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash.fill"), attributes: .destructive) { action in
            
            guard let index = self.tableView.indexPath(for: cell), self.files.indices.contains(index.row) else {
                return
            }
            
            self.tableView(self.tableView, commit: .delete, forRowAt: index)
        }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { (_) -> UIMenu? in
            
            guard let index = self.tableView.indexPath(for: cell), self.files.indices.contains(index.row) else {
                return nil
            }
            
            var isDir: ObjCBool = false
            if (self.files[index.row].pathExtension == "ll" || self.files[index.row].pathExtension == "bc") && FileManager.default.fileExists(atPath: self.files[index.row].path, isDirectory: &isDir) && !isDir.boolValue && groupURL != nil {
                return UIMenu(title: cell.textLabel?.text ?? "", children: [share, saveTo, useInLibTerm, rename, delete])
            } else {
                return UIMenu(title: cell.textLabel?.text ?? "", children: [share, saveTo, rename, delete])
            }
        }
    }
}
