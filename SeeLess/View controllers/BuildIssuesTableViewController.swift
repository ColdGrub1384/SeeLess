//
//  BuildIssuesTableViewController.swift
//  SeeLess
//
//  Created by Adrian Labbé on 17-09-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import UIKit

/// A Table view controller showing warnings and errors for each file.
class BuildIssuesTableViewController: UITableViewController {
    
    /// Files that emited warnings or errros.
    var files = [URL]()
    
    /// A list of clang output corresponding to `files` array.
    var issues = [String]()
    
    /// Initializes the Table view controller.
    ///
    /// - Parameters:
    ///     - file: Files that emited warnings or errros.
    ///     - issues: A list of clang output corresponding to `files` array.
    init(files: [URL], issues: [String]) {
        super.init(style: .plain)
        
        self.files = files
        self.issues = issues
        title = "Errors & Warnings"
    }
    
    /// Closes this View controller.
    @objc func close() {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Table view controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        clearsSelectionOnViewWillAppear = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return files.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = files[indexPath.row].lastPathComponent
        cell.detailTextLabel?.text = String(issues[indexPath.row].dropLast(1)).components(separatedBy: "\n").last?.components(separatedBy: "[0m").last
        
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: files[indexPath.row].path, isDirectory: &isDir) && isDir.boolValue {
            cell.imageView?.image = UIImage(systemName: "folder.fill")
        } else {
            cell.imageView?.image = UIImage(systemName: "doc.fill")
        }
        
        cell.accessoryType = .disclosureIndicator
        
        cell.contentView.alpha = files[indexPath.row].lastPathComponent.hasPrefix(".") ? 0.5 : 1
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        guard let issue = issues[indexPath.row].data(using: .utf8) else {
            return
        }
        
        class ViewController: UIViewController, ParserDelegate {
            
            let textView = UITextView()
            
            override func viewWillAppear(_ animated: Bool) {
                super.viewWillAppear(animated)
                
                if textView.superview == nil {
                    textView.isEditable = false
                    textView.backgroundColor = .clear
                    textView.textColor = .label
                    
                    view.addSubview(textView)
                    textView.frame = view.safeAreaLayoutGuide.layoutFrame
                }
            }
            
            override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
                super.viewWillTransition(to: size, with: coordinator)
                
                coordinator.animate(alongsideTransition: nil) { (_) in
                    self.textView.frame = self.view.safeAreaLayoutGuide.layoutFrame
                }
            }
            
            func parser(_ parser: Parser, didReceiveString string: NSAttributedString) {
                DispatchQueue.main.async {
                    
                    let attributedString = NSMutableAttributedString(attributedString: self.textView.attributedText ?? NSAttributedString())
                    attributedString.append(string)
                    
                    self.textView.attributedText = attributedString
                }
            }
            
            func parserDidEndTransmission(_ parser: Parser) {
            }
        }
        
        let vc = ViewController()
        vc.title = files[indexPath.row].lastPathComponent
        vc.view.backgroundColor = .systemBackground
        
        DispatchQueue.global().async {
            let parser = Parser()
            parser.delegate = vc
            parser.parse(issue)
        }
        
        navigationController?.pushViewController(vc, animated: true)
    }
}
