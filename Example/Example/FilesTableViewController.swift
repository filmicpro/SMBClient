//
//  FilesTableViewController.swift
//  Example
//
//  Created by Seth Faxon on 9/5/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import UIKit
import SMBClient

class FilesTableViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    
    var session: SMBSession?
    var path: String?
    var files: [SMBFile]? {
        didSet {
            self.tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.tableView.delegate = self
        self.tableView.dataSource = self
        
        guard let session = self.session else { return }
        guard let path = self.path else { return }
        
        self.title = "Loading..."
        
        session.requestContentsOfDirectory(atPath: path) { (result) in
            self.title = path
            switch result {
            case .success(let files):
                self.files = files
            case .failure(let error):
                self.files = []
                print("error requesting files: \(error)")
            }
        }
        
        // synchronous way to list files
//        switch session.requestContents(atFilePath: path) {
//        case .success(let files):
//            self.files = files
//        case .failure(let error):
//            self.files = []
//            print("error requesting files: \(error)")
//        }
//        self.files = session.requestContents(atFilePath: path)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func addButtonTapped(_ sender: UIBarButtonItem) {
        guard let session = self.session else { return }
        guard let path = self.path else { return }
        
        let uploadPath = "\(path)/\(UUID().uuidString).txt"
        guard let data = uploadPath.data(using: .utf8) else { return }
        
        let uploadTask = session.uploadTaskForFile(atPath: uploadPath, data: data, delegate: self)
        uploadTask.resume()
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

extension FilesTableViewController: SessionUploadTaskDelegate {
    func uploadTask(didFinishUploading: SessionUploadTask) {
        //
        print("did finish uploading")
    }
    
    func uploadTask(didCompleteWithError: SessionUploadError) {
        print("error uploading: \(didCompleteWithError)")
    }
    
    func uploadTask(_ task: SessionUploadTask, totalBytesSent: UInt64, totalBytesExpected: UInt64) {
        print("progress uploading!")
    }
}

extension FilesTableViewController: UITableViewDelegate {
    
}

extension FilesTableViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let files = self.files {
            return files.count
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        guard let files = self.files else { return cell }
        let file = files[indexPath.row]
        cell.textLabel?.text = file.name
        cell.detailTextLabel?.text = file.isDirectory ? "directory" : ""
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let file = self.files?[indexPath.row] else { return }
        guard let currentPath = self.path else { return }
        
        if !file.isDirectory {
            let vc = UIStoryboard.downloadProgressViewController(session: self.session!, filePath: "\(currentPath)/\(file.name)")
            self.navigationController?.pushViewController(vc, animated: true)
            return
        }
        
        
        let newPath: String
        if currentPath != "/" {
            newPath = "\(currentPath)/\(file.name)"
        } else {
            if currentPath == "/" {
                newPath = "/\(file.name)"
            } else {
                newPath = "\(currentPath)/\(file.name)"
            }
        }
        
        let vc = UIStoryboard.fileTableViewController(session: self.session!, title: file.name, path: newPath)
        self.navigationController?.pushViewController(vc, animated: true)
//        let svr = self.servers[indexPath.row]
//
//        let sess = SMBSession()
//        sess.hostName = svr.name
//        sess.ipAddress = svr.ipAddressString
//        //        let conn = sess.attemptConnection()
//        //        print("conn: \(conn)")
//
//        let paths = sess.requestContents(atFilePath: "/")
//        print(paths)
    }
}

