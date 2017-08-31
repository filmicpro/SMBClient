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


private func entryAddedCallback(p_opaque: UnsafeMutableRawPointer?, netbios_ns_entry: OpaquePointer?) {
    
}

private func entryRemovedCallback(p_opaque: UnsafeMutableRawPointer?, netbios_ns_entry: OpaquePointer?) {
    
}

func bridge<T : AnyObject>(obj : T) -> UnsafeMutableRawPointer {
    return UnsafeMutableRawPointer(Unmanaged.passUnretained(obj).toOpaque())
}

func bridge<T : AnyObject>(ptr : UnsafeRawPointer) -> T {
    return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
}

func bridgeRetained<T : AnyObject>(obj : T) -> UnsafeRawPointer {
    return UnsafeRawPointer(Unmanaged.passRetained(obj).toOpaque())
}

func bridgeTransfer<T : AnyObject>(ptr : UnsafeRawPointer) -> T {
    return Unmanaged<T>.fromOpaque(ptr).takeRetainedValue()
}
public class NetBIOSNameService {
    
    private let nameService = netbios_ns_new()
    
    public init() { }
    
    public func startDiscovery(withTimeout timeout: TimeInterval) {
        
        
        
//        netbios_ns_discover_callbacks(p_opaque: <#T##UnsafeMutableRawPointer!#>, pf_on_entry_added: <#T##((UnsafeMutableRawPointer?, OpaquePointer?) -> Void)!##((UnsafeMutableRawPointer?, OpaquePointer?) -> Void)!##(UnsafeMutableRawPointer?, OpaquePointer?) -> Void#>, pf_on_entry_removed: <#T##((UnsafeMutableRawPointer?, OpaquePointer?) -> Void)!##((UnsafeMutableRawPointer?, OpaquePointer?) -> Void)!##(UnsafeMutableRawPointer?, OpaquePointer?) -> Void#>)
        let blockPointer = bridge(obj: self)
        
//        var cb = netbios_ns_discover_callbacks(p_opaque: blockPointer, pf_on_entry_added: entryAddedCallback(p_opaque: <#T##UnsafeMutableRawPointer?#>, netbios_ns_entry: <#T##OpaquePointer?#>), pf_on_entry_removed: <#T##((UnsafeMutableRawPointer?, OpaquePointer?) -> Void)!##((UnsafeMutableRawPointer?, OpaquePointer?) -> Void)!##(UnsafeMutableRawPointer?, OpaquePointer?) -> Void#>)
        
//        let added = entryAddedCallback(p_opaque: unsafeMutableRawPointer, netbios_ns_entry: opaquePointer) {
//
//        }()
        let x: @convention(c) (UnsafeMutableRawPointer?, OpaquePointer?) -> Void = {
            (x, netbios_ns_entry) -> Void in
            print(x)
            if let ent = NetBiosNameServiceEntry(cEntity: netbios_ns_entry) {
                print(ent.name)
            }
        }
        
        var cb = netbios_ns_discover_callbacks(p_opaque: blockPointer, pf_on_entry_added: x, pf_on_entry_removed: x)
        
//        netbios_ns_discover_start(self.nameService, UInt32(timeout), <#T##callbacks: UnsafeMutablePointer<netbios_ns_discover_callbacks>!##UnsafeMutablePointer<netbios_ns_discover_callbacks>!#>)
        netbios_ns_discover_start(self.nameService, UInt32(timeout), &cb)
        
    }
    
//    private func @convention(c) onEntityRemoved(p_opaque: UnsafeMutableRawPointer?, netbiosNSEntry: OpaquePointer?) -> Void {
////        (x, netbios_ns_entry) -> Void in
//        print(p_opaque)
//        if let ent = NetBiosNameServiceEntry(cEntity: netbiosNSEntry) {
//            print(ent.name)
//        }
//    }
}

public struct NetBiosNameServiceEntry {
    let name: String
    
    init?(cEntity: OpaquePointer?) {
        guard let entity = cEntity else { return nil }
        guard let nameBits = netbios_ns_entry_name(entity) else { return nil } // UnsafePointer<Int8>
        self.name = String(cString: nameBits)
    }
}

