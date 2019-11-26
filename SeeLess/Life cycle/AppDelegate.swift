//
//  AppDelegate.swift
//  SeeLess
//
//  Created by Adrian Labbé on 15-09-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import UIKit
import ios_system
import SSZipArchive

/// The app's delegate.
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    /// Unimplemented on SeeLess.
    func movePrograms() {
        
    }
    
    // MARK: - Application delegate
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") {
            if !FileManager.default.fileExists(atPath: iCloudURL.path) {
                try? FileManager.default.createDirectory(at: iCloudURL, withIntermediateDirectories: true, attributes: nil)
            }
        }
        
        // clang
        
        let usrURL = FileManager.default.urls(for: .libraryDirectory, in: .allDomainsMask)[0].appendingPathComponent("usr")
        
        if FileManager.default.fileExists(atPath: usrURL.path) {
            try? FileManager.default.removeItem(at: usrURL)
        }
        
        if let zipPath =  Bundle.main.path(forResource: "usr", ofType: "zip") {
            DispatchQueue.global().async {
                Document.isCompiling = true
                SSZipArchive.unzipFile(atPath: zipPath, toDestination: usrURL.deletingLastPathComponent().path, progressHandler: nil) { (_, success, error) in
                    
                    Document.isCompiling = false
                    
                    if let error = error {
                        print(error.localizedDescription)
                    }
                    
                    /*if success {
                        putenv("C_INCLUDE_PATH=\(usrURL.appendingPathComponent("lib/clang/7.0.0/include").path):\(usrURL.appendingPathComponent("include").path)".cValue)
                        putenv("OBJC_INCLUDE_PATH=\(usrURL.appendingPathComponent("lib/clang/7.0.0/include")):\(usrURL.appendingPathComponent("include"))".cValue)
                        putenv("CPLUS_INCLUDE_PATH=\(usrURL.appendingPathComponent("include/c++/v1").path):\(usrURL.appendingPathComponent("lib/clang/7.0.0/include")):\(usrURL.appendingPathComponent("include").path)".cValue)
                        putenv("OBJCPLUS_INCLUDE_PATH=\(usrURL.appendingPathComponent("include/c++/v1")):\(usrURL.appendingPathComponent("lib/clang/7.0.0/include")):\(usrURL.appendingPathComponent("include"))".cValue)
                    }*/
                }
            }
        }
        
        DispatchQueue.global().async {
            print(ios_system("clang"))
        }
        
        // ios_system
        
        // cacert.pem
        let cacertNewURL = FileManager.default.urls(for: .documentDirectory, in: .allDomainsMask)[0].appendingPathComponent("cacert.pem")
        if let cacertURL = Bundle.main.url(forResource: "cacert", withExtension: "pem"), !FileManager.default.fileExists(atPath: cacertNewURL.path) {
            try? FileManager.default.copyItem(at: cacertURL, to: cacertNewURL)
        }
        
        initializeEnvironment()
        replaceCommand("id", "id_main", true)
        sideLoading = true
        
        if SettingsTableViewController.fontSize.integerValue == 0 {
            SettingsTableViewController.fontSize.integerValue = 14
        }
        
        ReviewHelper.shared.launches += 1
        
        return true
    }
}

