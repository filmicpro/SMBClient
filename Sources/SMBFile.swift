//
//  SMBFile.swift
//  SMBClient
//
//  Created by Seth Faxon on 9/1/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import libdsm

// shareRoot, directory, file are different things
public struct SMBFile {
    var session: SMBSession
//    var filePath: String
    public var isShareRoot: Bool
    public var isDirectory: Bool
    public var name: String

    public var fileSize: UInt64
    public var allocationSize: UInt64

    public var createdAt: Date?
    public var accessedAt: Date?
    public var writeAt: Date?
    public var modifiedAt: Date?

    init?(stat: OpaquePointer, session: SMBSession, parentDirectoryFilePath path: String) {
        guard let cName = smb_stat_name(stat) else { return nil }
        self.name = String(cString: cName)

        self.session = session
        self.fileSize = smb_stat_get(stat, SMB_STAT_SIZE)
        self.allocationSize = smb_stat_get(stat, SMB_STAT_ALLOC_SIZE)
        self.isDirectory = smb_stat_get(stat, SMB_STAT_ISDIR) != 0
        self.isShareRoot = false
    }

    init?(name: String, session: SMBSession) {
        self.name = name
        self.session = session
        self.fileSize = 0
        self.allocationSize = 0
        self.isDirectory = true
        self.isShareRoot = true
    }
}
