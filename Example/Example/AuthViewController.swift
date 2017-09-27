//
//  AuthViewController.swift
//  Example
//
//  Created by Seth Faxon on 9/27/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import UIKit
import SMBClient

class AuthViewController: UIViewController {
    var server: SMBServer?

    @IBOutlet weak var userNameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var authenticateButton: UIButton!
    @IBOutlet weak var guestButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func authenticateButtonTapped(_ sender: UIButton) {
        guard let userName = self.userNameTextField.text else { return }
        guard let pass = self.passwordTextField.text else { return }

        let creds = SMBSession.Credentials.user(name: userName, password: pass)
        self.authenticate(credentials: creds)
    }

    @IBAction func guestButtonTapped(_ sender: UIButton) {
        self.authenticate(credentials: .guest)
    }

    private func disableButtons() {
        self.authenticateButton.isEnabled = false
        self.guestButton.isEnabled = false
    }

    private func enabelButtons() {
        self.authenticateButton.isEnabled = true
        self.guestButton.isEnabled = true
    }

    private func authenticate(credentials: SMBSession.Credentials) {
        guard let smbServer = self.server else { return }
        let sess = SMBSession(server: smbServer, credentials: credentials)

        let vc = UIStoryboard.volumeListViewController(session: sess)
        self.navigationController?.pushViewController(vc, animated: true)
    }

}
