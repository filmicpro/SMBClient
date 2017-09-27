//
//  NetBIOSNameServiceEntry.swift
//  SMBClient
//
//  Created by Seth Faxon on 8/31/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import libdsm

public enum NetBIOSNameServiceType: Int8 {
    case workstation
    case messenger
    case fileServer
    case domainMaster

    init?(fromNetBIOSNSEntryType: Int8) {
        switch Int32(fromNetBIOSNSEntryType) {
        case NETBIOS_WORKSTATION:
            self = .workstation
        case NETBIOS_MESSENGER:
            self = .messenger
        case NETBIOS_FILESERVER:
            self = .fileServer
        case NETBIOS_DOMAINMASTER:
            self = .domainMaster
        default:
            return nil
        }
    }

    internal var typeValue: Int8 {
        switch self {
        case .workstation:
            return Int8(NETBIOS_WORKSTATION)
        case .messenger:
            return Int8(NETBIOS_MESSENGER)
        case .fileServer:
            return Int8(NETBIOS_FILESERVER)
        case .domainMaster:
            return Int8(NETBIOS_DOMAINMASTER)
        }
    }
}

public struct NetBIOSNameServiceEntry {
    public let name: String
    public let group: String
    public let serviceType: NetBIOSNameServiceType
    public let ipAddress: UInt32

    init?(cEntry: OpaquePointer?) {
        guard let entry = cEntry else { return nil }
        guard let nameBits = netbios_ns_entry_name(entry) else { return nil } // UnsafePointer<Int8>
        guard let groupBits = netbios_ns_entry_group(entry) else { return nil } // UnsafePointer<Int8>
        let serviceTypeBits = netbios_ns_entry_type(entry) // Int8
        guard let serviceType = NetBIOSNameServiceType.init(fromNetBIOSNSEntryType: serviceTypeBits) else { return nil }
        let ipAddressBits = netbios_ns_entry_ip(entry) // Uint32

        self.name = String(cString: nameBits)
        self.group = String(cString: groupBits)
        self.serviceType = serviceType
        self.ipAddress = ipAddressBits
    }

    public var ipAddressString: String {
        var bytes = [UInt32]()
        bytes.append(self.ipAddress & 0xFF)
        bytes.append((self.ipAddress >> 8) & 0xFF)
        bytes.append((self.ipAddress >> 16) & 0xFF)
        bytes.append((self.ipAddress >> 24) & 0xFF)

        return "\(bytes[0]).\(bytes[1]).\(bytes[2]).\(bytes[3])"
    }

    public var smbServer: SMBServer {
        return SMBServer(hostname: self.name, ipAddress: self.ipAddress)
    }
}

extension NetBIOSNameServiceEntry: CustomStringConvertible {
    public var description: String {
        return "\(self.name) - \(self.ipAddressString)"
    }
}

extension NetBIOSNameServiceEntry: Hashable {
    public var hashValue: Int {
        return (self.name.hashValue ^ self.group.hashValue) + Int(self.ipAddress)
    }
}

extension NetBIOSNameServiceEntry: Equatable { }

public func == (lhs: NetBIOSNameServiceEntry, rhs: NetBIOSNameServiceEntry) -> Bool {
    return lhs.hashValue == rhs.hashValue
}
