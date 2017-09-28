//
//  Directory + Extension.swift
//  SMBClientTests
//
//  Created by Seth Faxon on 9/28/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import Foundation
@testable import SMBClient

// test injection
extension SMBDirectory {
    init(name: String) {
        self.name = name

        self.createdAt = nil
        self.accessedAt = nil
        self.writeAt = nil
        self.modifiedAt = nil
    }
}
