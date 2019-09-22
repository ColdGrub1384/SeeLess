//
//  FileManager.swift
//  SeeLess
//
//  Created by Adrian Labbé on 17-09-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import Foundation

extension FileManager {
    
    /// Taken from https://stackoverflow.com/a/40866080/7515957
    func listFiles(path: String) -> [URL] {
        let baseurl: URL = URL(fileURLWithPath: path)
        var urls = [URL]()
        enumerator(atPath: path)?.forEach({ (e) in
            guard let s = e as? String else { return }
            let relativeURL = URL(fileURLWithPath: s, relativeTo: baseurl)
            let url = relativeURL.absoluteURL
            urls.append(url)
        })
        return urls
    }
}
