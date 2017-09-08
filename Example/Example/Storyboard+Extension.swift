//
//  Storyboard+Extension.swift
//  Example
//
//  Created by Seth Faxon on 9/7/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import UIKit
import SMBClient

extension UIStoryboard {
    class func mainStoryboard() -> UIStoryboard {
        return UIStoryboard(name: "Main", bundle: Bundle.main)
    }
    
    class func fileTableViewController(session: SMBSession, title: String, path: String = "/") -> FilesTableViewController {
        let vc = mainStoryboard().instantiateViewController(withIdentifier: "FilesTableViewController") as! FilesTableViewController
        vc.session = session
        vc.path = path
        vc.title = title
        return vc
    }
    
    class func downloadProgressViewController(session: SMBSession, filePath: String) -> DownloadProgressViewController {
        let vc = mainStoryboard().instantiateViewController(withIdentifier: "DownloadProgressViewController") as! DownloadProgressViewController
        vc.session = session
        vc.filePath = filePath
        return vc
    }
}

