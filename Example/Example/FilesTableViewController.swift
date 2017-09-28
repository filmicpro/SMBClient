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
    var path: SMBPath?
//    var volume: SMBVolume?
//    var path: String?
    var items: [SMBItem]? {
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
//        guard let volume = self.volume else { return }

        self.title = "Loading..."

        session.requestItems(atPath: path) { (result) in
            self.title = path.routablePath
            switch result {
            case .success(let items):
                self.items = items
            case .failure(let error):
                self.items = []
                print("FilesTableViewController failed to request files: \(error)")
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func addButtonTapped(_ sender: UIBarButtonItem) {
        guard let session = self.session else { return }
        guard let path = self.path else { return }

        let fileName = "\(UUID().uuidString).txt"

        let uploadPath = "\(path)/\(UUID().uuidString).txt"
        guard let data = uploadPath.data(using: .utf8) else { return }

        let uploadTask = session.uploadTaskForFile(toPath: path, withName: fileName, data: data, delegate: self)
        uploadTask.resume()
    }

}

extension FilesTableViewController: SessionUploadTaskDelegate {
    func uploadTask(didFinishUploading: SessionUploadTask) {
        //
        print("did finish uploading")
    }

    func uploadTask(didCompleteWithError: SessionUploadTask.SessionUploadError) {
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
        if let items = self.items {
            return items.count
        }
        return 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        guard let items = self.items else { return cell }
        let item = items[indexPath.row]
        switch  item {
        case .directory(let d):
            cell.textLabel?.text = d.name
            cell.detailTextLabel?.text = "directory"
        case .file(let file):
            cell.textLabel?.text = file.name
            cell.detailTextLabel?.text = "filesize: \(file.fileSize)"
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = self.items?[indexPath.row] else { return }
        guard let currentPath = self.path else { return }

        self.tableView.deselectRow(at: indexPath, animated: true)

        switch item {
        case .file(let file):
            let vc = UIStoryboard.downloadProgressViewController(session: self.session!, file: file)
            self.navigationController?.pushViewController(vc, animated: true)
            return
        case .directory(let directory):
//            let newPath: String
//            if currentPath != "/" {
//                newPath = "\(currentPath)/\(directory.name)"
//            } else {
//                if currentPath == "/" {
//                    newPath = "/\(directory.name)"
//                } else {
//                    newPath = "\(currentPath)/\(directory.name)"
//                }
//            }

            var newPath = self.path!
            newPath.append(directory: directory)

//            let vc = UIStoryboard.fileTableViewController(session: self.session!, volume: self.volume!, title: directory.name, path: newPath)
            let vc = UIStoryboard.fileTableViewController(session: self.session!, path: newPath, title: newPath.routablePath)
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}
