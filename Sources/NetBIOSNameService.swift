//
//  NetBIOSNameService.swift
//  SMBClient
//
//  Created by Seth Faxon on 8/30/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import Foundation
import libdsm

typealias DiscoverCallback = @convention(c) (UnsafeMutableRawPointer?, OpaquePointer?) -> Void

public protocol NetBIOSNameServiceDelegate {
    func added(entry: NetBIOSNameServiceEntry)
    func removed(entry: NetBIOSNameServiceEntry)
}

public class NetBIOSNameService {
    
    private let nameService = netbios_ns_new()
    
    public var delegate: NetBIOSNameServiceDelegate?
    
    public init() { }
    
    deinit {
        netbios_ns_discover_stop(self.nameService)
        self.onAdded = nil
        self.onRemoved = nil
        netbios_ns_destroy(self.nameService)
    }
    
    private var onAdded: DiscoverCallback? = { (p_opaque: UnsafeMutableRawPointer?, netBiosNSEntry: OpaquePointer?) -> Void in
        if let ent = NetBIOSNameServiceEntry(cEntry: netBiosNSEntry) {
            // https://stackoverflow.com/questions/33551191/swift-pass-data-to-a-closure-that-captures-context
            if let ptr = p_opaque {
                // if EXC_BAD_ACCESS is thrown here it's because 'this' instance of NetBIOSNameService has been deallocated
                // while netbios_ns_discover_start is still firing callbacks
                let mySelf = Unmanaged<NetBIOSNameService>.fromOpaque(ptr).takeUnretainedValue()
                mySelf.delegate?.added(entry: ent)
            }
        }
    }
    
    private var onRemoved: DiscoverCallback? = { (p_opaque: UnsafeMutableRawPointer?, netBiosNSEntry: OpaquePointer?) -> Void in
        if let ent = NetBIOSNameServiceEntry(cEntry: netBiosNSEntry) {
            guard let ptr = p_opaque else { return }
            let mySelf = Unmanaged<NetBIOSNameService>.fromOpaque(ptr).takeUnretainedValue()
            mySelf.delegate?.removed(entry: ent)
        }
    }
    
    // will return empty string if host is present, unreachable host returns nil
    public func networkNameFor(ipAddress: String) -> String? {
        let addr = UnsafeMutablePointer<in_addr>.allocate(capacity: 1)
        let addrString = ipAddress.cString(using: .ascii)
        inet_aton(addrString, addr)
        let nameChar = netbios_ns_inverse(self.nameService, addr.pointee.s_addr)
        guard let name = nameChar else { return nil }
        return String(cString: name)
    }
    
    public func startDiscovery(withTimeout timeout: TimeInterval) {
        let blockPointer = bridge(obj: self)
        
        var cb = netbios_ns_discover_callbacks(p_opaque: blockPointer, pf_on_entry_added: self.onAdded, pf_on_entry_removed: self.onRemoved)
        netbios_ns_discover_start(self.nameService, UInt32(timeout), &cb)
    }
    
}



