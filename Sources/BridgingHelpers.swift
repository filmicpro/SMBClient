//
//  BridgingHelpers.swift
//  SMBClient
//
//  Created by Seth Faxon on 8/31/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

internal func bridge<T: AnyObject>(obj: T) -> UnsafeMutableRawPointer {
    return UnsafeMutableRawPointer(Unmanaged.passUnretained(obj).toOpaque())
}

internal func bridge<T: AnyObject>(ptr: UnsafeRawPointer) -> T {
    return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
}

internal func bridgeRetained<T: AnyObject>(obj: T) -> UnsafeRawPointer {
    return UnsafeRawPointer(Unmanaged.passRetained(obj).toOpaque())
}

internal func bridgeTransfer<T: AnyObject>(ptr: UnsafeRawPointer) -> T {
    return Unmanaged<T>.fromOpaque(ptr).takeRetainedValue()
}
