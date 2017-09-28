//
//  SMBServerTests.swift
//  SMBClientTests
//
//  Created by Seth Faxon on 9/26/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import XCTest
@testable import SMBClient

class SMBServerTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testIPAddressString() {
        let smbServer = SMBServer(hostname: "test", ipAddress: 167772420)
        XCTAssert(smbServer.ipAddressString == "10.0.1.4", "unexpected ipAddressString")
    }

    func testEquatableAfirmative() {
        let lhs = SMBServer(hostname: "test", ipAddress: 167772420)
        let rhs = SMBServer(hostname: "test", ipAddress: 167772420)
        XCTAssert(lhs == rhs, "SMBServer equality failed")
    }

    func testEqualityNegativeForHost() {
        let lhs = SMBServer(hostname: "test", ipAddress: 167772420)
        let rhs = SMBServer(hostname: "foo", ipAddress: 167772420)
        XCTAssert(lhs != rhs, "SMBServer equality true, when it should be false - host")
    }

    func testEquatableNegativeForAddress() {
        let lhs = SMBServer(hostname: "test", ipAddress: 167772420)
        let rhs = SMBServer(hostname: "test", ipAddress: 1)
        XCTAssert(lhs != rhs, "SMBServer equality true, when it should be false - address")
    }

    func testHostnameLookup() {
        let srv = SMBServer(hostname: "bender")
        XCTAssert(srv != nil, "SMBServer init with only hostname failed")
        XCTAssert(srv?.ipAddress != 0)
    }

}
