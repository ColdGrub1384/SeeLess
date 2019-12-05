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
                
        guard let documentBrowserViewController = (window?.rootViewController as? UINavigationController)?.visibleViewController as? DocumentBrowserViewController else { return }

        documentBrowserViewController.presentDocument(at: fileURL)
    }
    
    // MARK: - Window scene delegate
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        if connectionOptions.urlContexts.count > 0 {
            self.scene(scene, openURLContexts: connectionOptions.urlContexts)
        }
        
        if let userActivity = session.stateRestorationActivity ?? connectionOptions.userActivities.first, let bookmarkData = userActivity.userInfo?["bookmarkData"] as? Data {
            do {
                var isStale = false
                ((window?.rootViewController as? UINavigationController)?.viewControllers.first as? DocumentBrowserViewController)?.documentURL = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        
        guard let url = URLContexts.first?.url else { return }
        
        if window?.rootViewController?.presentedViewController != nil {
            window?.rootViewController?.dismiss(animated: true, completion: {
                self.open(fileURL: url)
            })
        } else {
            open(fileURL: url)
        }
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
    
    @available(iOS 13.0, *)
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        
        let root = window?.rootViewController
        
        func runProgram() {
            if let data = userActivity.userInfo?["bookmarkData"] as? Data {
                do {
                    var isStale = false
                    let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
                    
                    _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { (timer) in
                        if let doc = self.window?.rootViewController as? DocumentBrowserViewController {
                            doc.presentDocument(at: url, arguments: userActivity.userInfo?["arguments"] as? String)
                            timer.invalidate()
                        }
                    })
                } catch {
                    let alert = UIAlertController(title: "Error reading file!", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                    root?.present(alert, animated: true, completion: nil)
                }
            }
        }
        
        if root?.presentedViewController != nil {
            root?.dismiss(animated: true, completion: {
                runProgram()
            })
        } else {
            runProgram()
        }
    }
}
