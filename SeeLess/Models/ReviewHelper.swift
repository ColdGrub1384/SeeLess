//
//  ReviewHelper.swift
//  SeeLess
//
//  Created by Adrian Labbé on 01-11-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import Foundation
import StoreKit

/// Helper used to request app review based on app launches.
class ReviewHelper: NSObject, SKStoreProductViewControllerDelegate {
    
    /// Request review and reset points.
    func requestReview() {
        if launches >= minLaunches {
            launches = 0
            SKStoreReviewController.requestReview()
        } else if launches >= minLaunches/2 && !UserDefaults.standard.bool(forKey: "pyto") {
            
            var keyWindow: UIWindow? {
                return UIApplication.shared.connectedScenes
                            .filter({$0.activationState == .foregroundActive})
                            .map({$0 as? UIWindowScene})
                            .compactMap({$0})
                            .first?.windows
                            .filter({$0.isKeyWindow}).first
            }
            
            UserDefaults.standard.set(true, forKey: "pyto")
            
            let alert = UIAlertController(title: "Pyto", message: "Pyto is a Python IDE with a lot of included libraries.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "View", style: .default, handler: { (_) in
                let vc = SKStoreProductViewController()
                vc.delegate = self
                vc.loadProduct(withParameters: [SKStoreProductParameterITunesItemIdentifier:1436650069], completionBlock: nil)
                (keyWindow?.rootViewController ?? keyWindow?.rootViewController?.presentedViewController)?.present(vc, animated: true) { () -> Void in }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            DispatchQueue.main.asyncAfter(deadline: .now()+2) {
                (keyWindow?.rootViewController ?? keyWindow?.rootViewController?.presentedViewController)?.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - Singleton
    
    /// Shared and unique instance.
    static let shared = ReviewHelper()
    private override init() {}
    
    // MARK: - Launches tracking
    
    /// App launches incremented in `AppDelegate.application(_:, didFinishLaunchingWithOptions:)`.
    ///
    /// Launches are saved to `UserDefaults`.
    var launches: Int {
        
        get {
            return UserDefaults.standard.integer(forKey: "launches")
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: "launches")
            UserDefaults.standard.synchronize()
        }
    }
    
    /// Minimum launches for asking for review.
    var minLaunches = 10
    
    // MARK: - Store product view controller delegate
    
    func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        viewController.dismiss(animated: true, completion: nil)
    }
}
