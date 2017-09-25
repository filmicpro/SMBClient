//
//  SMBVolume.swift
//  SMBClient
//
//  Created by Seth Faxon on 9/25/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import Foundation

public struct SMBVolume {
    var session: SMBSession

    public var name: String

    init(name: String, session: SMBSession) {
        self.name = name
        self.session = session
    }
}
