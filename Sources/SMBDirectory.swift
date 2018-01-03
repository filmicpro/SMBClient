//
//  SMBDirectory.swift
//  SMBClient
//
//  Created by Seth Faxon on 9/25/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import libdsm

public struct SMBDirectory {
    public var name: String

    public var createdAt: Date?
    public var accessedAt: Date?
    public var writeAt: Date?
    public var modifiedAt: Date?

    init?(stat: OpaquePointer, parentPath: SMBPath) {
        guard let cName = smb_stat_name(stat) else { return nil }
        self.name = String(cString: cName)
    }

    internal init(name: String) {
        self.name = name
    }

    public var isHidden: Bool {
        return self.name.last == "$" || self.name.first == "."
    }
}
