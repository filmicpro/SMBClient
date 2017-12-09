//
//  SMBVolume.swift
//  SMBClient
//
//  Created by Seth Faxon on 9/25/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import Foundation

public struct SMBVolume {
    public var server: SMBServer
    public var name: String

    init(server: SMBServer, name: String) {
        self.server = server
        self.name = name
    }

    public var path: SMBPath {
        return SMBPath(volume: self)
    }

    // skip system shares suffixed by '$'
    public var isHidden: Bool {
        return self.name.last == "$"
    }
}

extension SMBVolume: Equatable { }

public func == (lhs: SMBVolume, rhs: SMBVolume) -> Bool {
    return lhs.server == rhs.server && lhs.name == rhs.name
}
