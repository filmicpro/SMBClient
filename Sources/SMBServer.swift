//
//  SMBServer.swift
//  SMBClient
//
//  Created by Seth Faxon on 9/25/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import Foundation

public struct SMBServer {
    public let hostname: String
    public let ipAddress: UInt32

    public init(hostname: String, ipAddress: UInt32) {
        self.hostname = hostname
        self.ipAddress = ipAddress
    }

    // fails initiation if ipAddress lookup fails
    public init?(hostname: String) {
        self.hostname = hostname
        let ns = NetBIOSNameService()
        if let addr = ns.resolveIPAddress(forName: self.hostname, ofType: .fileServer) {
            self.ipAddress = addr
        } else {
            return nil
        }
    }

    public var ipAddressString: String {
        var bytes = [UInt32]()
        bytes.append((self.ipAddress >> 24) & 0xFF)
        bytes.append((self.ipAddress >> 16) & 0xFF)
        bytes.append((self.ipAddress >> 8) & 0xFF)
        bytes.append(self.ipAddress & 0xFF)

        return "\(bytes[0]).\(bytes[1]).\(bytes[2]).\(bytes[3])"
    }
}

extension SMBServer: CustomStringConvertible {
    public var description: String {
        return "\(hostname) - \(ipAddressString)"
    }
}

extension SMBServer: Equatable { }

public func == (lhs: SMBServer, rhs: SMBServer) -> Bool {
    return lhs.hostname == rhs.hostname && lhs.ipAddress == rhs.ipAddress
}
