//
//  SMBPathTests.swift
//  SMBClientTests
//
//  Created by Seth Faxon on 9/28/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import XCTest
@testable import SMBClient

class SMBPathTests: XCTestCase {
    var volume: SMBVolume?
    var server: SMBServer?
    var path: SMBPath?

    override func setUp() {
        super.setUp()

        self.server = SMBServer(hostname: "test", ipAddress: 167772420)
        self.volume = SMBVolume(server: self.server!, name: "Share")
        self.path =  SMBPath(volume: self.volume!)
    }

    override func tearDown() {
        super.tearDown()

        self.server = nil
        self.volume = nil
    }

    func testRoutablePathForVolume() {
        XCTAssert(self.path!.routablePath == "\\\(self.volume!.name)", "incorrect path for only volume")
    }

    func testRoutablePathForVolumeAndDirectory() {
        let dir = SMBDirectory(name: "firstDirectory")
        self.path!.append(directory: dir)
        XCTAssert(self.path!.routablePath == "\\\(self.volume!.name)\\\(dir.name)")
    }

    func testSearchPathForVolume() {
        XCTAssert(self.path!.searchPath == "*")
    }

    func testSearchPathForVolumeAndDirectory() {
        let dir = SMBDirectory(name: "firstDirectory")
        self.path!.append(directory: dir)
        XCTAssert(self.path!.searchPath == "\\\(dir.name)\\*")
    }

    func testAppendDirectory() {
        let dir = SMBDirectory(name: "foo")
        self.path!.append(directory: dir)
        XCTAssert(self.path?.directories.count == 1)
    }

    func testAppendDirectoryDoesNotAddDot() {
        let dot = SMBDirectory(name: ".")
        self.path!.append(directory: dot)
        XCTAssert(self.path?.directories.count == 0, "don't append . directory")
    }

    func testAppendDirectoryNoOpForDoubleDot() {
        let doubleDot = SMBDirectory(name: "..")
        self.path!.append(directory: doubleDot)
        XCTAssert(self.path?.directories.count == 0, "don't append .. directory")
    }

    func testAppendDirectoryPopsForDoubleDot() {
        let doubleDot = SMBDirectory(name: "..")
        let foo = SMBDirectory(name: "foo")
        self.path!.append(directory: foo)
        XCTAssert(self.path?.directories.count == 1, "sanity check")
        self.path!.append(directory: doubleDot)
        XCTAssert(self.path?.directories.count == 0, "expected .. directory append to pop")
    }

}
