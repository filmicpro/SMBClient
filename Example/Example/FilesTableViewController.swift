//
//  FilesTableViewController.swift
//  Example
//
//  Created by Seth Faxon on 9/5/17.
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
}

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
        self.files = session.requestContents(atFilePath: path)
        
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
            let task = self.session?.downloadTaskForFile(atPath: "\(currentPath)/\(file.name)", destinationPath: nil, delegate: nil)
            if let t = task {
                t.resume()
            }
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
        
        let vc = UIStoryboard.fileTableViewController(session: self.session!, title: "depth", path: newPath)
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

