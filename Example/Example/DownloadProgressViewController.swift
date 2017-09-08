//
//  DownloadProgressViewController.swift
//  Example
//
//  Created by Seth Faxon on 9/7/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import UIKit
import SMBClient

class DownloadProgressViewController: UIViewController {
    
    var session: SMBSession?
    var filePath: String?
    
    private var task: SessionDownloadTask?
    
    @IBOutlet weak var fileLabel: UILabel!
    @IBOutlet weak var downloadProgressView: UIProgressView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.downloadProgressView.progress = 0
        
        guard let destFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last else { return }
        guard let filePath = self.filePath else { return }
        let fileURL = URL(fileURLWithPath: filePath)
        let fileName = fileURL.lastPathComponent
        
        self.fileLabel.text = fileName
        
        self.task = self.session?.downloadTaskForFile(atPath: filePath, destinationPath: destFolder.absoluteString + fileName, delegate: self)
        if let t = self.task {
            t.resume()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func cancelButtonTapped(_ sender: UIBarButtonItem) {
        guard let t = self.task else { return }
        t.cancel()
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

extension DownloadProgressViewController: SessionDownloadTaskDelegate {
    func downloadTask(didFinishDownloadingToPath: String) {
        print("finished downloading to: \(didFinishDownloadingToPath)")
    }
    func downloadTask(totalBytesReceived: UInt64, totalBytesExpected: UInt64) {
        self.downloadProgressView.progress = Float(totalBytesReceived) / Float(totalBytesExpected)
    }
    func downloadTask(didCompleteWithError: SessionDownloadError) {
        print("error: \(didCompleteWithError)")
    }
}
