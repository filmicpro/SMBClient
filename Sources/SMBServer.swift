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
