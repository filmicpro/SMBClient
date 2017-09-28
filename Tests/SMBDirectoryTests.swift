//
//  SMBDirectoryTests.swift
//  SMBClientTests
//
//  Created by Seth Faxon on 9/28/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import XCTest
@testable import SMBClient

class SMBDirectoryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testDotIsHidden() {
        let d = SMBDirectory(name: ".")
        XCTAssert(d.isHidden)
    }

    func testDoubleDotIsHidden() {
        let d = SMBDirectory(name: "..")
        XCTAssert(d.isHidden)
    }

    func testTrailingDollarIsHidden() {
        let d = SMBDirectory(name: "SYSTEM$")
        XCTAssert(d.isHidden)
    }

    func testIsHiddenFalse() {
        let d = SMBDirectory(name: "Share")
        XCTAssert(!d.isHidden)
    }

}
