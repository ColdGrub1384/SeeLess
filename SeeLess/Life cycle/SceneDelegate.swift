//
//  SceneDelegate.swift
//  SeeLess
//
//  Created by Adrian Labbé on 19-09-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import UIKit

/// Scenes delegate.
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    /// Opens a file in the window corresponding to the delegate.
    ///
    /// - Parameters:
    ///     - fileURL: The URL of the file to open.
    func open(fileURL: URL) {
        guard fileURL.isFileURL else { return }
                
        // Reveal / import the document at the URL
        guard let documentBrowserViewController = window?.rootViewController as? DocumentBrowserViewController else { return }

        documentBrowserViewController.revealDocument(at: fileURL, importIfNeeded: true) { (revealedDocumentURL, error) in
            if let error = error {
                // Handle the error appropriately
                print("Failed to reveal the document at URL \(fileURL) with error: '\(error)'")
                return
            }
            
            // Present the Document View Controller for the revealed URL
            documentBrowserViewController.presentDocument(at: revealedDocumentURL!)
        }
    }
    
    // MARK: - Window scene delegate
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        if connectionOptions.urlContexts.count > 0 {
            self.scene(scene, openURLContexts: connectionOptions.urlContexts)
        }
        
        if let userActivity = session.stateRestorationActivity, let bookmarkData = userActivity.userInfo?["bookmarkData"] as? Data {
            do {
                var isStale = false
                open(fileURL: try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale))
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        
        guard let url = URLContexts.first?.url else { return }
        
        open(fileURL: url)
    }
    
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        guard let doc = (window?.rootViewController?.presentedViewController as? SplitViewController)?.document?.fileURL else {
            return nil
        }
        
        do {
            let userActivity = NSUserActivity(activityType: "document")
            userActivity.addUserInfoEntries(from: ["bookmarkData":try doc.bookmarkData()])
            return userActivity
        } catch {
            return nil
        }
    }
}
