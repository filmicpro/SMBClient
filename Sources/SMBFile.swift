//
//  SMBFile.swift
//  SMBClient
//
//  Created by Seth Faxon on 9/1/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import libdsm

public struct SMBFile {
    public private(set) var path: SMBPath

    var session: SMBSession
    public var name: String

    public var fileSize: UInt64
    public var allocationSize: UInt64

    public var createdAt: Date?
    public var accessedAt: Date?
    public var writeAt: Date?
    public var modifiedAt: Date?

    init?(stat: OpaquePointer, session: SMBSession, parentPath: SMBPath) {
        self.path = parentPath
        guard let cName = smb_stat_name(stat) else { return nil }
        let pathAndFile = String(cString: cName).split(separator: "\\")
        guard let n = pathAndFile.last else { return nil }
        self.name = n.decomposedStringWithCanonicalMapping

        self.session = session
        self.fileSize = smb_stat_get(stat, SMB_STAT_SIZE)
        self.allocationSize = smb_stat_get(stat, SMB_STAT_ALLOC_SIZE)
    }

    init?(path: SMBPath, name: String, session: SMBSession) {
        self.path = path
        self.name = name
        self.session = session
        self.fileSize = 0
        self.allocationSize = 0
    }

    public var isHidden: Bool {
        return self.name.first == "."
    }

    internal var uploadPath: String {
        let slash = "\\"
        let dirs: [String] = self.path.directories.map { $0.name }
        let result = slash + dirs.joined(separator: slash) + slash + self.name
        return result
    }

    internal var downloadPath: String {
        let slash = "\\"
        return slash + self.uploadPath
    }
}
