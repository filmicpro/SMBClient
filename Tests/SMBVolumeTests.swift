//
//  SMBVolumeTests.swift
//  SMBClientTests
//
//  Created by Seth Faxon on 9/28/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import XCTest
@testable import SMBClient

class SMBVolumeTests: XCTestCase {

    var server: SMBServer?

    override func setUp() {
        super.setUp()
        self.server = SMBServer(hostname: "testerton", ipAddress: 167772420) // 10.0.1.4
    }

    override func tearDown() {
        super.tearDown()
        self.server = nil
    }

    func testHiddenWhenTrailingDollar() {
        let volume = SMBVolume(server: server!, name: "Share$")
        XCTAssert(volume.isHidden, "isHidden should be true")
    }

    func testNotHidden() {
        let volume = SMBVolume(server: server!, name: "Share")
        XCTAssert(!volume.isHidden, "isHidden should be false")
    }

    func testPath() {
        let volume = SMBVolume(server: server!, name: "Share")
        XCTAssert(volume.path.directories.count == 0, "should init directories")
    }

}
