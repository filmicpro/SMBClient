//
//  SMBItem.swift
//  SMBClient
//
//  Created by Seth Faxon on 9/25/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import libdsm

public enum SMBItem {
    case file(SMBFile)
    case directory(SMBDirectory)

    init?(stat: OpaquePointer, session: SMBSession, parentPath: SMBPath) {
        if smb_stat_get(stat, SMB_STAT_ISDIR) != 0 {
            guard let directory = SMBDirectory(stat: stat, parentPath: parentPath) else { return nil}
            self = .directory(directory)
        } else {
            guard let file = SMBFile(stat: stat, parentPath: parentPath) else {
                return nil
            }
            self = .file(file)
        }
    }

    var name: String {
        switch self {
        case .directory(let d):
            return d.name
        case .file(let f):
            return f.name
        }
    }

    var isHidden: Bool {
        switch self {
        case .directory(let d):
            return d.isHidden
        case .file(let f):
            return f.isHidden
        }
    }
}
