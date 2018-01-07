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

    /// expects a URL like: smb://host/volume/somePath
    /// this will fail to init if the server is not currently available
    public init?(fromURL url: URL) {
        guard let host = url.host else {
            return nil
        }
        guard let server = SMBServer(hostname: host) else {
            return nil
        }
        // url.pathComponents gives us a leading slash,
        // from above example this is:
        // ["/", "volume", "somePath"]
        var pathComponents = url.pathComponents
        // can't have a valid connection without a host and a volume
        guard pathComponents.count >= 2 else {
            return nil
        }

        // pop off the leading '/' that pathComponents gives us
        var popedComponent = "/"
        while popedComponent == "/" && pathComponents.count > 0 {
            popedComponent = pathComponents.removeFirst()
        }
        let volumeName = popedComponent
        self.volume = SMBVolume(server: server, name: volumeName)

        // build directories from whatever is left
        var pathDirectories = [SMBDirectory]()
        while pathComponents.count > 0 {
            var pathName = pathComponents.removeFirst()
            if let p = pathName.removingPercentEncoding {
                pathName = p
            }
            let dir = SMBDirectory(name: pathName)
            pathDirectories.append(dir)
        }
        self.directories = pathDirectories
    }

    public var asURL: URL {
        var pathString = "/\(self.volume.name)/"
        pathString += self.directories.map { $0.name }.joined(separator: "/")
        var components = URLComponents(string: "")!
        components.scheme = "smb"
        components.host = self.volume.server.hostname
        components.path = pathString // does URL percent encoding

        return components.url!
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

extension SMBPath: Equatable {}

public func == (lhs: SMBPath, rhs: SMBPath) -> Bool {
    return lhs.volume == rhs.volume && lhs.routablePath == rhs.routablePath
}
