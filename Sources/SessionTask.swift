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

    internal var smbSession: OpaquePointer?
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

    func requestFileForItemAt(path: String, inTree treeId: smb_tid) -> SMBFile? {
        let fileCString = path.cString(using: .utf8)
        guard let stat = smb_fstat(self.smbSession, treeId, fileCString) else { return nil }

        let file = SMBFile(stat: stat, session: self.session, parentDirectoryFilePath: path)

        smb_stat_destroy(stat)
        return file
    }

    internal func cleanupBlock(treeId: smb_tid, fileId: smb_fd) {
        if let backgroundTask = self.backgroundTaskIdentifier {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            self.backgroundTaskIdentifier = nil
        }

        if self.taskOperation != nil && treeId > 0 {
            smb_tree_disconnect(self.smbSession, treeId)
        }

        if let session = self.smbSession {
            if fileId > 0 {
                smb_fclose(session, fileId)
            }
            smb_session_destroy(session)
        }
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
