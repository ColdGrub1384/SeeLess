//
//  ThumbnailProvider.swift
//  Thumbnail
//
//  Created by Adrian Labbé on 19-09-19.
//  Copyright © 2019 Adrian Labbé. All rights reserved.
//

import UIKit
import QuickLookThumbnailing

class ThumbnailProvider: QLThumbnailProvider {
    
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        
        handler(QLThumbnailReply(imageFileURL: Bundle.main.url(forResource: "fileThumbnail", withExtension: "png")!), nil)
    }
}
