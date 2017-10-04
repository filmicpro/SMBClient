//
//  VolumeListViewController.swift
//  Example
//
//  Created by Seth Faxon on 9/25/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import UIKit
import SMBClient

class VolumeListViewController: UIViewController {

    var session: SMBSession?
    var volumes: [SMBVolume] = [] {
        didSet {
            self.tableView.reloadData()
        }
    }

    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.tableView.delegate = self
        self.tableView.dataSource = self

        self.title = "Loading..."

        if let session = self.session {
            self.title = session.server.hostname
            session.requestVolumes(completion: { (result) in
                switch result {
                case .success(let volumes):
                    self.volumes = volumes
                case .failure(let error):
                    let alert = UIAlertController(title: "error", message: error.description, preferredStyle: .alert)
                    let ok = UIAlertAction(title: "OK", style: .default, handler: { (_) in
                        self.navigationController?.popViewController(animated: true)
                    })
                    alert.addAction(ok)
                    self.present(alert, animated: true, completion: nil)
                }
            })
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

extension VolumeListViewController: UITableViewDataSource {

}

extension VolumeListViewController: UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return volumes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let volume = volumes[indexPath.row]
        cell.textLabel?.text = volume.name
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)

        let volume = self.volumes[indexPath.row]

        let vc = UIStoryboard.fileTableViewController(session: self.session!, path: volume.path, title: volume.name)
        self.navigationController?.pushViewController(vc, animated: true)
    }
}
