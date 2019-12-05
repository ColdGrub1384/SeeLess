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

/// The last login date.
var lastLogin: Date? {
    get {
        return UserDefaults.standard.object(forKey: "lastLogin") as? Date
    }
    
    set {
        UserDefaults.standard.set(newValue, forKey: "lastLogin")
        UserDefaults.standard.synchronize()
    }
}

/// The `help` command.
func helpMain(argc: Int, argv: [String], io: LTIO) -> Int32 {
    
    if argv.contains("--compiling") || argv.contains("compiling") {
        
        var range = NSRange(location: 0, length: 0)
        DispatchQueue.main.sync {
            range = io.terminal?.terminalTextView.selectedRange ?? range
        }
        
        let compiling = "To compile C code, use the 'clang' command. Code cannot be compiled as an executable binary but has to be compiled into LLVM Intermediate Representation (LLVM IR). Then, the LLVM IR code will be interpreted by the 'lli' command. To compile code:\n\n$ clang -S -emit-llvm <other options> <C file to compile>\n\nThis will generate a '.ll' file, which is in LLVM IR format. To run the code, use the 'lli' command.\n\n$ lli <file>.ll\n\nThat will run the 'main' function.\n\nA '.ll' file can be executed or multiple '.ll' files can be merged into one, so we can code a program with multiple sources. You can use the 'llvm-link' command to \"merge\" multiple files.\n\n$ clang -S -emit-llvm helper.c\n$ clang -S -emit-llvm main.c\n$ llvm-link -o program.bc *.ll\n$ lli 'program.bc'\n\n"
        
        guard let rowsStr = ProcessInfo.processInfo.environment["LINES"], var rows = Int(rowsStr) else {
            fputs(compiling, stdout)
            return 0
        }
        
        rows -= 6
        
        let lines = compiling.components(separatedBy: "\n")
        var currentLine = 0
        
        for i in 0...rows {
            if lines.indices.contains(i) {
                currentLine += 1
                fputs(lines[i]+"\n", io.stdout)
            } else {
                break
            }
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        
        DispatchQueue.main.asyncAfter(deadline: .now()+0.7) {
            
            if currentLine <= lines.count-1 {
                for i in currentLine...lines.count-1 {
                    if lines.indices.contains(i) {
                        currentLine += 1
                        fputs(lines[i]+"\n", io.stdout)
                    } else {
                        break
                    }
                }
            }
            
            semaphore.signal()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now()+1.4, execute: {
            io.terminal?.terminalTextView.scrollRangeToVisible(range)
        })
        
        semaphore.wait()
        
        return 0
    }
    
    if argv.contains("--restored") || argv.contains("-r") {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        fputs("\n\nRestored on \(formatter.string(from: Date()))\n\n", io.stdout)
        return 0
    }
    
    var helpText: String
    
    #if FRAMEWORK
    helpText = ""
    #else
    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, let build = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        helpText = "SeeLess version \(version) (\(build)), \(formatter.string(from: BuildDate))\n\n"
    } else {
        helpText = "Unknown version\n\n"
    }
    helpText += "Use the 'create' command to create a project and 'open' to open a project.\n\n"
    #endif
    
    if argv.contains("--version") {
        fputs(helpText, io.stdout)
        return 0
    }
    
    if argv.contains("--startup") || argv.contains("-s") {
        if let lastLogin = lastLogin {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            
            helpText += "\nLast login: \(formatter.string(from: lastLogin))\n"
        }
        fputs(helpText, io.stdout)
        return 0
    }
    
    for command in LTHelp {
        if command != LTHelp.last {
            helpText += "\(command.commandName), "
        } else {
            helpText += "\(command.commandName)\n"
        }
    }
    
    helpText += "\nUse the 'package' command to install third party commands.\n"
    helpText += "\n\nWith SeeLess, you can compile and run C code with the 'clang' and 'lli' commands. Type 'help compiling' for more information.\n"
    fputs(helpText, io.stdout)
        
    return 0
}

/// The `create` command.
func createMain(argc: Int, argv: [String], io: LTIO) -> Int32 {
    
    var args = argv
    args.removeFirst()
    
    if args.count == 0 {
        fputs("Usage:\n\n  \(argv[0]) PROJECT_NAME\n", io.stderr)
        return 1
    }
    
    var url = URL(fileURLWithPath: args.joined(separator: " "), relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
    if url.pathExtension.lowercased() != "cproj" {
        url = url.appendingPathExtension("cproj")
    }
    do {
        try FileManager.default.copyItem(at: Bundle.main.url(forResource: "Untitled", withExtension: "cproj")!, to: url)
    } catch {
        fputs("\(error.localizedDescription)\n", io.stderr)
        return 1
    }
    
    return 0
}

/// The `open` command.
func openProjectMain(argc: Int, argv: [String], io: LTIO) -> Int32 {
    
    var args = argv
    args.removeFirst()
    
    if args.count == 0 {
        fputs("Usage:\n\n  \(argv[0]) PROJECT_NAME\n", io.stderr)
        return 1
    }
    
    var url = URL(fileURLWithPath: args.joined(separator: " "), relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
    if url.pathExtension.lowercased() != "cproj" && !FileManager.default.fileExists(atPath: url.path) {
        url = url.appendingPathExtension("cproj")
    }
    
    DispatchQueue.main.async {
        (io.terminal?.parent as? DocumentBrowserViewController)?.presentDocument(at: url)
    }
    
    return 0
}

/// The document browser.
class DocumentBrowserViewController: UIViewController {
    
    /// A shell for managing projects.
    class Shell: LibShell {
        
        override var builtins: [String : LTCommand] {
            var builtins = super.builtins
            builtins["create"] = createMain
            builtins["open"] = openProjectMain
            return builtins
        }
        
        override func run(command: String, appendToHistory: Bool = true) -> Int32 {
            let result = super.run(command: command, appendToHistory: appendToHistory)
            DispatchQueue.main.asyncAfter(deadline: .now()+0.5) {
                self.io?.terminal?.parent?.navigationItem.title = self.io?.terminal?.title
            }
            return result
        }
    }
    
    /// Opens app's settings.
    @IBAction func openSettings(_ sender: Any) {
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
    
    /// The URL to open.
    var documentURL: URL?
    
    // MARK: - Document browser view controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let term = LTTerminalViewController.makeTerminal(preferences: LTTerminalViewController.Preferences(), shell: Shell())
        addChild(term)
        view.addSubview(term.view)
        term.view.frame = view.frame
        term.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        view.window?.windowScene?.title = ""
        
        if let docURL = documentURL {
            presentDocument(at: docURL)
            documentURL = nil
        }
        
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
}

