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
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testIPAddressString() {
        let smbServer = SMBServer(hostname: "test", ipAddress: 167772420)
        XCTAssert(smbServer.ipAddressString == "10.0.1.4", "unexpected ipAddressString")
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
