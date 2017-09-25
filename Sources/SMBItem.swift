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

    init?(stat: OpaquePointer, session: SMBSession, parentDirectoryFilePath path: String) {
        if smb_stat_get(stat, SMB_STAT_ISDIR) != 0 {
//            guard let cName = smb_stat_name(stat) else { return nil }
//            let name = String(cString: cName)

            guard let directory = SMBDirectory(stat: stat, session: session, parentDirectoryFilePath: path) else { return nil}
//            guard let directory = SMBDirectory(name: name, session: session) else { return nil }
            self = .directory(directory)
        } else {
            guard let file = SMBFile(stat: stat, session: session, parentDirectoryFilePath: path) else {
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
}
