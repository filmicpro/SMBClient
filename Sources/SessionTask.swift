//
//  SessionTask.swift
//  SMBClient
//
//  Created by Seth Faxon on 9/5/17.
//  Copyright © 2017 Filmic. All rights reserved.
//

import Foundation
import UIKit
import libdsm

public class SessionTask {
    var session: SMBSession
    var delegateQueue: DispatchQueue
    var canBeResumed: Bool = false
    var state: SessionTaskState = .ready

    internal var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?

    init(session: SMBSession, delegateQueue: DispatchQueue = DispatchQueue.main) {
        self.session = session
        self.delegateQueue = delegateQueue
    }

    internal lazy var taskOperation: BlockOperation? = {
        var result = BlockOperation()
        result.addExecutionBlock {
            self.performTaskWith(operation: result)
        }
        result.completionBlock = {
            self.taskOperation = nil
        }
        return result
    }()

    func performTaskWith(operation: BlockOperation) {
        return
    }

    // used to validate that a remote file is where we expect, before operating on it
    func request(file: SMBFile, inTree treeId: smb_tid) -> SMBFile? {
        let fileStat = self.session.fileStat(treeId: treeId, file: file)
        switch fileStat {
        case .failure(_):
            return nil
        case .success(let f):
            return f
        }
    }

    internal func cleanupBlock(treeId: smb_tid, fileId: smb_fd) {
        if let backgroundTask = self.backgroundTaskIdentifier {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            self.backgroundTaskIdentifier = nil
        }

        if self.taskOperation != nil && treeId > 0 {
            _ = self.session.treeDisconnect(treeId: treeId)
        }
        self.session.fileClose(fileId: fileId)
    }

    public func cancel() {
        if self.state != .running {
            return
        }
        self.taskOperation?.cancel()
        self.state = .cancelled
        self.taskOperation = nil
    }

    internal func fail() {
        if self.state != .running {
            return
        }
        self.cancel()
        self.state = .failed
    }

    public func resume() {
        if self.state == .running {
            return
        }
        guard let to = self.taskOperation else {
            return
        }
        self.session.taskQueue.addOperation(to)
        self.state = .running
    }

}

extension SessionTask {
    public enum SessionTaskState {
        case ready
        case running
        case suspended
        case cancelled
        case completed
        case failed
    }
}
