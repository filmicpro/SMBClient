//
//  Result.swift
//  SMBClient
//
//  Created by Seth Faxon on 9/8/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import Foundation

public enum Result<T> {
    case success(T)
    case failure(Error)
}
