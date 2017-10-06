//
//  SMBPath.swift
//  SMBClient
//
//  Created by Seth Faxon on 9/27/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import Foundation

public struct SMBPath {
    public let volume: SMBVolume
    public private(set) var directories: [SMBDirectory]

    public init(volume: SMBVolume) {
        self.volume = volume
        self.directories = []
    }

    public var routablePath: String {
        let slash = "\\"
        if self.directories.count == 0 {
            return slash + volume.name
        }
        let dirs: [String] = self.directories.flatMap { $0.name }
        return slash + volume.name + slash + dirs.joined(separator: slash)
    }

    internal var searchPath: String {
        let slash = "\\"
        if self.directories.count == 0 {
            return "*"
        }
        let dirs: [String] = self.directories.flatMap { $0.name }
        return slash + dirs.joined(separator: slash) + slash + "*"
    }

    public mutating func append(directory: SMBDirectory) {
        switch directory.name {
        case "..":
            _ = self.directories.popLast()
        case ".":
            break
        default:
            self.directories.append(directory)
        }
    }

}
