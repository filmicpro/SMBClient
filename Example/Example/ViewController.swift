
//
//  ViewController.swift
//  Example
//
//  Created by Seth Faxon on 8/31/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import UIKit
import SMBClient

class ViewController: UIViewController {
    
    let s = NetBIOSNameService()
    
    @IBOutlet weak var tableView: UITableView!
    
    var servers: [NetBIOSNameServiceEntry] = [] {
        didSet {
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        
        s.delegate = self
        s.startDiscovery(withTimeout: 3000)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let dest = segue.destination as? FilesTableViewController {
            dest.session = sender as? SMBSession
            dest.path = "/"
            
        }
    }

}

extension ViewController: NetBIOSNameServiceDelegate {
    func added(entry: NetBIOSNameServiceEntry) {
        print(entry)
        self.servers.append(entry)
    }
    func removed(entry: NetBIOSNameServiceEntry) {
        print("removed - \(entry)")
        self.servers = self.servers.filter { $0 != entry }
    }
}


extension ViewController: UITableViewDelegate {
    
}

extension ViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.servers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let server = self.servers[indexPath.row]
        cell.textLabel?.text = server.name
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let svr = self.servers[indexPath.row]
        
        let sess = SMBSession()
        sess.hostName = svr.name
        sess.ipAddress = svr.ipAddressString
//        let conn = sess.attemptConnection()
//        print("conn: \(conn)")
        
//        let paths = sess.requestContents(atFilePath: "/")
//        print(paths)
        
        let vc = UIStoryboard.fileTableViewController(session: sess, title: "Shares")
        self.navigationController?.pushViewController(vc, animated: true)
        
        // self.performSegue(withIdentifier: "showFiles", sender: sess)
    }
}
